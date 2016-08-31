/*
* Copyright 2016 Google Inc. All Rights Reserved.
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
 Protocol for delegate events that occur on a `FieldView`.
 */
@objc(BKYFieldViewDelegate)
public protocol FieldViewDelegate {
  /**
   Event that is called when a field view requests to present a view controller as a popover.

   - Parameter fieldView: The `FieldView` that made the request
   - Parameter viewController: The `UIViewController` to present
   - Parameter fromView: The `UIView` where the popover should pop up from
   - Returns: True if the `viewController` was presented. False otherwise.
   */
  func fieldView(fieldView: FieldView,
                 requestedToPresentPopoverViewController viewController: UIViewController,
                                                         fromView: UIView) -> Bool
}

/**
 Abstract view for rendering a `FieldLayout`.
 */
@objc(BKYFieldView)
public class FieldView: LayoutView {

  // MARK: - Properties

  /// The delegate for events that occur on this instance
  public weak var delegate: FieldViewDelegate?

  /// The layout object to render
  private var fieldLayout: FieldLayout? {
    return layout as? FieldLayout
  }

  // MARK: - Super

  public override func refreshView(
    forFlags flags: LayoutFlag = LayoutFlag.All, animated: Bool = false)
  {
    super.refreshView(forFlags: flags, animated: animated)

    guard let fieldLayout = self.fieldLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith([Layout.Flag_NeedsDisplay, Layout.Flag_UpdateViewFrame]) {
        // Update the view frame
        self.frame = fieldLayout.viewFrame
      }

      // Enable/disable user interaction
      self.userInteractionEnabled = fieldLayout.userInteractionEnabled
    }
  }
}
