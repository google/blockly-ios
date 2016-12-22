/*
* Copyright 2016 Google Inc. All Rights Reserved.
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
 A view for displaying the blocks inside of a `Toolbox.Category`.
 */
@objc(BKYToolboxCategoryViewController)
public final class ToolboxCategoryViewController: WorkspaceViewController {

  // MARK: - Static Properties

  /// Default background color to use for `view`
  private static let ViewBackgroundColor = UIColor(white: 0.6, alpha: 0.65)

  // MARK: - Properties

  /// The toolbox layout to display
  public var toolboxLayout: ToolboxLayout?
  /// The current category being displayed
  public fileprivate(set) var category: Toolbox.Category?
  /// The workspace view controller that contains the toolbox blocks.
  public var workspaceViewController: WorkspaceViewController
  /// The main workspace name manager, to add variable names and track changes.
  public var workspaceNameManager: NameManager?
  /// The view containing the "Add variable" button.
  public var addButtonView: UIView

  /// Width constraint for this view.
  private var _widthConstraint: NSLayoutConstraint!
  /// Height constraint for this view.
  private var _heightConstraint: NSLayoutConstraint!
  /// Constraint of the button's height or width, depending on orientation.
  private var _buttonConstraint: NSLayoutConstraint!
  /// The orientation of the toolbox.
  private let orientation: ToolboxCategoryListViewController.Orientation

  // MARK: - Super

  public init(viewFactory: ViewFactory,
    orientation: ToolboxCategoryListViewController.Orientation)
  {
    workspaceViewController = WorkspaceViewController(viewFactory: viewFactory)
    self.orientation = orientation
    addButtonView = UIView()

    super.init(viewFactory: viewFactory)
  }

  public required init?(coder aDecoder: NSCoder) {
    workspaceViewController = WorkspaceViewController(viewFactory: ViewFactory())
    orientation = .horizontal
    addButtonView = UIView()

    super.init(coder: aDecoder)
  }

  open override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = ToolboxCategoryViewController.ViewBackgroundColor
    workspaceViewController.workspaceView.allowCanvasPadding = false
    workspaceViewController.workspaceView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(workspaceViewController.workspaceView)

    addButtonView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(addButtonView)

    let button = UIButton()
    button.addTarget(self, action: #selector(didTapButton(_:)), for: .touchUpInside)
    button.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    addButtonView.addSubview(button)

    let views: [String: UIView] = [
      "workspaceView": workspaceViewController.workspaceView,
      "addButtonView": addButtonView
      ]

    let constraints: [String]
    switch (orientation) {
    case .horizontal:
      constraints = [
        "H:|[addButtonView][workspaceView]|",
        "V:|[workspaceView]|",
        "V:|[addButtonView]|",
      ]

      _buttonConstraint = addButtonView.bky_addWidthConstraint(0, priority: UILayoutPriorityRequired)
    case .vertical:
      constraints = [
        "V:|[addButtonView][workspaceView]|",
        "H:|[workspaceView]|",
        "H:|[addButtonView]|",
      ]

      _buttonConstraint = addButtonView.bky_addHeightConstraint(0, priority: UILayoutPriorityRequired)
    }

    view.bky_addVisualFormatConstraints(constraints, metrics: [:], views: views)

    // Add low priority size constraints. This allows this view to automatically resize itself
    // if no other higher priority size constraints have been set elsewhere.
    _widthConstraint = view.bky_addWidthConstraint(0, priority: UILayoutPriorityDefaultLow)
    _heightConstraint = view.bky_addHeightConstraint(0, priority: UILayoutPriorityDefaultLow)

    view.setNeedsUpdateConstraints()
    workspaceViewController.workspaceView.setNeedsUpdateConstraints()
  }

  public func didTapButton(_: UIButton) {
    let addView =
      UIAlertController(title: "New variable name:",
        message: "", preferredStyle: .alert)
    addView.addTextField { (textField: UITextField!) in

    }
    addView.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
    addView.addAction(UIAlertAction(title: "Add", style: .default) { _ in
      guard let textField = addView.textFields?[0],
        let newName = textField.text else
      {
        return
      }

      try! self.workspaceNameManager?.addName(newName)
    })

    workspaceViewController.present(addView, animated: true, completion: nil)
  }

  // MARK: - Public

  /**
   Shows the contents of a given category and automatically resizes view's size to
   completely fit the size of the contents.

   - parameter category: The `Category` to show.
   - parameter animated: Flag indicating if resizing the view's size should be animated.
   */
  public func showCategory(_ category: Toolbox.Category, animated: Bool) {
    setCategory(category, animated: animated)
  }

  /**
   Hides any open category and automatically resizes the view's size to `(0, 0)`.

   - parameter animated: Flag indicating if resizing the view's size should be animated.
   */
  public func hideCategory(animated: Bool) {
    setCategory(nil, animated: animated)
  }

  // MARK: - Private

  private func setCategory(_ category: Toolbox.Category?, animated: Bool) {
    if self.category == category {
      return
    }

    self.category = category

    do {
      // Clear the layout so all current blocks are removed
      try workspaceViewController.loadWorkspaceLayoutCoordinator(nil)

      // Set the new layout
      if let layoutCoordinator =
        toolboxLayout?.categoryLayoutCoordinators
          .filter({ $0.workspaceLayout.workspace == category }).first
      {
        try workspaceViewController.loadWorkspaceLayoutCoordinator(layoutCoordinator)
      }
    } catch let error {
      bky_assertionFailure("Could not load category: \(error)")
      return
    }

    // Update the size of the toolbox, if needed
    let newWidth = category?.layout?.viewFrame.size.width ?? 0
    let newHeight = category?.layout?.viewFrame.size.height ?? 0

    view.bky_updateConstraints(animated: animated, update: {
      self._widthConstraint.constant = newWidth
      self._heightConstraint.constant = newHeight
    })

    // TODO(corydiers):- Add customization(and default) here.
    var buttonSize = 0
    if let category = category,
      category.isVariable
    {
      switch (orientation) {
      case .horizontal:
        buttonSize = 100
        break
      case .vertical:
        buttonSize = 100
        break
      }
    }

    self._buttonConstraint?.constant = CGFloat(buttonSize)
  }
}
