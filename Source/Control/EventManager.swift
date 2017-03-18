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
 */
@objc(BKYEventManager)
public final class EventManager: NSObject {

  // MARK: - Properties

  /// Shared instance.
  public static let sharedInstance = EventManager()

  /// Sequential list of events queued up for firing.
  public private(set) var pendingEvents = [BlocklyEvent]()

  /// Flag that determines if the event manager is allowing any new events to be queued via
  /// `addPendingEvent(:)`. Defaults to `true`.
  public var isEnabled: Bool = true

  /// The current group ID that is automatically assigned to new events with no group ID.
  public private(set) var groupID: String?

  /// Objects listening to event fires.
  private var _listeners = WeakSet<EventManagerListener>()

  /// Flag indicating if events are currently being fired.
  private var _firingEvents: Bool = false

  /// Flag that determines if `firePendingEvents()` should be called again immediately after
  /// it has been called.
  private var _firePendingEventsAgain: Bool = false

  // MARK: - Events

  /**
   Queues an event to be fired in the future (via `firePendingEvents()`). However, this event will
   not be queued if `self.isEnabled` is set to `false`.

   If `event.groupID` is `nil`, it is automatically assigned the value of `self.groupID`, by this
   method.

   - parameter event: The `BlocklyEvent` to queue.
   */
  public func addPendingEvent(_ event: BlocklyEvent) {
    guard isEnabled else {
      return
    }

    if event.groupID == nil {
      event.groupID = groupID
    }

    pendingEvents.append(event)
  }

  /**
   Fires all pending events.
   */
  public func firePendingEvents() {
    guard !_firingEvents else {
      // The event manager is currently firing events. Schedule it to fire the next batch of events
      // after it is done its current batch.
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
      // Immediately fire the next batch of events
      _firePendingEventsAgain = false
      firePendingEvents()
    }
  }

  // MARK: - Grouping

  /**
   Starts a group by setting `self.groupID` to a new UUID. Each new pending event will automatically
   be assigned to this group ID, if it is not already assigned to a group ID.
   */
  public func startGroup() {
    groupID = UUID().uuidString
  }

  /**
   Starts a group by setting `self.groupID` to a given group ID. Each new pending event will
   automatically be assigned to this group ID, if it is not already assigned to a group ID.

   - parameter groupID: The groupID to assign.
   */
  public func startGroup(groupID: String) {
    self.groupID = groupID
  }

  /**
   Stops the current group by setting `self.groupID` to `nil`. Each new pending event will no
   longer be automatically assigned to a group ID.
   */
  public func stopGroup() {
    groupID = nil
  }

  /**
   Convenience method that starts a new group, executes a given closure, stops the group, and then
   fires all pending events.

   - parameter closure: The closure to execute.
   - note: This method guarantees a group is started, stopped, and all pending events are fired,
   regardless if the given closure throws an error.
   */
  public func groupAndFireEvents(forClosure closure: () throws -> Void) rethrows {
    startGroup()

    defer {
      // This is guaranteed to run after the execution of `closure`, regardless if it fails or not.
      stopGroup()
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
