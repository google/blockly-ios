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
public class LayoutEventManager: NSObject {
  /// Shared instance.
  public static let sharedInstance = LayoutEventManager()

  /// Layouts to send change events for
  private var layouts = [String: Layout]()

  /// Flag if this class has been scheduled to send change events at the beginning of the next
  /// run loop.
  private var scheduledSendChangeEvents: Bool = false

  // MARK: - Public

  /**
  Schedules to call `sendChangeEvent()` on a given layout at the beginning of the next run loop.

  - Parameter layout: The given layout
  */
  public func scheduleChangeEventForLayout(layout: Layout) {
    if layouts[layout.uuid] == nil {
      layouts[layout.uuid] = layout

      if !self.scheduledSendChangeEvents {
        // Schedule to send out all the change events at the beginning of the next run loop
        self.performSelector("sendChangeEvents", withObject: nil, afterDelay: 0.0)
        self.scheduledSendChangeEvents = true
      }
    }
  }

  // MARK: - Internal

  /**
  Calls `sendChangeEvent()` on every layout added via `scheduleChangeEventForLayout(_)`.
  */
  internal func sendChangeEvents() {
    for (_, layout) in layouts {
      layout.sendChangeEvent()
    }

    // Reset the layouts to send change events for
    self.layouts.removeAll()
    self.scheduledSendChangeEvents = false
  }
}
