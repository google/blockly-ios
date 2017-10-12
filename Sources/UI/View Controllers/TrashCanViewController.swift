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
@objc(BKYTrashCanViewController)
@objcMembers public final class TrashCanViewController: WorkspaceViewController {

  // MARK: - Properties

  /// The layout engine to use for displaying the trash can
  public let engine: LayoutEngine
  /// The layout direction to use for `self.workspaceLayout`
  public let layoutDirection: WorkspaceFlowLayout.LayoutDirection

  /// The constraint for resizing the width of `self.view`
  private var _viewWidthConstraint: NSLayoutConstraint?
  /// The constraint for resizing the height of `self.view`
  private var _viewHeightConstraint: NSLayoutConstraint?
  /// Pointer used for distinguishing changes in `self.bounds`
  private var _kvoContextBounds = 0


  // MARK: - Initializers/Deinitializers

  init(engine: LayoutEngine, layoutBuilder: LayoutBuilder,
       layoutDirection: WorkspaceFlowLayout.LayoutDirection, viewFactory: ViewFactory)
  {
    self.engine = engine
    self.layoutDirection = layoutDirection
    super.init(viewFactory: viewFactory)

    // Create the workspace and layout representing the trash can
    let workspace = WorkspaceFlow()
    workspace.readOnly = true
    workspace.workspaceType = .trash

    do {
      let workspaceLayout =
        WorkspaceFlowLayout(workspace: workspace, engine: engine, layoutDirection: layoutDirection)
      let workspaceLayoutCoordinator = try WorkspaceLayoutCoordinator(
        workspaceLayout: workspaceLayout, layoutBuilder: layoutBuilder, connectionManager: nil)
      try loadWorkspaceLayoutCoordinator(workspaceLayoutCoordinator)
    } catch let error {
      bky_assertionFailure("Could not create WorkspaceFlowLayout: \(error)")
    }
  }

  public required init?(coder aDecoder: NSCoder) {
    // TODO(#52): Support the ability to create view controllers from XIBs.
    // Note: Both the layoutEngine and layoutBuilder need to be initialized somehow.
    fatalError("Called unsupported initializer")
  }

  deinit {
    if isViewLoaded {
      view.removeObserver(self, forKeyPath: "bounds")
    }
  }

  // MARK: - Super

  open override func viewDidLoad() {
    super.viewDidLoad()

    workspaceView.allowCanvasPadding = false

    view.addObserver(self, forKeyPath: "bounds",
      options: NSKeyValueObservingOptions.new, context: &self._kvoContextBounds)

    updateMaximumLineBlockSize()
  }

  open override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey : Any]?,
    context: UnsafeMutableRawPointer?)
  {
    if context == &_kvoContextBounds {
      updateMaximumLineBlockSize()
    } else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }

  // MARK: - Public

  /**
   Sets the height of the workspace view.

   - parameter height: The new height
   - parameter animated: Flag determining if the new height should be animated.
   */
  public func setWorkspaceViewHeight(_ height: CGFloat, animated: Bool) {
    if _viewHeightConstraint == nil {
      _viewHeightConstraint = view.bky_addHeightConstraint(0)
    }

    if let constraint = _viewHeightConstraint , constraint.constant != height {
      if height > 0 {
        // Immediately update the max line block size before animating so the contents within the
        // workspace view don't animate their positions. Only do it for height > 0 since we don't
        // want things to be repositioned as the trash is being closed.
        updateMaximumLineBlockSize(fromViewSize: CGSize(width: view.bounds.width, height: height))
      }

      view.bky_updateConstraints(animated: animated, update: {
        constraint.constant = height
      })
    }
  }

  /**
   Sets the width of the workspace view.

   - parameter width: The new width
   - parameter animated: Flag determining if the new width should be animated.
   */
  public func setWorkspaceViewWidth(_ width: CGFloat, animated: Bool) {
    if _viewWidthConstraint == nil {
      _viewWidthConstraint = view.bky_addWidthConstraint(0)
    }

    if let constraint = _viewWidthConstraint , constraint.constant != width {
      if width > 0 {
        // Immediately update the max line block size before animating so the contents within the
        // workspace view don't animate their positions. Only do it for width > 0 since we don't
        // want things to be repositioned as the trash is being closed.
        updateMaximumLineBlockSize(fromViewSize: CGSize(width: width, height: view.bounds.height))
      }

      view.bky_updateConstraints(animated: animated, update: {
        constraint.constant = width
      })
    }
  }

  // MARK: - Private

  private func updateMaximumLineBlockSize(fromViewSize viewSize: CGSize? = nil) {
    guard let workspaceLayout = self.workspaceLayout as? WorkspaceFlowLayout else {
      return
    }

    let size = viewSize ?? view.bounds.size
    let maxBlockLineSize = layoutDirection == WorkspaceFlowLayout.LayoutDirection.horizontal ?
      workspaceLayout.engine.workspaceUnitFromViewUnit(size.width) :
      workspaceLayout.engine.workspaceUnitFromViewUnit(size.height)

    // Only need to set a maximum line block size if it's > 0. We don't want things to be
    // repositioned as the trash is being closed.
    if maxBlockLineSize > 0 {
      workspaceLayout.maximumLineBlockSize = maxBlockLineSize
      workspaceLayout.updateLayoutDownTree()
      workspaceView.refreshView()
    }
  }
}
