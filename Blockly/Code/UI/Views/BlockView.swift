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
 Handler for events that occur on a `BlockView`.
 */
public protocol BlockViewDelegate: class {
  /**
   Event that is called when a block view requests to present a view controller
   as a popover.

   - Parameter blockView: The block view that made the request
   - Parameter viewController: The view controller to present
   - Parameter fromView: The view where the popover should pop up from
   - Returns: True if the view controller was presented. False otherwise.
   */
  func blockView(blockView: BlockView,
    requestedToPresentPopoverViewController viewController: UIViewController,
    fromView: UIView) -> Bool
}

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

  /// Layer for rendering the block's background
  private let _backgroundLayer = BezierPathLayer()

  /// Layer for rendering the block's highlight overlay
  private var _highlightLayer: BezierPathLayer?

  /// Field subviews
  private var _fieldViews = [FieldView]()

  /// Flag determining if layer changes should be animated
  private var _disableLayerChangeAnimations: Bool = true

  /// Delegate for events that occur on the block
  public weak var delegate: BlockViewDelegate?

  public private(set) final var zIndex: UInt = 0 {
    didSet {
      if zIndex != oldValue {
        if let superview = self.superview as? WorkspaceView.BlockGroupView {
          // Re-order this view within its parent BlockGroupView view
          superview.upsertBlockView(self)
        }
      }
    }
  }

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

    // super.refreshView() automatically handles updates for `Layout.Flag_UpdateViewFrame`.
    // If that was the only flag that was set, then just exit early.
    guard flags.subtract(Layout.Flag_UpdateViewFrame).hasFlagSet() else {
      return
    }

    guard let layout = self.blockLayout else {
      return
    }

    CATransaction.begin()
    CATransaction.setDisableActions(_disableLayerChangeAnimations)

    refreshBackgroundUI(forFlags: flags)

    if flags.intersectsWith(BlockLayout.Flag_NeedsDisplay) {
      // Update field views
      for fieldLayout in layout.fieldLayouts {
        let cachedFieldView = ViewManager.sharedInstance.findFieldViewForLayout(fieldLayout)

        if cachedFieldView == nil {
          do {
            let fieldView = try ViewFactory.sharedInstance.fieldViewForLayout(fieldLayout)
            _fieldViews.append(fieldView)

            addSubview(fieldView)
          } catch let error as NSError {
            bky_assertionFailure("\(error)")
          }
        } else {
          // Do nothing. The field view will handle its own refreshing/repositioning.
        }
      }

      // Set its user interaction
      userInteractionEnabled = !layout.block.disabled
    }

    if flags.intersectsWith([BlockLayout.Flag_NeedsDisplay, BlockLayout.Flag_UpdateZIndex]) {
      self.zIndex = layout.zIndex
    }

    if flags.intersectsWith([BlockLayout.Flag_NeedsDisplay, BlockLayout.Flag_UpdateVisible]) {
      self.hidden = !layout.visible
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

    for fieldView in _fieldViews {
      fieldView.removeFromSuperview()
      ViewFactory.sharedInstance.recycleView(fieldView)
    }
    _fieldViews = []
  }

  // MARK: - Public

  /**
   Requests `self.delegate` to present a view controller from a specific view.

   - Parameter viewController: The view controller to present
   - Parameter fromView: The view where the popover should pop up from.
   - Returns: True if the view controller was presented. False otherwise.
   */
  public func requestToPresentPopoverViewController(
    viewController: UIViewController, fromView: UIView) -> Bool
  {
    return delegate?.blockView(
      self, requestedToPresentPopoverViewController: viewController, fromView: fromView) ?? false
  }
}
