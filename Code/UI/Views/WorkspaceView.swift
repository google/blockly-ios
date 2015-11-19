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
  private var scrollView: WorkspaceView.ScrollView!

  /// Manager for acquiring and recycling views.
  private let _viewManager = ViewManager.sharedInstance

  /// Controls logic for dragging blocks around in the workspace
  private var _dragger = Dragger()

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

  public override func internalRefreshView() {
    guard let layout = self.layout as? WorkspaceLayout else {
      return
    }

    // Get blocks that are in the current viewport
    for blockLayout in layout.allBlockLayoutDescendants() {
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

  public override func internalPrepareForReuse() {
    guard let layout = self.layout as? WorkspaceLayout else {
      return
    }

    // Remove all block views
    for blockLayout in layout.allBlockLayoutDescendants() {
      if let blockView = _viewManager.cachedBlockViewForLayout(blockLayout) {
        removeBlockView(blockView)
      }
    }
  }

  public override func refreshPosition() {
    guard let layout = self.layout as? WorkspaceLayout else {
      return
    }

    // NOTE: This method purposely does not call super.refreshPosition() since that automatically
    // sets `viewFrame` and `layer.zPosition` -- things that don't need to be done by this view.

    // Set the content size of the scroll view.
    // TODO:(vicng) Figure out a good amount to pad the workspace by
    scrollView.blockGroupView.frame = CGRectMake(0, 0,
      layout.totalSize.width + UIScreen.mainScreen().bounds.size.width,
      layout.totalSize.height + UIScreen.mainScreen().bounds.size.height)
    scrollView.contentSize = scrollView.blockGroupView.bounds.size
  }

  // MARK: - Private

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
    addGestureRecognizersForBlockView(newBlockView)
    scrollView.blockGroupView.upsertBlockView(newBlockView)
  }

  /**
  Adds pan and tap gesture recognizers to a block view.
  
  - Parameter blockView: A given block view.
  */
  private func addGestureRecognizersForBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()

    let panGesture = UIPanGestureRecognizer(target: self, action: "didRecognizePanGesture:")
    panGesture.maximumNumberOfTouches = 1
    blockView.addGestureRecognizer(panGesture)

    let tapGesture = UITapGestureRecognizer(target: self, action: "didRecognizeTapGesture:")
    blockView.addGestureRecognizer(tapGesture)
  }

  /**
  Removes a given block view from the scroll view and recycles it.

  - Parameter blockView: The given block view
  */
  private func removeBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()
    blockView.removeFromSuperview()

    if let blockLayout = blockView.blockLayout {
      _dragger.clearGestureDataForBlockLayout(blockLayout)
      _viewManager.uncacheBlockViewForLayout(blockLayout)
    }
    _viewManager.recycleView(blockView)
  }
}

// MARK: - Gesture Recognizers

extension WorkspaceView {
  /**
  Event handler for a UIPanGestureRecognizer.
  */
  internal func didRecognizePanGesture(gesture: UIPanGestureRecognizer) {
    guard let blockView = gesture.view as? BlockView,
      blockLayout = blockView.blockLayout else {
      return
    }

    let touchPosition =
      workspaceLayout!.workspacePointFromViewPoint(gesture.locationInView(self))

    // TODO:(vicng) Handle screen rotations (either lock the screen during drags or stop any
    // on-going drags when the screen is rotated).

    if gesture.state == .Began {
      _dragger.startDraggingBlockLayout(blockLayout, touchPosition: touchPosition)
    } else if gesture.state == .Changed || gesture.state == .Cancelled || gesture.state == .Ended {
      _dragger.continueDraggingBlockLayout(blockLayout, touchPosition: touchPosition)
    }

    if gesture.state == .Cancelled || gesture.state == .Ended || gesture.state == .Failed {
      _dragger.finishDraggingBlockLayout(blockLayout)

      // HACK: Re-add gesture recognizers for the block view, as there is a problem re-recognizing
      // them when dragging multiple blocks simultaneously
      addGestureRecognizersForBlockView(blockView)
    }
  }

  /**
  Event handler for a UITapGestureRecognizer.
  */
  internal func didRecognizeTapGesture(gesture: UITapGestureRecognizer) {
    guard let blockView = gesture.view as? BlockView else {
      return
    }

    // TODO:(vicng) Set this block as "selected" within the workspace
  }
}

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
    private var blockGroupView: BlockGroupView!

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
  /**
  UIView which holds `BlockView` instances, where instances are ordered in the subview list by their
  `zIndex` property. This causes each `BlockView` to be rendered and hit-tested inside
  `BlockGroupView` based on their `zIndex`.
  */
  public class BlockGroupView: UIView {
    /**
    Inserts or updates a given `BlockView` to this block group, where it is sorted inside
    `BlockGroupView` based on its `zIndex`.

    - Parameter blockView: The given block view
    */
    public func upsertBlockView(blockView: BlockView) {
      // TODO(vicng): This method is causing performance problems when bringing lots of blocks to
      // the front at the same time. Calling `self.subviews` may be the culprit (more investigation
      // is needed).
      let zIndex = blockView.zIndex

      // More often than not, the target blockView's zIndex will be >= the zIndex of the highest
      // subview anyway. Quickly check to see if that's the case.
      let lastBlockView = (self.subviews.last as? BlockView)
      if lastBlockView == nil ||
        (blockView != lastBlockView && blockView.zIndex >= lastBlockView!.zIndex) {
          self.insertSubview(blockView, atIndex: self.subviews.count)
          return
      }

      // Binary search to find the correct position of where the block view should be, based on its
      // z-index.

      // Initialize clamps
      var min = 0
      var max = self.subviews.count

      if blockView.superview == self {
        // If blockView is already in this group, temporarily move it to the end.
        // NOTE: blockView is purposely not removed from this view prior to running this method, as
        // it will cause any active gesture recognizers on the blockView to be cancelled. Therefore,
        // the blockView is simply skipped over if it is found in the binary search.
        self.insertSubview(blockView, atIndex: self.subviews.count)
        max = self.subviews.count - 1 // Don't include this blockView in the binary search range
      }

      while (min < max) {
        let currentMid = (min + max) / 2
        let currentZIndex = (self.subviews[currentMid] as! BlockView).zIndex

        if (currentZIndex < zIndex) {
          min = currentMid + 1
        } else if (currentZIndex > zIndex) {
          max = currentMid
        } else {
          min = currentMid
          break
        }
      }

      // This will insert the block view at the correct index, or update its index position if it
      // is already a subview.
      self.insertSubview(blockView, atIndex: min)
    }
  }
}
