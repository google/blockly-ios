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
public class TrashCanViewController: UIViewController {

  // MARK: - Properties

  /// The `WorkspaceFlowLayout` of the trash can's workspace
  public private(set) var workspaceLayout: WorkspaceFlowLayout?
  /// The associated `Workspace` of the trash can
  public var workspace: Workspace? {
    return workspaceLayout?.workspace
  }
  /// The trash can's `WorkspaceView`
  public var workspaceView: WorkspaceView! {
    return self.view as! WorkspaceView
  }
  /// The layout engine to use for displaying the trash can
  public private(set) var engine: LayoutEngine!
  /// The layout builder to create layout hierarchies inside the trash can
  public private(set) var layoutBuilder: LayoutBuilder!
  /// The layout direction to use for `self.workspaceLayout`
  public private(set) var layoutDirection: WorkspaceFlowLayout.LayoutDirection!

  /// The constraint for resizing the width of `self.workspaceView`
  private var _workspaceViewWidthConstraint: NSLayoutConstraint?
  /// The constraint for resizing the height of `self.workspaceView`
  private var _workspaceViewHeightConstraint: NSLayoutConstraint?
  /// Pointer used for distinguishing changes in `self.bounds`
  private var _kvoContextBounds = 0


  // MARK: - Initializers/Deinitializers

  init(engine: LayoutEngine, layoutBuilder: LayoutBuilder,
    layoutDirection: WorkspaceFlowLayout.LayoutDirection)
  {
    self.engine = engine
    self.layoutBuilder = layoutBuilder
    self.layoutDirection = layoutDirection
    super.init(nibName: nil, bundle: nil)
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    // TODO:(#52) Support the ability to create view controllers from XIBs.
    // Note: Both the layoutEngine and layoutBuilder need to be initialized somehow.
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
    commonInit()
  }

  deinit {
    self.workspaceView?.removeObserver(self, forKeyPath: "bounds")
  }

  private func commonInit() {
    // Create the workspace and layout representing the trash can
    let workspace = WorkspaceFlow()
    workspace.readOnly = true

    do {
      self.workspaceLayout = try WorkspaceFlowLayout(workspace: workspace,
        layoutDirection: layoutDirection, engine: engine, layoutBuilder: layoutBuilder)
    } catch let error as NSError {
      bky_assertionFailure("Could not create WorkspaceFlowLayout: \(error)")
    }
  }

  // MARK: - Super

  public override func loadView() {
    super.loadView()

    let workspaceView = WorkspaceView()
    workspaceView.backgroundColor = UIColor(white: 0.6, alpha: 0.65)
    workspaceView.allowCanvasPadding = false
    workspaceView.addObserver(self,
      forKeyPath: "bounds", options: NSKeyValueObservingOptions.New, context: &_kvoContextBounds)
    workspaceView.layout = workspaceLayout

    self.view = workspaceView
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

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
      _workspaceViewHeightConstraint = workspaceView.bky_addHeightConstraint(0)
    }

    if let constraint = _workspaceViewHeightConstraint where constraint.constant != height {
      self.workspaceView.bky_updateConstraints(animated: animated, updateConstraints: {
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
      _workspaceViewWidthConstraint = workspaceView.bky_addWidthConstraint(0)
    }

    if let constraint = _workspaceViewWidthConstraint where constraint.constant != width {
      self.workspaceView.bky_updateConstraints(animated: animated, updateConstraints: {
        constraint.constant = width
      })
    }
  }

  // MARK: - Private

  private func updateMaximumLineBlockSize() {
    guard let workspaceLayout = self.workspaceLayout else {
      return
    }

    // Constrain the workspace layout width to the view's width
    workspaceLayout.maximumLineBlockSize =
      workspaceLayout.engine.workspaceUnitFromViewUnit(workspaceView.bounds.size.width)
    workspaceLayout.updateLayoutDownTree()
    workspaceView.refreshView()
  }
}
