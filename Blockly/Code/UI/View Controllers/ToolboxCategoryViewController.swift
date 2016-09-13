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

 // TODO:(vicng) Change this into a view controller that uses `WorkspaceViewController` instead.
 */
public class ToolboxCategoryViewController: WorkspaceViewController {

  // MARK: - Static Properties

  /// Default background color to use for `view`
  private static let ViewBackgroundColor = UIColor(white: 0.6, alpha: 0.65)

  // MARK: - Properties

  /// The toolbox layout to display
  public var toolboxLayout: ToolboxLayout?
  /// The current category being displayed
  public private(set) var category: Toolbox.Category?
  /// Width constraint for this view
  private var _widthConstraint: NSLayoutConstraint!
  /// Height constraint for this view
  private var _heightConstraint: NSLayoutConstraint!

  // MARK: - Super

  public override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = ToolboxCategoryViewController.ViewBackgroundColor
    workspaceView.allowCanvasPadding = false

    // Add low priority size constraints. This allows this view to automatically resize itself
    // if no other higher priority size constraints have been set elsewhere.
    _widthConstraint = view.bky_addWidthConstraint(0, priority: UILayoutPriorityDefaultLow)
    _heightConstraint = view.bky_addHeightConstraint(0, priority: UILayoutPriorityDefaultLow)

    view.setNeedsUpdateConstraints()
  }

  // MARK: - Public

  /**
   Shows the contents of a given category and automatically resizes view's size to
   completely fit the size of the contents.

   - Parameter category: The `Category` to show.
   - Parameter animated: Flag indicating if resizing the view's size should be animated.
   */
  public func showCategory(category: Toolbox.Category, animated: Bool) {
    setCategory(category, animated: animated)
  }

  /**
   Hides the contents of a given category and automatically resizes the view's size to `(0, 0)`.

   - Parameter category: The `Category` to hide.
   - Parameter animated: Flag indicating if resizing the view's size should be animated.
   */
  public func hideCategory(animated animated: Bool) {
    setCategory(nil, animated: animated)
  }

  // MARK: - Private

  private func setCategory(category: Toolbox.Category?, animated: Bool) {
    if self.category == category {
      return
    }

    self.category = category

    do {
      // Clear the layout so all current blocks are removed
      try loadWorkspaceLayoutCoordinator(nil)

      // Set the new layout
      if let layoutCoordinator =
        toolboxLayout?.categoryLayoutCoordinators
          .filter({ $0.workspaceLayout.workspace == category }).first
      {
        try loadWorkspaceLayoutCoordinator(layoutCoordinator)
      }
    } catch let error as NSError {
      bky_assertionFailure("Could not load category: \(error)")
      return
    }

    // Update the size of the toolbox, if needed
    let newWidth = category?.layout?.viewFrame.size.width ?? 0
    let newHeight = category?.layout?.viewFrame.size.height ?? 0
    if _widthConstraint.constant == newWidth && _heightConstraint.constant == newHeight {
      return
    }

    view.bky_updateConstraints(animated: animated, update: {
      self._widthConstraint.constant = newWidth
      self._heightConstraint.constant = newHeight
    })
  }
}
