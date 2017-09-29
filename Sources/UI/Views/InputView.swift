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
 View for rendering a `InputLayout`.
 */
@objc(BKYInputView)
@objcMembers open class InputView: LayoutView {

  // MARK: - Properties

  /// The layout object to render
  open var inputLayout: InputLayout? {
    return layout as? InputLayout
  }

  // MARK: - Super

  /**
   Returns the furthest descendant of the receiver in the view hierarchy that contains a specified
   point. Unlike the default implementation, block group view will not return itself, since it
   should return the owning block.

   - parameter point: A point specified in the receiver’s local coordinate system (bounds).
   - parameter event: The event that warranted a call to this method. If you are calling this method
   from outside your event-handling code, you may specify nil.
   - returns: The view object that is the furthest descendent the current view and contains `point`.
   */
  open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // Override hitTest so it doesn't return itself as a view if this is the only visible view that
    // gets hitTest
    let hitTestView = super.hitTest(point, with: event)
    return (hitTestView == self) ? nil : hitTestView
  }

  open override func refreshView(
    forFlags flags: LayoutFlag = LayoutFlag.All, animated: Bool = false)
  {
    super.refreshView(forFlags: flags, animated: animated)

    guard let layout = self.inputLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith([Layout.Flag_NeedsDisplay, Layout.Flag_UpdateViewFrame]) {
        // Update the view frame
        self.frame = layout.viewFrame
      }

      // Force the input view to always be drawn behind sibling views (which could be other
      // blocks).
      self.superview?.sendSubview(toBack: self)
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    for subview in self.subviews {
      subview.removeFromSuperview()
    }
  }
}
