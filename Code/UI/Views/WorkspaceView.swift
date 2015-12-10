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

// TODO:(vicng) By default, Blockly is configured to support auto-layout. Create an option to
// disable it, so it only uses frame-based layouts (which should theoretically result in faster
// rendering).

/**
View for rendering a `WorkspaceLayout`.
*/
@objc(BKYWorkspaceView)
public class WorkspaceView: LayoutView {
  // MARK: - Properties

  /// Layout object to render
  public var workspaceLayout: WorkspaceLayout? {
    return layout as? WorkspaceLayout
  }

  /// Scroll view used to render the workspace
  public private(set) var scrollView: WorkspaceView.ScrollView!

  /// Manager for acquiring and recycling views.
  private let _viewManager = ViewManager.sharedInstance

  /// Delegate for events that occur on this view
  public weak var delegate: WorkspaceViewDelegate?

  public var scrollViewCanvasPadding: CGSize = CGSizeZero {
    didSet {
      updateCanvasSizeFromLayout()
    }
  }

  // MARK: - Initializers

  public required init() {
    self.scrollView = WorkspaceView.ScrollView(frame: CGRectZero)
    super.init(frame: CGRectZero)

    scrollView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    scrollView.autoresizesSubviews = false
    addSubview(scrollView)
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func internalRefreshView(forFlags flags: LayoutFlag) {
    guard let layout = self.workspaceLayout else {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      // Get blocks that are in the current viewport
      for blockLayout in layout.allBlockLayoutsInWorkspace() {
        let blockView = _viewManager.cachedBlockViewForLayout(blockLayout)

        // TODO:(vicng) For now, always render blocks regardless of where they are on the screen.
        // Later on, this should be replaced by shouldRenderBlockLayout(blockLayout).
        let shouldRenderBlockLayout = true
        if !shouldRenderBlockLayout {
          // This layout shouldn't be rendered. If its corresponding view exists, remove it from the
          // workspace view and recycle it.
          if blockView != nil {
            removeBlockView(blockView!)
          }
        } else if blockView == nil {
          // Create a new block view for this layout
          addBlockViewForLayout(blockLayout)
        } else {
          // Do nothing. The block view will handle its own refreshing/repositioning.
        }
      }
    }

    if flags.intersectsWith([Layout.Flag_NeedsDisplay, WorkspaceLayout.Flag_UpdateCanvasSize]) {
      updateCanvasSizeFromLayout()
    }
  }

  public override func updateViewFrameFromLayout() {
    // Do nothing. This view is special in that its `self.frame` should not be set by
    // `self.layout.viewFrame`.
  }

  public override func internalPrepareForReuse() {
    // Remove all block views
    for view in scrollView.blockGroupView.subviews {
      if let blockView = view as? BlockView {
        removeBlockView(blockView)
      }
    }
  }

  // MARK: - Public

  /**
  Copies a block view into this workspace view. This is done by:
  1) Creating a copy of the view's block
  2) Building its layout tree and setting its workspace position to be relative to where the given
  block view is currently on-screen.
  3) Immediately firing all change events that are pending on `LayoutEventManager.sharedInstance`,
  which forces the block view to be created in `self.internalRefreshView(...)`.

  - Parameter blockView: The block view to copy into this workspace.
  - Returns: The new block view that was added to this workspace.
  - Throws:
  `BlocklyError`: Thrown if the block view could not be created.
  */
  public func copyBlockView(blockView: BlockView) throws -> BlockView
  {
    guard let blockLayout = blockView.blockLayout else {
      throw BlocklyError(.LayoutNotFound, "No layout was set for the `blockView` parameter")
    }
    guard let workspaceLayout = self.workspaceLayout else {
      throw BlocklyError(.LayoutNotFound, "No workspace layout has been set for the `self.layout`")
    }

    let workspace = workspaceLayout.workspace

    // TODO:(vicng) Change this to do a deep copy of the block
    // Create a copy of the block
    let newBlock = Block.Builder(block: blockLayout.block).buildForWorkspace(workspace)

    // Get the position of the block view relative to this view, and use that as
    // the position for the newly created block
    let blockPosition =
      blockView.convertPoint(CGPointZero, toView: self.scrollView)
    let newWorkspacePosition = workspaceLayout.workspacePointFromViewPoint(blockPosition)

    // Add the layout tree for the new block to the workspace layout
    try workspaceLayout
        .addLayoutTreeForTopLevelBlock(newBlock, atPosition: newWorkspacePosition)

    // Send change events immediately, which will force the corresponding block view to be created
    LayoutEventManager.sharedInstance.immediatelySendChangeEvents()

    guard
      let newBlockLayout = newBlock.layout,
      let newBlockView = ViewManager.sharedInstance.cachedBlockViewForLayout(newBlockLayout) else
    {
      throw BlocklyError(.ViewNotFound, "View could not be located for the copied block")
    }

    return newBlockView
  }

  // MARK: - Private

  private func updateCanvasSizeFromLayout() {
    guard let layout = self.workspaceLayout else {
      return
    }

    // Update the content size of the scroll view.
    scrollView.blockGroupView.frame = CGRectMake(0, 0,
      layout.totalSize.width + self.scrollViewCanvasPadding.width,
      layout.totalSize.height + self.scrollViewCanvasPadding.height)
    scrollView.contentSize = scrollView.blockGroupView.bounds.size
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
    let leftMostEdge = blockLayout.viewFrame.origin.x
    let rightMostEdge = blockLayout.viewFrame.origin.x + blockLayout.viewFrame.size.width
    let topMostEdge = blockLayout.viewFrame.origin.y
    let bottomMostEdge = blockLayout.viewFrame.origin.y + blockLayout.viewFrame.size.height

    return
      ((minX <= leftMostEdge && leftMostEdge <= maxX) ||
      (minX <= rightMostEdge && rightMostEdge <= maxX)) &&
      ((minY <= topMostEdge && topMostEdge <= maxY) ||
      (minY <= bottomMostEdge && bottomMostEdge <= maxY))
  }

  /**
  Creates a block view for a given layout and adds it to the scroll view.

  - Parameter layout: The given layout
  */
  private func addBlockViewForLayout(layout: BlockLayout) {
    let newBlockView = _viewManager.newBlockViewForLayout(layout)
    scrollView.blockGroupView.upsertBlockView(newBlockView)

    delegate?.workspaceView(self, didAddBlockView: newBlockView)
  }


  /**
  Removes a given block view from the scroll view and recycles it.

  - Parameter blockView: The given block view
  */
  private func removeBlockView(blockView: BlockView) {
    delegate?.workspaceView(self, willRemoveBlockView: blockView)

    blockView.removeFromSuperview()

    if let blockLayout = blockView.blockLayout {
      _viewManager.uncacheBlockViewForLayout(blockLayout)
    }
    _viewManager.recycleView(blockView)
  }
}

// TODO:(vicng) Distinguish between swipe vs pan gestures
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
    public private(set) var blockGroupView: BlockGroupView!

    /// The fake pan gesture recognizer
    private var _fakePanGestureRecognizer: UIPanGestureRecognizer!

    /// The first touch of the fake pan gesture recognizer
    private var _firstTouch: UITouch?

    // MARK: - Initializers

    private override init(frame: CGRect) {
      _fakePanGestureRecognizer = UIPanGestureRecognizer()
      blockGroupView = BlockGroupView(frame: CGRectZero)
      super.init(frame: frame)

      _fakePanGestureRecognizer.delegate = self
      addGestureRecognizer(_fakePanGestureRecognizer)
      self.panGestureRecognizer.requireGestureRecognizerToFail(_fakePanGestureRecognizer)

      blockGroupView.autoresizesSubviews = false
      addSubview(blockGroupView)

      self.delaysContentTouches = false
    }

    public required init?(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)
      bky_assertionFailure("Called unsupported initializer")
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

extension WorkspaceView {
  // TODO(vicng): Handle removing block views
  /**
  UIView which *only* holds `BlockView` instances, where instances are ordered in the subview list
  by their `zIndex` property. This causes each `BlockView` to be rendered and hit-tested inside
  `BlockGroupView` based on their `zIndex`.

  - Note: All block views should be added via `upsertBlockView(:)`. Using any other insertion method
  on this class may have adverse effects. Also, adding any view other than a `BlockView` instance
  will result in an app crash.
  */
  public final class BlockGroupView: UIView {
    /// The highest z-index `BlockView` that has been added to this block group
    private var highestInsertedZIndex: UInt = 0

    /**
    Inserts or updates a `BlockView` in this block group, where it is sorted inside `BlockGroupView`
    based on its `zIndex`.

    - Parameter blockView: The given block view
    */
    public func upsertBlockView(blockView: BlockView) {
      let zIndex = blockView.zIndex

      // More often than not, the target blockView's zIndex will be >= the zIndex of the highest
      // subview anyway. Quickly check to see if that's the case.
      if zIndex >= highestInsertedZIndex {
        upsertBlockViewAtEnd(blockView)
        return
      }

      let isUpdateOperation = (blockView.superview == self)
      if isUpdateOperation {
        // If blockView is already in this group, temporarily move it to the end.
        // NOTE: blockView is purposely not removed from this view prior to running this method, as
        // it will cause any active gesture recognizers on the blockView to be cancelled. Therefore,
        // the blockView is simply skipped over if it is found in the binary search.
        upsertBlockViewAtEnd(blockView)
      }

      // Binary search to find the correct position of where the block view should be, based on its
      // z-index.

      // Calling self.subviews is very expensive -- internally, it does not appear to be an array
      // and is constructed dynamically when called. Only call it once and stuff it in a local var.
      let subviews = self.subviews

      // Initialize clamps
      var min = 0
      var max = isUpdateOperation ?
        // Don't include the last index since that's where the given blockView is now positioned
        (subviews.count - 1) :
        subviews.count

      while (min < max) {
        let currentMid = (min + max) / 2
        let currentZIndex = (subviews[currentMid] as! BlockView).zIndex

        if (currentZIndex < zIndex) {
          min = currentMid + 1
        } else if (currentZIndex > zIndex) {
          max = currentMid
        } else {
          min = currentMid
          break
        }
      }

      // Upsert the block view at the new index
      upsertBlockView(blockView, atIndex: min)
    }

    private func upsertBlockViewAtEnd(blockView: BlockView) {
      upsertBlockView(blockView, atIndex: -1)
    }

    /**
    Upserts a block view into the group.

    - Parameter blockView: The block view to upsert
    - Parameter index: The index to upsert the block view at. If the value is < 0, the block view is
    automatically upserted to the end of `self.subviews`.
    */
    private func upsertBlockView(blockView: BlockView, atIndex index: Int) {
      if index >= 0 {
        // Calling insertSubview(...) on a block view that is already a subview just updates its
        // position in `self.subviews`.
        // Note: Inserting (or re-inserting) a subview at an `index` greater than the number of
        // subviews does not cause an error, it simply puts it at the end.
        insertSubview(blockView, atIndex: index)
      } else {
        // Calling addSubview(_) always adds the view to the end of `self.subviews` (regardless of
        // whether the view was already a subview) and brings it to appear on top of all other
        // subviews.
        addSubview(blockView)
      }

      if blockView.zIndex >= highestInsertedZIndex {
        highestInsertedZIndex = blockView.zIndex
      }
    }
  }
}
