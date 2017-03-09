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

  /// Sequential list of events queued up for firing
  public private(set) var pendingEvents = [BlocklyEvent]()

  /// Flag that determines if the event manager is allowing any new events to be queued via
  /// `addPendingEvent(:)`. Defaults to `true`.
  public var isEnabled = true

  /// Objects listening to event fires
  private var _listeners = WeakSet<EventManagerListener>()

  // MARK: - Events

  /**
   Queues an event to be fired in the future (via `firePendingEvents()`). However, this event will
   not be queued if `self.isEnabled` is set to `false`.

   - parameter event: The `BlocklyEvent` to queue.
   */
  public func addPendingEvent(_ event: BlocklyEvent) {
    guard isEnabled else {
      return
    }

    pendingEvents.append(event)
  }

  /**
   Fires all pending events.
   */
  public func firePendingEvents() {
    // TODO:(#272) Merge similar events before firing them.

    for event in pendingEvents {
      for listener in _listeners {
        listener.eventManager(self, didFireEvent: event)
      }
    }

    pendingEvents.removeAll()
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
