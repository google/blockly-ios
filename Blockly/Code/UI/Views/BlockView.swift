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
View for rendering a `BlockLayout`.
*/
@objc(BKYBlockView)
public class BlockView: LayoutView {
  // MARK: - Properties

  /// Layout object to render
  public var blockLayout: BlockLayout? {
    return layout as? BlockLayout
  }

  /// Flag determining if layer changes should be animated
  private var _disableLayerChangeAnimations: Bool = true

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Abstract

  /**
   Updates the background UI of the block based on the layout flags.

   - Parameter flags: Refresh the background UI for the given set of flags.
   - Note: This method needs to be implemented by a subclass.
   */
  public func refreshBackgroundUI(forFlags flags: LayoutFlag) {
    bky_assertionFailure("\(#function) needs to be implemented by a subclass")
  }

  // MARK: - Super

  public override func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All) {
    super.refreshView(forFlags: flags)

    guard let layout = self.blockLayout else {
      return
    }

    CATransaction.begin()
    CATransaction.setDisableActions(_disableLayerChangeAnimations)

    if flags.intersectsWith([Layout.Flag_NeedsDisplay, Layout.Flag_UpdateViewFrame]) {
      // Update the view frame
      frame = layout.viewFrame
    }

    refreshBackgroundUI(forFlags: flags)

    if flags.intersectsWith(BlockLayout.Flag_NeedsDisplay) {
      // Set its user interaction
      userInteractionEnabled = layout.userInteractionEnabled
    }

    if flags.intersectsWith([BlockLayout.Flag_NeedsDisplay, BlockLayout.Flag_UpdateVisible]) {
      hidden = !layout.visible
    }

    CATransaction.commit()

    // Re-enable layer animations for any future changes
    _disableLayerChangeAnimations = false
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    self.frame = CGRectZero

    // Disable animating layer changes, so that the next block layout that uses this view instance
    // isn't animated into view based on the previous block layout.
    _disableLayerChangeAnimations = true

    for subview in subviews {
      subview.removeFromSuperview()
    }
  }
}
