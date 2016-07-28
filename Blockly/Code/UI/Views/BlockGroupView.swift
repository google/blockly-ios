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
 View for rendering a `BlockGroupLayout`.
 */
@objc(BKYBlockGroupView)
public class BlockGroupView: LayoutView, ZIndexedView {

  // MARK: - Properties

  /// The layout object to render
  public var blockGroupLayout: BlockGroupLayout? {
    return layout as? BlockGroupLayout
  }

  /// The z-index of the block group view
  public private(set) final var zIndex: UInt = 0 {
    didSet {
      if zIndex != oldValue {
        if let superview = self.superview as? ZIndexedGroupView {
          // Re-order this view within its parent BlockGroupView view
          superview.upsertView(self)
        }
      }
    }
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

    guard let layout = self.blockGroupLayout else {
      return
    }

    if flags.intersectsWith([Layout.Flag_NeedsDisplay, Layout.Flag_UpdateViewFrame]) {
      // Update the view frame
      frame = layout.viewFrame
    }

    if flags.intersectsWith([Layout.Flag_NeedsDisplay, BlockGroupLayout.Flag_UpdateDragging]) {
      // Update the alpha interaction
      alpha = layout.dragging ?
        layout.config.floatFor(DefaultLayoutConfig.BlockDraggingFillColorAlpha) : 1.0
    }

    if flags.intersectsWith([Layout.Flag_NeedsDisplay, BlockGroupLayout.Flag_UpdateZIndex]) {
      // Update the z-index
      zIndex = layout.zIndex
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    for subview in self.subviews {
      subview.removeFromSuperview()
    }
  }
}
