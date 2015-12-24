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

  /// The underlying workspace
  public var workspace: Workspace?
  /// The underlying toolbox
  public var toolbox: Toolbox?

  /// Controls logic for dragging blocks around in the workspace
  private var _dragger = Dragger()

  /// The main workspace view
  @IBOutlet public var workspaceView: WorkspaceView! {
    didSet {
      oldValue?.delegate = nil
      workspaceView?.delegate = self
    }
  }

  // The toolbox view
  @IBOutlet public var toolboxView: ToolboxView! {
    didSet {
      // We need to listen for when block views are added/removed from the block list
      // so we can attach pan gesture recognizers to those blocks (for dragging them onto
      // the workspace)
      oldValue?.blockListView.delegate = nil
      toolboxView?.blockListView.delegate = self
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

    self.view.backgroundColor = UIColor.whiteColor()
    self.view.autoresizesSubviews = true
    self.view.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]

    // Create views if ones weren't supplied by a xib file
    toolboxView = ToolboxView()

    workspaceView = WorkspaceView()
    workspaceView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)

    // Set up auto-layout constraints
    let views = ["toolboxView": toolboxView, "workspaceView": workspaceView]
    let metrics = ["toolboxWidth": ToolboxView.CategoryListViewWidth]
    let constraints = [
      "H:|[toolboxView]",
      "H:|-toolboxWidth-[workspaceView]|",
      "V:|[toolboxView]|",
      "V:|[workspaceView]|",
    ]

    self.view.bky_addSubviews(Array(views.values))
    self.view.bky_addVisualFormatConstraints(constraints, metrics: metrics, views: views)

    self.view.bringSubviewToFront(toolboxView)
  }

  // MARK: - Public

  /**
  Refreshes the UI based on the current version of `self.workspace` and `self.toolbox`.
  */
  public func refreshView() {
    workspaceView.layout = workspace?.layout
    workspaceView.refreshView()

    toolboxView.toolbox = toolbox
    toolboxView.refreshView()
  }
}

// MARK: - WorkspaceViewDelegate

extension WorkbenchViewController: WorkspaceViewDelegate {
  public func workspaceView(workspaceView: WorkspaceView, didAddBlockView blockView: BlockView) {
    if workspaceView == self.workspaceView {
      addGestureTrackingForBlockView(blockView)
    } else if workspaceView == toolboxView.blockListView {
      addGestureTrackingForToolboxBlockView(blockView)
    }
  }

  public func workspaceView(
    workspaceView: WorkspaceView, willRemoveBlockView blockView: BlockView)
  {
    if workspaceView == self.workspaceView {
      removeGestureTrackingForBlockView(blockView)
    } else if workspaceView == toolboxView.blockListView {
      removeGestureTrackingForToolboxBlockView(blockView)
    }
  }
}

// MARK: - Toolbox Gesture Tracking

extension WorkbenchViewController {
  /**
   Adds a pan gesture recognizer to a toolbox block view.

   - Parameter blockView: A given block view.
   */
  private func addGestureTrackingForToolboxBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()

    let panGesture = UIPanGestureRecognizer(target: self, action: "didRecognizeToolboxPanGesture:")
    panGesture.maximumNumberOfTouches = 1
    blockView.addGestureRecognizer(panGesture)
  }

  /**
   Removes all gesture recognizers from a toolbox block view.

   - Parameter blockView: A given block view.
   */
  private func removeGestureTrackingForToolboxBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()
  }

  /**
   Pan gesture event handler for a block view inside `self.toolboxView`.
  */
  private dynamic func didRecognizeToolboxPanGesture(gesture: UIPanGestureRecognizer) {
    guard let
      toolboxBlockView = gesture.view as? BlockView,
      workspaceLayout = self.workspace?.layout else
    {
      return
    }

    if gesture.state == UIGestureRecognizerState.Began {
      // Copy the toolbox block view into the workspace view
      let newBlockView: BlockView
      do {
        newBlockView = try workspaceView.copyBlockView(toolboxBlockView)
      } catch let error as NSError {
        bky_assertionFailure("Could not copy toolbox block view into workspace view: \(error)")
        return
      }

      // Transfer this gesture recognizer from the toolbox block view to the new block view
      gesture.removeTarget(self, action: "didRecognizeToolboxPanGesture:")
      toolboxBlockView.removeGestureRecognizer(gesture)
      gesture.addTarget(self, action: "didRecognizeWorkspacePanGesture:")
      newBlockView.addGestureRecognizer(gesture)

      // Re-add gesture tracking to the toolbox block view for future drags
      addGestureTrackingForToolboxBlockView(toolboxBlockView)

      // Start the first step of dragging the block layout
      let touchPosition = workspaceView.workspacePointFromGestureTouchLocation(gesture)
      _dragger.startDraggingBlockLayout(newBlockView.blockLayout!, touchPosition: touchPosition)

      // Hide the toolbox category
      toolboxView.hideCategory(animated: false)
    }
  }
}

// MARK: - Workspace Gesture Tracking

extension WorkbenchViewController {
  /**
   Adds pan and tap gesture recognizers to a block view.

   - Parameter blockView: A given block view.
   */
  private func addGestureTrackingForBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()

    let panGesture =
      UIPanGestureRecognizer(target: self, action: "didRecognizeWorkspacePanGesture:")
    panGesture.maximumNumberOfTouches = 1
    blockView.addGestureRecognizer(panGesture)

    let tapGesture =
      UITapGestureRecognizer(target: self, action: "didRecognizeWorkspaceTapGesture:")
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
   Pan gesture event handler for a block view inside `self.workspaceView`.
   */
  private dynamic func didRecognizeWorkspacePanGesture(gesture: UIPanGestureRecognizer) {
    guard let blockView = gesture.view as? BlockView,
      blockLayout = blockView.blockLayout else {
        return
    }

    let touchPosition = self.workspaceView.workspacePointFromGestureTouchLocation(gesture)

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
   Tap gesture event handler for a block view inside `self.workspaceView`.
   */
  private dynamic func didRecognizeWorkspaceTapGesture(gesture: UITapGestureRecognizer) {
    guard let blockView = gesture.view as? BlockView else {
      return
    }

    // TODO:(vicng) Set this block as "selected" within the workspace
  }
}
