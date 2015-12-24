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
 A view for displaying a `Toolbox`, where categories are displayed in a vertical list and blocks for
 each category appear to its right when a category is selected.
 */
public class ToolboxView: UIView {

  // MARK: - Static Properties

  /// The width of the categories view
  public static let CategoryListViewWidth = CGFloat(35)

  // MARK: - Properties

  /// The toolbox to display
  public var toolbox: Toolbox? {
    didSet {
      if toolbox == oldValue {
        return
      }

      if toolbox != nil {
        // Build each category's workspace layout tree
        for category in toolbox!.categories {
          do {
            try category.workspace.layout?.layoutBuilder.buildLayoutTree()
            category.workspace.layout?.updateLayoutDownTree()
          } catch let error as NSError {
            bky_assertionFailure("Couldn't create layout tree for toolbox category: \(error)")
          }
        }
      }

      categoryListView.toolbox = toolbox
    }
  }

  /// The list view for the toolbox's categories
  public private(set) var categoryListView: ToolboxCategoryListView!

  /// The view for displaying each category's set of blocks
  public private(set) var blockListView: WorkspaceView!

  /// The constraint for resizing the width of `self.blockListView`
  private var blockListViewWidthConstraint: NSLayoutConstraint!

  // MARK: - Initializers

  public convenience init() {
    self.init(frame: CGRectZero)
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    // Create views
    categoryListView = ToolboxCategoryListView()
    categoryListView.listViewDelegate = self

    blockListView = WorkspaceView()
    blockListView.backgroundColor = UIColor(white: 0.6, alpha: 0.65)
    blockListView.allowCanvasPadding = false

    // Add constraints
    let views = ["categoryListView": categoryListView, "blockListView": blockListView]
    let metrics = ["categoryListViewWidth": ToolboxView.CategoryListViewWidth]
    let constraints = [
      "H:|[categoryListView(categoryListViewWidth)][blockListView]",
      "V:|[categoryListView]|",
      "V:|[blockListView]|"
    ]
    bky_addSubviews(Array(views.values))
    bky_addVisualFormatConstraints(constraints, metrics: metrics, views: views)

    blockListViewWidthConstraint = NSLayoutConstraint(item: blockListView, attribute: .Width,
      relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 0)
    self.addConstraint(blockListViewWidthConstraint)

    sendSubviewToBack(blockListView)
  }

  // MARK: - Super

  public override func intrinsicContentSize() -> CGSize {
    // This view's intrinsic content width is always the width of the toolbar + the width of the
    // current category, if it's open
    var size = CGSizeMake(ToolboxView.CategoryListViewWidth, UIViewNoIntrinsicMetric)

    if let blockListViewFrame = categoryListView.selectedCategory?.workspace.layout?.viewFrame {
      size.width += blockListViewFrame.size.width
    }

    return size
  }

  // MARK: - Public

  /**
  Refreshes the UI based on the current version of `self.toolbox`.
  */
  public func refreshView() {
    categoryListView.reloadData()
  }

  /**
   Shows the contents of a given category.

   - Parameter category: The `Category` to show.
   - Parameter animated: True if the category should be animated into view.
   */
  public func showCategory(category: Toolbox.Category, animated: Bool) {
    setCategory(category, animated: animated)
  }

  /**
   Hides the contents of a given category.

   - Parameter category: The `Category` to hide.
   - Parameter animated: True if the category should be animated out of view.
   */
  public func hideCategory(animated animated: Bool) {
    setCategory(nil, animated: animated)
  }

  // MARK: - Private

  private func setCategory(category: Toolbox.Category?, animated: Bool) {
    // Highlight the new category
    categoryListView.selectedCategory = category

    // Clear the layout so all current blocks are removed
    blockListView.layout = nil

    // Set the new layout
    blockListView.layout = category?.workspace.layout
    blockListView.refreshView()

    // Update the width of `self.blockListView`.
    let updateBlockListViewWidth = { () -> Void in
      if let blockListViewFrame = category?.workspace.layout?.viewFrame {
        self.blockListViewWidthConstraint.constant = blockListViewFrame.size.width
      } else {
        self.blockListViewWidthConstraint.constant = 0
      }
      self.invalidateIntrinsicContentSize()
    }

    if animated {
      // Force pending layout changes to complete (before animating the list width change)
      self.layoutIfNeeded()

      UIView.animateWithDuration(0.3, delay: 0.0, options: .CurveEaseInOut,
        animations: { Void -> () in
          updateBlockListViewWidth()
          self.layoutIfNeeded()
        }, completion: nil)
    } else {
      updateBlockListViewWidth()
    }
  }
}

// MARK: - Protocol - ToolboxCategoryListViewDelegate

extension ToolboxView: ToolboxCategoryListViewDelegate {
  public func toolboxCategoryListView(
    listView: ToolboxCategoryListView, didSelectCategory category: Toolbox.Category)
  {
    showCategory(category, animated: true)
  }

  public func toolboxCategoryListViewDidDeselectCategory(listView: ToolboxCategoryListView) {
    hideCategory(animated: true)
  }
}
