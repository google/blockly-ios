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
  private var scrollView: UIScrollView!

  /// Manager for acquiring and recycling views.
  private let _viewManager = ViewManager.sharedInstance

  /// Controls logic for dragging blocks around in the workspace
  private var _dragger: Dragger!

  // MARK: - Initializers

  public required init() {
    self.scrollView = UIScrollView(frame: CGRectZero)
    super.init(frame: CGRectZero)

    _dragger = Dragger(workspaceView: self)

    scrollView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    self.autoresizesSubviews = true
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
    scrollView.contentSize = CGSizeMake(
      layout.totalSize.width + UIScreen.mainScreen().bounds.size.width,
      layout.totalSize.height + UIScreen.mainScreen().bounds.size.height)
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
    newBlockView.bky_removeAllGestureRecognizers()

    let panGesture = UIPanGestureRecognizer(target: self, action: "didRecognizePanGesture:")
    panGesture.maximumNumberOfTouches = 1
    newBlockView.addGestureRecognizer(panGesture)

    let tapGesture = UITapGestureRecognizer(target: self, action: "didRecognizeTapGesture:")
    newBlockView.addGestureRecognizer(tapGesture)

    scrollView.addSubview(newBlockView)
  }

  /**
  Removes a given block view from the scroll view and recycles it.

  - Parameter blockView: The given block view
  */
  private func removeBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()
    blockView.removeFromSuperview()

    if let blockLayout = blockView.blockLayout {
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
    guard let blockView = gesture.view as? BlockView else {
      return
    }

    if gesture.state == .Began {
      _dragger.startDraggingBlock(blockView, gesture: gesture)
    } else if gesture.state == .Changed || gesture.state == .Cancelled || gesture.state == .Ended {
      _dragger.continueDraggingBlock(blockView, gesture: gesture)
    }

    if gesture.state == .Cancelled || gesture.state == .Ended || gesture.state == .Failed {
      _dragger.finishDraggingBlock(blockView, gesture: gesture)
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
