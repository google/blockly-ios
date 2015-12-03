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

import UIKit

/**
 View controller for editing a workspace.
 */
@objc(BKYWorkbenchViewController)
public class WorkbenchViewController: UIViewController {

  // MARK: - Properties

  /// The main workspace
  public var workspace: Workspace? {
    didSet {
      loadWorkspaceIntoView()
    }
  }

  /// Controls logic for dragging blocks around in the workspace
  private var _dragger = Dragger()

  /// The main workspace view
  @IBOutlet public var workspaceView: WorkspaceView! {
    didSet {
      oldValue?.delegate = nil
      workspaceView?.delegate = self
    }
  }

  // MARK: - Initializers

  public init() {
    super.init(nibName: nil, bundle: nil)
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func loadView() {
    super.loadView()

    // Create views if ones weren't supplied by a xib file
    self.workspaceView = WorkspaceView()
    workspaceView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
    workspaceView.frame = self.view.bounds
    workspaceView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    self.view.addSubview(workspaceView)
    self.view.sendSubviewToBack(workspaceView)
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    loadWorkspaceIntoView()
  }

  // MARK: - Private

  /**
  If it exists, loads `self.workspace.layout` into `self.workspaceView`.
  */
  private func loadWorkspaceIntoView() {
    guard let
      workspaceLayout = workspace?.layout,
      workspaceView = self.workspaceView else
    {
      return
    }

    workspaceView.layout = workspaceLayout
    workspaceView.refreshView()
  }
}

// MARK: - WorkspaceViewDelegate

extension WorkbenchViewController: WorkspaceViewDelegate {
  public func workspaceView(workspaceView: WorkspaceView, didAddBlockView blockView: BlockView) {
    if workspaceView == self.workspaceView {
      addGestureTrackingForBlockView(blockView)
    }
  }

  public func workspaceView(
    workspaceView: WorkspaceView, willRemoveBlockView blockView: BlockView)
  {
    if workspaceView == self.workspaceView {
      removeGestureTrackingForBlockView(blockView)
    }
  }
}

// MARK: - Gesture Tracking

extension WorkbenchViewController {
  /**
   Adds pan and tap gesture recognizers to a block view.

   - Parameter blockView: A given block view.
   */
  private func addGestureTrackingForBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()

    let panGesture = UIPanGestureRecognizer(target: self, action: "didRecognizePanGesture:")
    panGesture.maximumNumberOfTouches = 1
    blockView.addGestureRecognizer(panGesture)

    let tapGesture = UITapGestureRecognizer(target: self, action: "didRecognizeTapGesture:")
    blockView.addGestureRecognizer(tapGesture)
  }

  /**
   Removes all gesture recognizers and any on-going gesture data from a block view.

   - Parameter blockView: A given block view.
   */
  private func removeGestureTrackingForBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()

    if let blockLayout = blockView.blockLayout {
      _dragger.clearGestureDataForBlockLayout(blockLayout)
    }
  }

  /**
   Event handler for a UIPanGestureRecognizer.
   */
  internal func didRecognizePanGesture(gesture: UIPanGestureRecognizer) {
    guard let blockView = gesture.view as? BlockView,
      blockLayout = blockView.blockLayout else {
        return
    }

    let touchPosition = self.workspaceView.workspaceLayout!.workspacePointFromViewPoint(
      gesture.locationInView(self.workspaceView))

    // TODO:(vicng) Handle screen rotations (either lock the screen during drags or stop any
    // on-going drags when the screen is rotated).

    if gesture.state == .Began {
      _dragger.startDraggingBlockLayout(blockLayout, touchPosition: touchPosition)
    } else if gesture.state == .Changed || gesture.state == .Cancelled || gesture.state == .Ended {
      _dragger.continueDraggingBlockLayout(blockLayout, touchPosition: touchPosition)
    }

    if gesture.state == .Cancelled || gesture.state == .Ended || gesture.state == .Failed {
      _dragger.finishDraggingBlockLayout(blockLayout)

      // HACK: Re-add gesture tracking for the block view, as there is a problem re-recognizing
      // them when dragging multiple blocks simultaneously
      addGestureTrackingForBlockView(blockView)
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
