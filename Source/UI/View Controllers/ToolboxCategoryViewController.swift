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
public final class ToolboxCategoryViewController: UIViewController {

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
  /// The view containing any UI elements for the header - currently, the "Add variable" button.
  public var headerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()
  /// Currently unused - any buttons that go in the footer
  public var footerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  /// The main workspace name manager, to add variable names and track changes.
  private weak var variableNameManager: NameManager?
  /// Width constraint for this view.
  private var _widthConstraint: NSLayoutConstraint!
  /// Height constraint for this view.
  private var _heightConstraint: NSLayoutConstraint!
  /// Constraint of the button's height or width, depending on orientation.
  private var _headerConstraint: NSLayoutConstraint!
  /// The orientation of the toolbox.
  private let orientation: ToolboxCategoryListViewController.Orientation
  /// The button for adding variables to the name manager.
  private lazy var addVariableButton: UIButton = {
    let button = UIButton()
    button.setTitle("+ Add variable", for: UIControlState.normal)
    button.setTitleColor(.white, for: .normal)
    button.setTitleColor(.gray, for: .highlighted)
    button.backgroundColor = .darkGray
    button.addTarget(self, action: #selector(didTapButton(_:)), for: .touchUpInside)
    button.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    return button
  }()

  // MARK: - Super

  public init(viewFactory: ViewFactory,
    orientation: ToolboxCategoryListViewController.Orientation,
    nameManager: NameManager?)
  {
    workspaceViewController = WorkspaceViewController(viewFactory: viewFactory)
    self.orientation = orientation
    variableNameManager = nameManager

    super.init(nibName: nil, bundle: nil)

    variableNameManager?.listeners.add(self)
  }

  deinit {
    variableNameManager?.listeners.remove(self)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  open override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = ToolboxCategoryViewController.ViewBackgroundColor
    workspaceViewController.workspaceView.allowCanvasPadding = false
    workspaceViewController.workspaceView.translatesAutoresizingMaskIntoConstraints = false
    workspaceViewController.workspace?.workspaceType = .toolbox
    headerView.addSubview(addVariableButton)

    let views: [String: UIView] = [
      "workspaceView": workspaceViewController.workspaceView,
      "headerView": headerView,
      "footerView": footerView
      ]

    let constraints: [String]
    switch (orientation) {
    case .horizontal:
      constraints = [
        "H:|[headerView][workspaceView][footerView]|",
        "V:|[workspaceView]|",
        "V:|[headerView]|",
        "V:|[footerView]|"
      ]

      footerView.bky_addWidthConstraint(0, priority: UILayoutPriorityDefaultLow)
      _headerConstraint = headerView.bky_addWidthConstraint(0,
        priority: UILayoutPriorityRequired)
    case .vertical:
      constraints = [
        "V:|[headerView][workspaceView][footerView]|",
        "H:|[workspaceView]|",
        "H:|[headerView]|",
        "H:|[footerView]|"
      ]

      footerView.bky_addHeightConstraint(0, priority: UILayoutPriorityDefaultLow)
      _headerConstraint = headerView.bky_addHeightConstraint(0,
        priority: UILayoutPriorityRequired)
    }

    view.bky_addSubviews(Array(views.values))
    view.bky_addVisualFormatConstraints(constraints, metrics: nil, views: views)

    // Add low priority size constraints. This allows this view to automatically resize itself
    // if no other higher priority size constraints have been set elsewhere.
    _widthConstraint = view.bky_addWidthConstraint(0, priority: UILayoutPriorityDefaultLow)
    _heightConstraint = view.bky_addHeightConstraint(0, priority: UILayoutPriorityDefaultLow)

    view.setNeedsUpdateConstraints()
    workspaceViewController.workspaceView.setNeedsUpdateConstraints()
  }

  public func didTapButton(_: UIButton) {
    let addView = UIAlertController(title: "New variable name:", message: "",
      preferredStyle: .alert)
    addView.addTextField(configurationHandler: nil)
    addView.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
    addView.addAction(UIAlertAction(title: "Add", style: .default) { _ in
      guard let textField = addView.textFields?[0],
        let newName = textField.text else
      {
        return
      }

      do {
        try self.variableNameManager?.addName(newName)
      } catch {
        bky_assertionFailure(
          "Tried to create an invalid variable without proper error handling: \(error)")
      }
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
    var newWidth = category?.layout?.viewFrame.size.width ?? 0
    var newHeight = category?.layout?.viewFrame.size.height ?? 0

    // TODO(corydiers):- Add customization(and default) here.
    var buttonSize: CGFloat = 0
    if let category = category,
      category.isVariable
    {
      workspaceViewController.workspaceLayoutCoordinator?.variableNameManager = variableNameManager
      addVariableButton.isHidden = false
      switch (orientation) {
      case .horizontal:
        buttonSize = 136
        newWidth += buttonSize
      case .vertical:
        buttonSize = 56
        newHeight += buttonSize
      }

      newWidth = max(newWidth, 136)
      newHeight = max(newHeight, 56)
    } else {
      addVariableButton.isHidden = true
    }

    _headerConstraint?.constant = CGFloat(buttonSize)

    view.bky_updateConstraints(animated: animated, update: {
      self._widthConstraint.constant = newWidth
      self._heightConstraint.constant = newHeight
    })
  }

  fileprivate func getVariableCoordinator() -> WorkspaceLayoutCoordinator? {
    guard let categories = toolboxLayout?.toolbox.categories else {
      return nil
    }
    for (index, category) in categories.enumerated() {
      if category.isVariable {
        return toolboxLayout?.categoryLayoutCoordinators[index]
      }
    }

    return nil
  }

  fileprivate func makeVariableBlock(_ blockName: String, varName: String) throws -> Block? {
    let block = try getVariableCoordinator()?.blockFactory?.makeBlock(name: blockName)
    let field = block?.firstField(withName: "VAR") as? FieldVariable
    try field?.setVariable(varName)
    return block
  }
}

extension ToolboxCategoryViewController: NameManagerListener {
  public func nameManager(_ nameManager: NameManager, didAddName name: String) {
    guard let config = workspaceViewController.workspaceLayout?.config,
      let toolbox = toolboxLayout?.toolbox else {
      return
    }

    let uniqueVariableBlocks = config.stringArray(for: LayoutConfig.UniqueVariableBlocks)
    let variableBlocks = config.stringArray(for: LayoutConfig.VariableBlocks)

    guard let index = toolbox.categories.index(where: ({ $0.isVariable })) else {
      return
    }

    let category = toolbox.categories[index]
    do {
      if category.allBlocks.count == 0 {
        for blockName in uniqueVariableBlocks {
          if let block = try makeVariableBlock(blockName, varName: name) {
            try category.addBlockTree(block)
          }
        }
      }

      for blockName in variableBlocks {
        if let block = try makeVariableBlock(blockName, varName: name) {
          try category.addBlockTree(block)
        }
      }
    } catch {
      bky_assertionFailure("Failed to make a variable block: \(error)")
      return
    }
  }

  public func nameManager(_ nameManager: NameManager, didRemoveName name: String) {
    guard let variableCoordinator = getVariableCoordinator(),
      let config = toolboxLayout?.engine.config else
    {
      return
    }

    let workspace = variableCoordinator.workspaceLayout.workspace
    let matchingBlocks = workspace.allVariableBlocks(forName: name)
    let uniqueVariableBlocks =  config.stringArray(for: LayoutConfig.UniqueVariableBlocks)
    let variableBlocks = config.stringArray(for: LayoutConfig.VariableBlocks)
    let shouldDeleteSetters = workspace.allBlocks.count ==
      uniqueVariableBlocks.count + variableBlocks.count
    var toChangeName: [Block] = []

    // Remove each block with matching variable fields.
    for block in matchingBlocks {
      do {
        if uniqueVariableBlocks.contains(block.name) && !shouldDeleteSetters {
          toChangeName.append(block)
          continue
        }

        try variableCoordinator.removeSingleBlock(block)
      } catch let error {
        bky_assertionFailure("Couldn't remove block: \(error)")
      }
    }

    // If the unique blocks had their variable deleted, set them to another variable in the manager.
    guard let newDefault = nameManager.names.first else {
      return
    }
    for block in toChangeName {
      guard let field = block.firstField(withName: "VAR") as? FieldVariable else {
        continue
      }

      do {
        try field.setVariable(newDefault)
        block.layout?.updateLayoutDownTree()
      } catch {
        bky_assertionFailure("Couldn't set variable on block: \(error)")
      }
    }
  }
}
