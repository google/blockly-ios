/*
 * Copyright 2017 Google Inc. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

/**
 Protocol for listening to when events are fired by `EventManager`.
 */
@objc(BKYEventManagerListener)
public protocol EventManagerListener: class {
  /**
   Method that is executed when an event manager fires an event.

   - parameter eventManager: The `EventManager` firing the event.
   - parameter event: The `BlocklyEvent` that was fired.
   */
  func eventManager(_ eventManager: EventManager, didFireEvent event: BlocklyEvent)
}

/**
 Manages the use of events across Blockly.

 This class is designed as a singleton instance, accessible via `EventManager.shared`.

 - note: This class is not thread-safe and should only be accessed from the main thread.
 */
@objc(BKYEventManager)
@objcMembers public final class EventManager: NSObject {

  // MARK: - Properties

  /// Shared instance.
  public static let shared = EventManager()

  /// Sequential list of events queued up for firing.
  public private(set) var pendingEvents = [BlocklyEvent]()

  /// Flag that determines if the event manager is allowing any new events to be queued via
  /// `addPendingEvent(:)`. Defaults to `true`.
  public var isEnabled: Bool = true

  /// The current group ID that is automatically assigned to new events with no group ID.
  public private(set) var currentGroupID: String?

  /// The stack of group IDs that have been created thus far.
  private var _groupStack = [String]() {
    didSet {
      // Update the current group ID
      currentGroupID = _groupStack.last
    }
  }

  /// Objects listening to event fires.
  private var _listeners = WeakSet<EventManagerListener>()

  /// Flag indicating if events are currently being fired.
  private var _firingEvents: Bool = false

  /// Flag that determines if `firePendingEvents()` should be called again immediately after
  /// it has been called.
  private var _firePendingEventsAgain: Bool = false

  // MARK: - Initializers

  /**
   A singleton instance for this class is accessible via `EventManager.shared.`
   */
  private override init() {
  }

  // MARK: - Events

  /**
   Queues an event to be fired in the future (via `firePendingEvents()`). However, this event will
   not be queued if `self.isEnabled` is set to `false`, or if the event is discardable.

   If `event.groupID` is `nil`, it is automatically assigned the value of `self.currentGroupID`,
   by this method.

   - parameter event: The `BlocklyEvent` to queue.
   */
  public func addPendingEvent(_ event: BlocklyEvent) {
    guard isEnabled && !event.isDiscardable() else {
      return
    }

    if event.groupID == nil {
      event.groupID = currentGroupID
    }

    pendingEvents.append(event)
  }

  /**
   Fires all pending events.
   */
  public func firePendingEvents() {
    guard !_firingEvents else {
      // The event manager is currently firing events. This means that one of the current listeners
      // of `EventManager` is trying to fire more events before the current batch of events have
      // been fully fired. For now, do nothing, but schedule to fire the next batch of events
      // immediately after the current batch has been fired for all remaining listeners.
      _firePendingEventsAgain = true
      return
    }

    _firingEvents = true

    // Work off copy of the current batch of events, so we can clear the queue immediately.
    let eventQueue = pendingEvents.merged().filterDiscardable()
    pendingEvents.removeAll()

    // Fire events
    for event in eventQueue {
      for listener in _listeners {
        listener.eventManager(self, didFireEvent: event)
      }
    }

    _firingEvents = false

    if _firePendingEventsAgain {
      // Immediately fire the next batch of events.
      // Note: It's possible this recurses infinitely and crashes. This is desired behavior though
      // so devs can find the problem quickly.
      _firePendingEventsAgain = false
      firePendingEvents()
    }
  }

  // MARK: - Grouping

  /**
   Generates a group UUID and pushes this new group ID to the group stack, effectively setting it to
   `self.currentGroupID`. Each new pending event will automatically be assigned to this group ID,
   if it is not already assigned to a group ID.

   Every call to `pushNewGroup()` needs to be balanced by a future call to `popGroup()`.

   - note: It is not recommended to push a new group ID if `self.currentGroupID` is not `nil`.
   Doing this will result in an error in debug mode and a warning in release mode.
   */
  public func pushNewGroup() {
    pushGroup(groupID: UUID().uuidString)
  }

  /**
   Pushes a given group ID to the group stack, effectively setting it to `self.currentGroupID`.
   Each new pending event will automatically be assigned to this group ID, if it is not already
   assigned to a group ID.

  Every call to `pushGroup(groupID:)` needs to be balanced by a future call to `popGroup()`.

   - parameter groupID: The groupID to push.
   - note: It is not recommended to push a group ID that differs from `self.currentGroupID`,
   if it is not `nil`. Doing this will result in an error in debug mode and a warning in release
   mode.
   */
  public func pushGroup(groupID: String) {
    if let currentGroupID = self.currentGroupID, currentGroupID != groupID {
      bky_assertionFailure(
        "A new group ID was pushed to EventManager, when it differs from the current group ID." +
        "This behavior is discouraged and you should refactor your code to avoid this situation.")
    }

    _groupStack.append(groupID)
  }

  /**
   Pops the current group ID from the group stack.

   If the group stack is not empty, `self.currentGroupID` is assigned to the previously pushed group
   ID.
   If the group stack is empty, `self.currentGroupID` is assigned to `nil`.

   Each new pending event will automatically be assigned to the new value of `self.currentGroupID`,
   if it is not already assigned to a group ID.
   */
  public func popGroup() {
    if !_groupStack.isEmpty {
      _groupStack.removeLast()
    } else {
      bky_assertionFailure(
        "An attempt was made to pop a group when no groups have been pushed to EventManager." +
        "Calls to `pushNewGroup()` and `pushGroup()` should be balanced with the same number of " +
        "calls to `popGroup()`.")
    }
  }

  /**
   Convenience method that starts a new group, executes a given closure, stops the group, and then
   fires all pending events.

   - parameter groupID: [Optional] Specifies a group ID to assign to a new group. If `nil`, a
   unique UUID is created for the group ID.
   - parameter closure: The closure to execute.
   - note: This method guarantees a group is started, stopped, and all pending events are fired,
   regardless if the given closure throws an error.
   */
  public func groupAndFireEvents(
    groupID: String? = nil, forClosure closure: () throws -> Void) rethrows {
    if let groupID = groupID {
      pushGroup(groupID: groupID)
    } else {
      pushNewGroup()
    }

    defer {
      // This is guaranteed to run after the execution of `closure`, regardless if it fails or not.
      popGroup()
      firePendingEvents()
    }

    try closure()
  }

  // MARK: - Listeners

  /**
   Adds a listener to `EventManager`.

   - parameter listener: The `EventManagerListener` to add.
   */
  public func addListener(_ listener: EventManagerListener) {
    _listeners.add(listener)
  }

  /**
   Removes a listener from `EventManager`.

   - parameter listener: The `EventManagerListener` to remove.
   */
  public func removeListener(_ listener: EventManagerListener) {
    _listeners.remove(listener)
  }
}
