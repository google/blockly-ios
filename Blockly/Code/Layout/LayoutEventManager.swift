/*
* Copyright 2015 Google Inc. All Rights Reserved.
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
Manages the scheduling of change events for layouts.
*/
@objc(BKYLayoutEventManager)
public final class LayoutEventManager: NSObject {
  /// Shared instance.
  public static let sharedInstance = LayoutEventManager()

  /**
  Layouts to send change events for.

  - Note: When creation/deletion of items is done more often than item lookup, NSSet is more
  performant than Set, which is why it's used here.
  */
  private var _layouts = NSMutableSet()

  /// Flag if this class has been scheduled to send change events at the beginning of the next
  /// run loop.
  private var _scheduledSendChangeEvents: Bool = false

  // MARK: - Public

  /**
  Schedules to call `sendChangeEvent()` on a given layout at the beginning of the next run loop.

  - Parameter layout: The given layout
  */
  public func scheduleChangeEventForLayout(layout: Layout) {
    _layouts.addObject(layout)

    if !_scheduledSendChangeEvents {
      // TODO:(#35) Consider scheduling these events to execute at the end of the current run loop
      // Schedule to send out all the change events at the beginning of the next run loop
      self.performSelector("internalSendChangeEvents", withObject: nil, afterDelay: 0.0)
      _scheduledSendChangeEvents = true
    }
  }

  // MARK: - Public

  /**
  Immediately calls `sendChangeEvent()` for every layout that was added via
  scheduleChangeEventForLayout(_) (instead of waiting to do so at the beginning of the next run
  loop).
  */
  public func immediatelySendChangeEvents() {
    if _scheduledSendChangeEvents {
      // Cancel internalSendChangeEvents() from being called again in the future
      NSObject.cancelPreviousPerformRequestsWithTarget(self,
        selector: "internalSendChangeEvents",
        object: nil)
      _scheduledSendChangeEvents = false
    }

    internalSendChangeEvents()
  }

  // MARK: - Internal

  /**
  Calls `sendChangeEvent()` on every layout added via `scheduleChangeEventForLayout(_)`.

  - Note: This method must be internal in order to be able to call `self.performSelector(...)` on
  it.
  */
  internal func internalSendChangeEvents() {
    for layout in _layouts {
      (layout as! Layout).sendChangeEvent()
    }

    // Reset the layouts to send change events for
    _layouts.removeAllObjects()
    _scheduledSendChangeEvents = false
  }
}
