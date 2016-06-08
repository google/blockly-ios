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

// MARK: - WorkspaceViewDelegate Protocol

/**
 Protocol for events that occur on `WorkspaceView`.
 */
public protocol WorkspaceViewDelegate: class {
  /**
   Event that is called when a block view has been added to a workspace view.

   - Parameter workspaceView: The given `WorkspaceView`
   - Parameter blockView: The `BlockView` that has been added
   */
  func workspaceView(workspaceView: WorkspaceView, didAddBlockView blockView: BlockView)

  /**
   Event that is called when a block view will be removed from a workspace view.

   - Parameter workspaceView: The given `WorkspaceView`
   - Parameter blockView: The `BlockView` that will be removed
   */
  func workspaceView(workspaceView: WorkspaceView, willRemoveBlockView blockView: BlockView)
}

// MARK: - WorkspaceView Class

/**
View for rendering a `WorkspaceLayout`.
*/
@objc(BKYWorkspaceView)
public class WorkspaceView: LayoutView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `WorkspaceLayout`
  public var workspaceLayout: WorkspaceLayout? {
    return layout as? WorkspaceLayout
  }

  /// Scroll view used to render the workspace
  public lazy var scrollView: WorkspaceView.ScrollView = {
    let scrollView = WorkspaceView.ScrollView(frame: self.bounds)
    scrollView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    scrollView.autoresizesSubviews = false
    scrollView.delegate = self
    return scrollView
  }()

  /// Delegate for events that occur on this view
  public weak var delegate: WorkspaceViewDelegate?

  /// Flag if the canvas should be padded with extra spaces around its edges via
  /// `self.canvasPadding`. If set to false, the user will only be allowed to scroll the exact
  /// amount needed to view all blocks.
  public var allowCanvasPadding: Bool = true {
    didSet {
      updateCanvasSizeFromLayout()
    }
  }

  /// The amount of padding to apply to the edges of the workspace canvas
  public var canvasPadding = EdgeInsets(100, 100, 300, 100)

  /**
  The amount of padding that should be added to the edges when automatically scrolling a
  `Block` into view.
  */
  public var scrollIntoViewEdgeInsets = EdgeInsets(20, 20, 100, 20)

  /// The last known value for `workspaceLayout.contentOrigin`
  private var _lastKnownContentOrigin: CGPoint = CGPointZero

  /// Flag for disabling inadvertent calls to `removeExcessScrollSpace()`
  private var _disableRemoveExcessScrollSpace = false

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    addSubview(scrollView)

    // Don't automatically update `self.frame` based on `self.layout`
    updateOriginFromLayout = false
    updateBoundsFromLayout = false
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  public override func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All) {
    super.refreshView(forFlags: flags)

    guard let layout = self.workspaceLayout else {
      return
    }

    let allBlockLayouts = layout.allVisibleBlockLayoutsInWorkspace()

    if flags.intersectsWith([Layout.Flag_NeedsDisplay, WorkspaceLayout.Flag_AddedBlockLayout]) {
      // Get blocks that are in the current viewport
      for blockLayout in allBlockLayouts {
        let blockView = ViewManager.sharedInstance.findBlockViewForLayout(blockLayout)

        // TODO:(#29) For now, always render blocks regardless of where they are on the screen.
        // Later on, this should be replaced by shouldRenderBlockLayout(blockLayout).
        if blockView == nil {
          do {
            // Create a new block view for this layout
            try addBlockViewForLayout(blockLayout)
          } catch let error {
            bky_assertionFailure("\(error)")
          }
        } else {
          // Do nothing. The block view will handle its own refreshing/repositioning.
        }
      }
    }

    if flags.intersectsWith([Layout.Flag_NeedsDisplay, WorkspaceLayout.Flag_RemovedBlockLayout]) {
      // TODO:(#29) Remove block views more efficiently.
      var blockLayoutSet = Set<BlockLayout>()
      for blockLayout in allBlockLayouts {
        blockLayoutSet.insert(blockLayout)
      }

      // For all block views, check if the layout exists in `self.workspaceLayout`. If it doesn't,
      // then the block view has been removed.
      for view in scrollView.blockGroupView.subviews {
        if let blockView = view as? BlockView {
          if blockView.blockLayout == nil || !blockLayoutSet.contains(blockView.blockLayout!) {
            removeBlockView(blockView)
          }
        }
      }
    }

    if flags.intersectsWith([Layout.Flag_NeedsDisplay, WorkspaceLayout.Flag_UpdateCanvasSize]) {
      updateCanvasSizeFromLayout()
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    // Remove all block views
    for view in scrollView.blockGroupView.subviews {
      if let blockView = view as? BlockView {
        removeBlockView(blockView)
      }
    }

    scrollView.contentSize = CGSizeZero
    scrollView.contentOffset = CGPointZero
    scrollView.blockGroupView.frame = CGRectZero
  }

  public override func layoutSubviews() {
    super.layoutSubviews()

    updateCanvasSizeFromLayout()
  }

  // MARK: - Public

  /**
   Maps a gesture's touch location relative to this view to a logical Workspace position.

   - Parameter gesture: The gesture
   - Returns: The corresponding `WorkspacePoint` for the gesture
   */
  public final func workspacePositionFromGestureTouchLocation(gesture: UIGestureRecognizer)
    -> WorkspacePoint
  {
    let touchPosition = gesture.locationInView(self.scrollView.blockGroupView)
    return workspacePositionFromViewPoint(touchPosition)
  }

  /**
   Returns the logical Workspace position of a given `BlockView` based on its position relative
   to this `WorkspaceView`.

   - Parameter blockView: The `BlockView`
   - Returns: The `blockView`'s corresponding Workspace position
   */
  public final func workspacePositionFromBlockView(blockView: UIView) -> WorkspacePoint {
    var blockViewPoint = CGPointZero
    if (workspaceLayout?.engine.rtl ?? false) {
      // In RTL, the block's workspace position is mapped to the top-right corner point (whereas
      // it is the top-left corner point in LTR)
      blockViewPoint = CGPointMake(blockView.bounds.width, 0)
    }
    let workspaceViewPosition =
      blockView.convertPoint(blockViewPoint, toView: scrollView.blockGroupView)
    return workspacePositionFromViewPoint(workspaceViewPosition)
  }

  public final func viewPointFromWorkspacePosition(workspacePosition: WorkspacePoint) {

  }

  /**
   Automatically adjusts the workspace's scroll view to bring a given `Block` into view.

   - Parameter block: The `Block` to bring into view
   - Parameter animated: Flag determining if this scroll view adjustment should be animated.
   - Note: See `scrollIntoViewEdgeInsets`.
   */
  public func scrollBlockIntoView(block: Block, animated: Bool) {
    guard let blockLayout = block.layout,
      let blockView = ViewManager.sharedInstance.findBlockViewForLayout(blockLayout) else
    {
      return
    }

    var scrollViewRect =
      CGRectMake(scrollView.contentOffset.x, scrollView.contentOffset.y,
                 scrollView.bounds.width, scrollView.bounds.height)

    // Force the blockView to be inset within the scroll view rectangle
    scrollViewRect.origin.x += scrollIntoViewEdgeInsets.left
    scrollViewRect.size.width -= scrollIntoViewEdgeInsets.left + scrollIntoViewEdgeInsets.right
    scrollViewRect.origin.y += scrollIntoViewEdgeInsets.top
    scrollViewRect.size.height -= scrollIntoViewEdgeInsets.top + scrollIntoViewEdgeInsets.bottom

    let blockViewRect = blockView.convertRect(blockView.bounds, toView: scrollView)
    var contentOffset = scrollView.contentOffset

    // Check right edge
    if blockViewRect.maxX > scrollViewRect.maxX {
      contentOffset.x += (blockViewRect.maxX - scrollViewRect.maxX)
    }
    // Check left edge
    if blockViewRect.minX < scrollViewRect.minX {
      contentOffset.x -= (scrollViewRect.minX - blockViewRect.minX)
    }
    // Check bottom edge
    if blockViewRect.maxY > scrollViewRect.maxY {
      contentOffset.y += (blockViewRect.maxY - scrollViewRect.maxY)
    }
    // Check top edge
    if blockViewRect.minY < scrollViewRect.minY {
      contentOffset.y -= (scrollViewRect.minY - blockViewRect.minY)
    }

    if scrollView.contentOffset != contentOffset {
      scrollView.setContentOffset(contentOffset, animated: animated)
    }
  }

  // MARK: - Private

  /**
  Maps a `UIView` point relative to `self.scrollView.blockGroupView` to a logical Workspace
  position.

  - Parameter point: The `UIView` point
  - Returns: The corresponding `WorkspacePoint`
  */
  private func workspacePositionFromViewPoint(point: CGPoint) -> WorkspacePoint {
    guard let workspaceLayout = self.workspaceLayout else {
      return WorkspacePointZero
    }

    var viewPoint = point

    if workspaceLayout.engine.rtl {
      // In RTL, the workspace position is relative to the top-right corner of
      // `scrollView.blockGroupView`
      viewPoint.x = scrollView.blockGroupView.frame.width - viewPoint.x
    }

    // Account for the current content origin
    let viewContentOrigin =
      workspaceLayout.engine.viewPointFromWorkspacePoint(workspaceLayout.contentOrigin)
    viewPoint.x += viewContentOrigin.x
    viewPoint.y += viewContentOrigin.y

    // Scale this CGPoint (ie. `viewPoint`) into a WorkspacePoint
    return workspaceLayout.engine.scaledWorkspaceVectorFromViewVector(viewPoint)
  }

  private func updateCanvasSizeFromLayout() {
    guard let layout = self.workspaceLayout else {
      return
    }

    // Disable inadvertent calls to `removeExcessScrollSpace()`
    _disableRemoveExcessScrollSpace = true

    // Get the total canvas size in UIView sizing
    let blockGroupSize = layout.engine.viewSizeFromWorkspaceSize(layout.totalSize)

    // Figure out the amount that the content jumped by (based on the new content origin)
    let contentDelta = _lastKnownContentOrigin - layout.contentOrigin
    let contentViewDelta = layout.engine.viewPointFromWorkspacePoint(contentDelta)

    // Calculate the extra padding to add around the content
    var contentPadding = EdgeInsets(0, 0, 0, 0)
    if allowCanvasPadding {
      // Content padding must be at least two full screen sizes in all directions or else
      // blocks will appear to jump whenever the total canvas size shrinks (eg. after blocks are
      // moved from higher value coordinates to lower value ones) or grows in the negative
      // direction. Any unnecessary padding is removed at the end in `removeExcessScrollSpace()`.
      contentPadding.top = scrollView.bounds.height + canvasPadding.top
      contentPadding.leading = scrollView.bounds.width + canvasPadding.leading
      contentPadding.bottom = scrollView.bounds.height + canvasPadding.bottom
      contentPadding.trailing = scrollView.bounds.width + canvasPadding.trailing
    } else if layout.engine.rtl {
      // In RTL, the canvas width needs to completely fill the entire scroll view frame to make
      // sure that content appears right-aligned.
      contentPadding.trailing = max(scrollView.bounds.width - blockGroupSize.width, 0)
    }

    // Calculate the new `contentSize` for the scroll view
    var newContentSize = blockGroupSize
    newContentSize.width += contentPadding.leading + contentPadding.trailing
    newContentSize.height += contentPadding.top + contentPadding.bottom

    // Update the content size of the scroll view.
    if layout.engine.rtl {
      var oldBlockGroupFrame = scrollView.blockGroupView.frame

      if oldBlockGroupFrame.width < 1 && oldBlockGroupFrame.height < 1 {
        // If the previous block group size was (0, 0), it was never actually positioned.
        // For the sake of calculation purposes below, it is assumed that
        // `scrollView.blockGroupView` is always anchored to the top-right corner. Therefore, we
        // simply set the `oldBlockGroupFrame.origin.x` to the right edge of the scrollView's
        // bounds.
        oldBlockGroupFrame.origin.x =
          scrollView.bounds.width - (allowCanvasPadding ? canvasPadding.leading : 0)
      }

      // Position the blockGroupView relative to the top-right corner
      let blockGroupOrigin = CGPointMake(
        newContentSize.width - blockGroupSize.width - contentPadding.leading, contentPadding.top)
      scrollView.blockGroupView.frame = CGRectMake(
        blockGroupOrigin.x, blockGroupOrigin.y, blockGroupSize.width, blockGroupSize.height)

      // The content offset must be adjusted based on the new content origin, so it doesn't
      // appear that viewport has jumped to a new location
      // NOTE: In RTL, we jump in the opposite X direction
      scrollView.contentOffset.x -= contentViewDelta.x
      scrollView.contentOffset.y += contentViewDelta.y

      // The block group origin may have changed since the last call to
      // `updateCanvasSizeFromLayout()`, so we need to adjust the content offset for this too.
      // NOTE: In RTL, `contentOffset.x` is adjusted based on the right edge, not the left edge.
      scrollView.contentOffset.x += scrollView.blockGroupView.frame.maxX - oldBlockGroupFrame.maxX
      scrollView.contentOffset.y += scrollView.blockGroupView.frame.minY - oldBlockGroupFrame.minY
    } else {
      let blockGroupOrigin = CGPointMake(contentPadding.leading, contentPadding.top)
      let oldBlockGroupFrame = scrollView.blockGroupView.frame
      scrollView.blockGroupView.frame = CGRectMake(
        blockGroupOrigin.x, blockGroupOrigin.y, blockGroupSize.width, blockGroupSize.height)

      // The content offset must be adjusted based on the new content origin, so it doesn't appear
      // that viewport has jumped to a new location
      scrollView.contentOffset.x += contentViewDelta.x
      scrollView.contentOffset.y += contentViewDelta.y

      // The block group origin may have changed since the last call to
      // `updateCanvasSizeFromLayout()`, so we need to adjust the content offset for this too.
      scrollView.contentOffset.x += scrollView.blockGroupView.frame.minX - oldBlockGroupFrame.minX
      scrollView.contentOffset.y += scrollView.blockGroupView.frame.minY - oldBlockGroupFrame.minY
    }

    // Set the content size of the scroll view
    // NOTE: This has to be done *after* adjusting the `scrollView.contentOffset`. `UIScrollView`
    // will automatically adjust `contentOffset` on its own if `contentSize` shrinks and the
    // the current `contentOffset` is unreachable (but it won't change if it grows, which is why we
    // adjust `contentOffset` manually first).
    scrollView.contentSize = newContentSize

    _lastKnownContentOrigin = layout.contentOrigin

    // Re-enable `removeExcessScrollSpace()` and call it
    _disableRemoveExcessScrollSpace = false
    removeExcessScrollSpace()
  }

  private func removeExcessScrollSpace() {
    if !allowCanvasPadding || _disableRemoveExcessScrollSpace ||
      scrollView.tracking || scrollView.dragging || scrollView.decelerating
    {
      return
    }
    guard let layout = self.workspaceLayout else {
      return
    }

    // Disable this method from recursively calling itself
    _disableRemoveExcessScrollSpace = true

    // Figure out the ideal placement for the scrollView.blockGroupView. This helps us figure out
    // the excess scrolling area that can be removed from the canvas.
    let idealBlockGroupFrame: CGRect
    if layout.engine.rtl {
      // The block group in RTL must always appear right-aligned on-screen, so we calculate an
      // origin that takes into account the block group's width and the current scrollView width
      let originX = max(canvasPadding.trailing,
        scrollView.bounds.width - scrollView.blockGroupView.frame.width -
          canvasPadding.leading)
      idealBlockGroupFrame = CGRectMake(
        originX,
        canvasPadding.top,
        scrollView.blockGroupView.frame.width + canvasPadding.leading,
        scrollView.blockGroupView.frame.height + canvasPadding.bottom)
    } else {
      idealBlockGroupFrame = CGRectMake(canvasPadding.leading, canvasPadding.top,
        scrollView.blockGroupView.frame.width + canvasPadding.trailing,
        scrollView.blockGroupView.frame.height + canvasPadding.bottom)
    }

    // Remove excess left space
    let leftExcessSpace = scrollView.blockGroupView.frame.minX - idealBlockGroupFrame.minX

    if leftExcessSpace > 0 && scrollView.contentOffset.x >= 0 {
      let adjustment = min(leftExcessSpace, scrollView.contentOffset.x)
      scrollView.contentOffset.x -= adjustment
      scrollView.contentSize.width -= adjustment
      scrollView.blockGroupView.frame.origin.x -= adjustment
    }

    // Remove excess right space
    let rightExcessSpace = scrollView.contentSize.width -
      (scrollView.blockGroupView.frame.minX + idealBlockGroupFrame.width)

    if rightExcessSpace > 0 &&
      (scrollView.contentOffset.x + scrollView.bounds.width) <= scrollView.contentSize.width
    {
      let adjustment = min(rightExcessSpace,
        scrollView.contentSize.width - (scrollView.contentOffset.x + scrollView.bounds.width))
      scrollView.contentSize.width -= adjustment
    }

    // Remove excess top space
    let topExcessSpace = scrollView.blockGroupView.frame.minY - idealBlockGroupFrame.minY
    if topExcessSpace > 0 && scrollView.contentOffset.y >= 0 {
      let adjustment = min(topExcessSpace, scrollView.contentOffset.y)
      scrollView.contentOffset.y -= adjustment
      scrollView.contentSize.height -= adjustment
      scrollView.blockGroupView.frame.origin.y -= adjustment
    }

    // Remove excess bottom space
    let bottomExcessSpace = scrollView.contentSize.height -
      (scrollView.blockGroupView.frame.origin.y + idealBlockGroupFrame.height)

    if bottomExcessSpace > 0 &&
      (scrollView.contentOffset.y + scrollView.bounds.height) <= scrollView.contentSize.height
    {
      let adjustment = min(bottomExcessSpace,
        scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.bounds.height)
      scrollView.contentSize.height -= adjustment
    }

    // Re-enable this method
    _disableRemoveExcessScrollSpace = false
  }

  /**
  Returns true if a given block layout should be rendered within the workspace view.
  Otherwise, false is returned.

  - Parameter blockLayout: A given block layout.
  */
  private func shouldRenderBlockLayout(blockLayout: BlockLayout) -> Bool {
    // Allow blocks within a 1/2 screen away to be rendered
    let xDelta = scrollView.contentSize.width / 2
    let yDelta = scrollView.contentSize.height / 2
    let minX = scrollView.contentOffset.x - xDelta
    let maxX = scrollView.contentOffset.x + scrollView.contentSize.width + xDelta
    let minY = scrollView.contentOffset.y - yDelta
    let maxY = scrollView.contentOffset.y + scrollView.contentSize.height + yDelta
    let leftMostEdge = blockLayout.viewFrame.minX
    let rightMostEdge = blockLayout.viewFrame.maxX
    let topMostEdge = blockLayout.viewFrame.minY
    let bottomMostEdge = blockLayout.viewFrame.maxY

    return
      ((minX <= leftMostEdge && leftMostEdge <= maxX) ||
      (minX <= rightMostEdge && rightMostEdge <= maxX)) &&
      ((minY <= topMostEdge && topMostEdge <= maxY) ||
      (minY <= bottomMostEdge && bottomMostEdge <= maxY))
  }

  /**
  Creates a block view for a given layout and adds it to the scroll view.

  - Parameter layout: The given layout
  - Throws:
  `BlocklyError`: Thrown if the block view could not be added
  */
  private func addBlockViewForLayout(layout: BlockLayout) throws {
    let newBlockView = try ViewFactory.sharedInstance.blockViewForLayout(layout)
    scrollView.blockGroupView.upsertView(newBlockView)

    delegate?.workspaceView(self, didAddBlockView: newBlockView)
  }

  /**
  Removes a given block view from the scroll view and recycles it.

  - Parameter blockView: The given block view
  */
  private func removeBlockView(blockView: BlockView) {
    delegate?.workspaceView(self, willRemoveBlockView: blockView)

    blockView.removeFromSuperview()
    ViewFactory.sharedInstance.recycleView(blockView)
  }
}


// MARK: - UIScrollViewDelegate Implementation

extension WorkspaceView: UIScrollViewDelegate {
  public func scrollViewDidScroll(scrollView: UIScrollView) {
    removeExcessScrollSpace()
  }

  public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
    removeExcessScrollSpace()
  }

  public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    removeExcessScrollSpace()
  }
}

// MARK: - WorkspaceView.ScrollView Class

// TODO:(#46) Distinguish between swipe vs pan gestures

extension WorkspaceView {
  /**
  A custom version of UIScrollView that can properly distinguish between dragging blocks and
  scrolling the workspace, in a performant way.

  The simple approach is to call `self.panGestureRecognizer.requireGestureRecognizerToFail(:)` on
  each block's set of gesture recognizers. Unfortunately, this doesn't scale and causes
  very slow initialization times. Another approach would be to assign this instance as a delegate of
  `self.panGestureRecognizer.delegate` in order to control its behaviour, but that doesn't work
  because the delegate assignment is protected by `UIScrollView`.

  The alternative approach implemented here is to create a "fake" UIPanGestureRecognizer on which
  `self.panGestureRecognizer` depends on. This allows us to kill `self.panGestureRecognizer` from
  triggering if we can determine a block is being dragged.
  */
  public class ScrollView: UIScrollView, UIGestureRecognizerDelegate {
    /// View which holds all the block views
    public private(set) var blockGroupView: ZIndexedGroupView = {
      let blockGroupView = ZIndexedGroupView(frame: CGRectZero)
      blockGroupView.autoresizesSubviews = false
      return blockGroupView
    }()

    /// The fake pan gesture recognizer
    private lazy var _fakePanGestureRecognizer: UIPanGestureRecognizer = {
      let fakePanGestureRecognizer = UIPanGestureRecognizer()
      fakePanGestureRecognizer.delegate = self
      return fakePanGestureRecognizer
    }()

    /// The first touch of the fake pan gesture recognizer
    private var _firstTouch: UITouch?

    // MARK: - Initializers

    private override init(frame: CGRect) {
      super.init(frame: frame)

      addGestureRecognizer(_fakePanGestureRecognizer)
      panGestureRecognizer.requireGestureRecognizerToFail(_fakePanGestureRecognizer)

      addSubview(blockGroupView)

      delaysContentTouches = false
    }

    public required init?(coder aDecoder: NSCoder) {
      fatalError("Called unsupported initializer")
    }

    // MARK: - Super

    @objc public final func gestureRecognizer(
      gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool
    {
      if gestureRecognizer == _fakePanGestureRecognizer && !self.decelerating && !self.dragging
      {
        // Register the first touch point of the fake gesture recognizer, now that the scroll view
        // is "at rest".
        _firstTouch = touch
      }

      return true
    }

    public final override func gestureRecognizerShouldBegin(
      gestureRecognizer: UIGestureRecognizer) -> Bool
    {
      // This method is called when a gesture recognizer wants to transition from the "Possible"
      // state to the "Began" state (ie. triggering the gesture recognizer).
      if gestureRecognizer == _fakePanGestureRecognizer {
        if _firstTouch != nil {
          let firstTouchLocation = _firstTouch!.locationInView(blockGroupView)
          let hitTestView = blockGroupView.hitTest(firstTouchLocation, withEvent: nil)
          if hitTestView != nil && hitTestView != blockGroupView {
            // The user is dragging something, but the first touch did not begin inside the scroll
            // view, which can only mean that the user is dragging a block. Therefore, we need to
            // temporarily disable panning of the scroll view by forcing it to transition into a
            // Cancel state.
            self.panGestureRecognizer.enabled = false

            // Re-enable it for the future
            self.panGestureRecognizer.enabled = true
          }

          _firstTouch = nil
        }

        // This fake gesture recognizer should always fail to allow legitimate gesture recognizers
        // to be recognized. If `self.panGestureRecognizer` wasn't cancelled from above, it will
        // now be allowed to recognize the current gesture.
        return false
      }

      return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
  }
}
