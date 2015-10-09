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
public class WorkspaceView: UIScrollView {
  // MARK: - Properties

  /// Stores the location of the block view's start position for a pan gesture
  private var panGestureBlockViewStartPosition: WorkspacePoint?

  /// Stores the first touch location of a pan gesture
  private var panGestureFirstTouchPosition: WorkspacePoint?

  /// Layout object to render
  public var layout: WorkspaceLayout! {
    didSet {
      self.frame = layout?.viewFrame ?? CGRectZero
      // TODO:(vicng) Re-draw this view too
    }
  }

  /// Manager for acquiring and recycling views.
  private let _viewManager = ViewManager.sharedInstance

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // MARK: - Public

  /**
  Refreshes the view based on the current layout. Only blocks that are visible or near the current
  viewport are refreshed.
  */
  public func refresh() {
    // TODO:(vicng) Figure out a good amount to pad the workspace by
    self.contentSize = CGSizeMake(
      layout.totalSize.width + UIScreen.mainScreen().bounds.size.width,
      layout.totalSize.height + UIScreen.mainScreen().bounds.size.height)

    // Get blocks that are in the current viewport
    for descendantLayout in layout.allBlockLayoutDescendants() {
      if !shouldRenderLayout(descendantLayout) {
        return
      }

      let descendantView = _viewManager.blockViewForLayout(descendantLayout)
      descendantView.addGestureRecognizer(
        UIPanGestureRecognizer(target: self, action: "didRecognizePanGesture:"))
      descendantView.addGestureRecognizer(
        UITapGestureRecognizer(target: self, action: "didRecognizeTapGesture:"))

      if descendantView.superview != nil {
        descendantView.removeFromSuperview()
      }
      addSubview(descendantView)
    }
  }

  // MARK: - Private

  private func shouldRenderLayout(layout: Layout) -> Bool {
    // TODO:(vicng) Implement this method
    return true
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
      // Store the start position of the block view and first touch point, but don't do anything yet
      panGestureBlockViewStartPosition = blockView.layout?.absolutePosition
      panGestureFirstTouchPosition =
        layout.workspacePointFromViewPoint(gesture.locationInView(self))
    } else if gesture.state == .Changed || gesture.state == .Cancelled || gesture.state == .Ended {
      // Handle actual panning of the view
      let currentWorkspacePoint = layout.workspacePointFromViewPoint(gesture.locationInView(self))

      if (blockView.layout?.topBlockInBlockLayout == true) ?? false {
        // TODO:(vicng) Disconnect this block from its block group layout, prior to moving it
      }

      blockView.layout?.parentBlockGroupLayout.moveToWorkspacePosition(
        panGestureBlockViewStartPosition! + currentWorkspacePoint - panGestureFirstTouchPosition!)
    }

    // Reset ivars if the gesture has finished
    if gesture.state == .Cancelled || gesture.state == .Ended || gesture.state == .Failed {
      panGestureFirstTouchPosition = nil
      panGestureBlockViewStartPosition = nil
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
