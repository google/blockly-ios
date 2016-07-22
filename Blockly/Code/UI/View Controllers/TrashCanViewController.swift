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
 A view controller for displaying blocks in a trash can.
 */
public class TrashCanViewController: WorkspaceViewController {

  // MARK: - Properties

  /// The layout engine to use for displaying the trash can
  public let engine: LayoutEngine
  /// The layout builder to create layout hierarchies inside the trash can
  public let layoutBuilder: LayoutBuilder
  /// The layout direction to use for `self.workspaceLayout`
  public let layoutDirection: WorkspaceFlowLayout.LayoutDirection

  /// The constraint for resizing the width of `self.workspaceView`
  private var _workspaceViewWidthConstraint: NSLayoutConstraint?
  /// The constraint for resizing the height of `self.workspaceView`
  private var _workspaceViewHeightConstraint: NSLayoutConstraint?
  /// Pointer used for distinguishing changes in `self.bounds`
  private var _kvoContextBounds = 0


  // MARK: - Initializers/Deinitializers

  init(engine: LayoutEngine, layoutBuilder: LayoutBuilder,
       layoutDirection: WorkspaceFlowLayout.LayoutDirection, viewFactory: ViewFactory)
  {
    self.engine = engine
    self.layoutBuilder = layoutBuilder
    self.layoutDirection = layoutDirection
    super.init(viewFactory: viewFactory)

    // Create the workspace and layout representing the trash can
    let workspace = WorkspaceFlow()
    workspace.readOnly = true

    do {
      let workspaceLayout = try WorkspaceFlowLayout(
        workspace: workspace, layoutDirection: layoutDirection, engine: engine,
        layoutBuilder: layoutBuilder)
      try loadWorkspaceLayout(workspaceLayout)
    } catch let error as NSError {
      bky_assertionFailure("Could not create WorkspaceFlowLayout: \(error)")
    }
  }

  public required init?(coder aDecoder: NSCoder) {
    // TODO:(#52) Support the ability to create view controllers from XIBs.
    // Note: Both the layoutEngine and layoutBuilder need to be initialized somehow.
    fatalError("Called unsupported initializer")
  }

  deinit {
    workspaceView.removeObserver(self, forKeyPath: "bounds")
  }

  // MARK: - Super

  public override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = UIColor(white: 0.6, alpha: 0.65)
    workspaceView.allowCanvasPadding = false
    workspaceView.addObserver(self, forKeyPath: "bounds",
      options: NSKeyValueObservingOptions.New, context: &self._kvoContextBounds)
    
    updateMaximumLineBlockSize()
  }

  public override func observeValueForKeyPath(
    keyPath: String?,
    ofObject object: AnyObject?,
    change: [String : AnyObject]?,
    context: UnsafeMutablePointer<Void>)
  {
    if context == &_kvoContextBounds {
      updateMaximumLineBlockSize()
    } else {
      super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
    }
  }

  // MARK: - Public

  /**
   Sets the height of `self.workspaceView`.

   - Parameter height: The new height
   - Parameter animated: Flag determining if the new height should be animated.
   */
  public func setWorkspaceViewHeight(height: CGFloat, animated: Bool) {
    if _workspaceViewHeightConstraint == nil {
      _workspaceViewHeightConstraint = view.bky_addHeightConstraint(0)
    }

    if let constraint = _workspaceViewHeightConstraint where constraint.constant != height {
      view.bky_updateConstraints(animated: animated, update: {
        constraint.constant = height
      })
    }
  }

  /**
   Sets the width of `self.workspaceView`.

   - Parameter width: The new width
   - Parameter animated: Flag determining if the new width should be animated.
   */
  public func setWorkspaceViewWidth(width: CGFloat, animated: Bool) {
    if _workspaceViewWidthConstraint == nil {
      _workspaceViewWidthConstraint = view.bky_addWidthConstraint(0)
    }

    if let constraint = _workspaceViewWidthConstraint where constraint.constant != width {
      view.bky_updateConstraints(animated: animated, update: {
        constraint.constant = width
      })
    }
  }

  // MARK: - Private

  private func updateMaximumLineBlockSize() {
    guard let workspaceLayout = self.workspaceLayout as? WorkspaceFlowLayout else {
      return
    }

    // Constrain the workspace layout max line size to the view's width or height
    workspaceLayout.maximumLineBlockSize =
      layoutDirection == WorkspaceFlowLayout.LayoutDirection.Horizontal ?
        workspaceLayout.engine.workspaceUnitFromViewUnit(workspaceView.bounds.width) :
        workspaceLayout.engine.workspaceUnitFromViewUnit(workspaceView.bounds.height)
    workspaceLayout.updateLayoutDownTree()
    workspaceView.refreshView()
  }
}
