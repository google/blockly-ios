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

// TODO:(#120) This delegate only exists right now so `WorkbenchViewController` can attach
// gesture recognizers on the BlockView. Refactor this so the gesture recognizers are managed
// in this view controller and then this delegate can be deleted.
@objc(BKYWorkspaceViewControllerDelegate)
public protocol WorkspaceViewControllerDelegate {
  func workspaceViewController(
    workspaceViewController: WorkspaceViewController, didAddBlockView blockView: BlockView)

  func workspaceViewController(
    workspaceViewController: WorkspaceViewController, didRemoveBlockView blockView: BlockView)
}

/**
 View controller for managing a workspace.
 */
@objc(BKYWorkspaceViewController)
public class WorkspaceViewController: UIViewController {

  /// The workspace layout this view controller operates on
  public private(set) var workspaceLayout: WorkspaceLayout?

  /// A convenience property for `self.workspaceLayout.workspace`
  public var workspace: Workspace? {
    return workspaceLayout?.workspace
  }

  /// The target workspace view
  public lazy var workspaceView: WorkspaceView = {
    let workspaceView = WorkspaceView()
    workspaceView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    workspaceView.backgroundColor = UIColor.clearColor()
    return workspaceView
  }()

  /// Delegate for events that occur on this view controller
  public weak var delegate: WorkspaceViewControllerDelegate?

  /// The view builder used for managing the view hierarchy
  private let _viewBuilder: ViewBuilder

  // MARK: - Initializers

  /**
   Initializer.

   - Parameter viewFactory: The `ViewFactory` that should be used when creating the
   view hierarchy for a workspace.
   */
  public init(viewFactory: ViewFactory) {
    _viewBuilder = ViewBuilder(viewFactory: viewFactory)
    super.init(nibName: nil, bundle: nil)

    _viewBuilder.delegate = self
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  public override func viewDidLoad() {
    super.viewDidLoad()

    workspaceView.frame = view.bounds
    view.addSubview(workspaceView)
  }

  // MARK: - Public

  /**
   Loads a `WorkspaceLayout` into `self.workspaceView`. This method automatically creates and
   manages all the views required to render the workspace.

   - Parameter workspaceLayout: A `WorkspaceLayout`.
   */
  public func loadWorkspaceLayout(workspaceLayout: WorkspaceLayout?) throws {
    self.workspaceLayout = workspaceLayout

    workspaceView.layout = workspaceLayout
    try _viewBuilder.buildViewTree(forWorkspaceView: workspaceView)
    workspaceView.refreshView()
  }
}

extension WorkspaceViewController: ViewBuilderDelegate {
  public func viewBuilder(
    viewBuilder: ViewBuilder, didAddChild childView: UIView, toParent parentView: UIView)
  {
    // TODO:(#120) This delegate only exists right now so `WorkbenchViewController` can attach
    // gesture recognizers on the BlockView. Refactor this so the gesture recognizers are managed
    // in this view controller.
    if let blockView = childView as? BlockView {
      delegate?.workspaceViewController(self, didAddBlockView: blockView)
    }
  }

  public func viewBuilder(
    viewBuilder: ViewBuilder, didRemoveChild childView: UIView, fromParent parentView: UIView)
  {
    // TODO:(#120) This delegate only exists right now so `WorkbenchViewController` can attach
    // gesture recognizers on the BlockView. Refactor this so the gesture recognizers are managed
    // in this view controller.
    if let blockView = childView as? BlockView {
      delegate?.workspaceViewController(self, didRemoveBlockView: blockView)
    }
  }
}
