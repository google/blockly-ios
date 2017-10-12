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
 Protocol for events that occur on a `BlockGroupView`.
 */
@objc(BKYBlockGroupViewDelegate)
protocol BlockGroupViewDelegate: class {
  /**
   Event that is called when a `BlockGroupView` has its `dragging` property.
   */
  func blockGroupViewDidUpdateDragging(_ blockGroupView: BlockGroupView)
}

/**
 View for rendering a `BlockGroupLayout`.
 */
@objc(BKYBlockGroupView)
@objcMembers open class BlockGroupView: LayoutView, ZIndexedView {

  // MARK: - Properties

  /// The layout object to render
  open var blockGroupLayout: BlockGroupLayout? {
    return layout as? BlockGroupLayout
  }

  /// Delegate for listening to events that occur on this instance.
  weak var delegate: BlockGroupViewDelegate?

  /// The z-index of the block group view
  public fileprivate(set) final var zIndex: UInt = 0 {
    didSet {
      if zIndex != oldValue {
        if let superview = self.superview as? ZIndexedGroupView {
          // Re-order this view within its parent BlockGroupView view
          superview.upsertView(self)
        }
      }
    }
  }

  /// Flag indicating if this view is being dragged.
  public var dragging: Bool = false {
    didSet {
      if dragging != oldValue {
        delegate?.blockGroupViewDidUpdateDragging(self)
      }
    }
  }

  // MARK: - Super

  /**
   Returns the furthest descendant of the receiver in the view hierarchy that contains a specified
   point. Unlike the default implementation, block group view will not return itself.

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

  /**
   Refreshes the block group view, when necessary.

   - parameter flags: `LayoutFlag` indicating which parts of the view to refresh. Defaults to
     `LayoutFlag.All` if no value is specified.
   - parameter animated: `true` if the view should animate during the refresh. `false` if the view
     should refresh immediately. Defaults to `false`.
   */
  open override func refreshView(
    forFlags flags: LayoutFlag = LayoutFlag.All, animated: Bool = false)
  {
    super.refreshView(forFlags: flags, animated: animated)

    guard let layout = self.blockGroupLayout else {
      return
    }

    if flags.intersectsWith([Layout.Flag_NeedsDisplay, BlockGroupLayout.Flag_UpdateDragging]) {
      self.dragging = layout.dragging

      // Update the alpha interaction. This part isn't animated since it can look weird when
      // connecting new blocks into an existing block group that was previously highlighted before
      // (the new blocks will change from fully opaque to translucent, and then quickly animate
      // back to fully opaque)
      self.alpha = layout.dragging ?
        layout.config.float(for: DefaultLayoutConfig.BlockDraggingFillColorAlpha) : 1.0
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith([Layout.Flag_NeedsDisplay, Layout.Flag_UpdateViewFrame]) {
        // Update the view frame
        self.frame = layout.viewFrame
      }

      if flags.intersectsWith([Layout.Flag_NeedsDisplay, BlockGroupLayout.Flag_UpdateZIndex]) {
        // Update the z-index
        self.zIndex = layout.zIndex
      }
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    for subview in self.subviews {
      subview.removeFromSuperview()
    }
  }
}
