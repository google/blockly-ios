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
public class InputView: LayoutView {

  // MARK: - Properties

  /// The layout object to render
  public var inputLayout: InputLayout? {
    return layout as? InputLayout
  }

  // MARK: - Super

  public override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
    // Override hitTest so it doesn't return itself as a view if this is the only visible view that
    // gets hitTest
    let hitTestView = super.hitTest(point, withEvent: event)
    return (hitTestView == self) ? nil : hitTestView
  }

  public override func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All) {
    super.refreshView(forFlags: flags)

    guard let layout = self.inputLayout else {
      return
    }

    if flags.intersectsWith([Layout.Flag_NeedsDisplay, Layout.Flag_UpdateViewFrame]) {
      // Update the view frame
      frame = layout.viewFrame
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    for subview in self.subviews {
      subview.removeFromSuperview()
    }
  }
}
