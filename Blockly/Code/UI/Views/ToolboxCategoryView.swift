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
public class ToolboxCategoryView: WorkspaceView {

  // MARK: - Properties

  /// The current category being displayed
  public private(set) var category: Toolbox.Category?
  /// Width constraint for this view
  private var _widthConstraint: NSLayoutConstraint!

  // MARK: - Initializers

  public required init() {
    super.init()
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    // Create views
    self.backgroundColor = UIColor(white: 0.6, alpha: 0.65)
    self.allowCanvasPadding = false

    // Add width constraint
    _widthConstraint = NSLayoutConstraint(item: self, attribute: .Width,
      relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 0)
    addConstraint(_widthConstraint)
    setNeedsUpdateConstraints()
  }

  // MARK: - Public

  /**
   Shows the contents of a given category and automatically resizes view's width to completely fit
   the size of the contents.

   - Parameter category: The `Category` to show.
   - Parameter animated: Flag indicating if resizing the view's width should be animated.
   */
  public func showCategory(category: Toolbox.Category, animated: Bool) {
    setCategory(category, animated: animated)
  }

  /**
   Hides the contents of a given category and automatically resizes the view's width to `0`.

   - Parameter category: The `Category` to hide.
   - Parameter animated: Flag indicating if resizing the view's width should be animated.
   */
  public func hideCategory(animated animated: Bool) {
    setCategory(nil, animated: animated)
  }

  // MARK: - Private

  private func setCategory(category: Toolbox.Category?, animated: Bool) {
    self.category = category

    // Clear the layout so all current blocks are removed
    self.layout = nil

    // Set the new layout
    self.layout = category?.layout
    self.refreshView()

    // Update the width of the toolbox, if needed
    let newWidth = category?.layout?.viewFrame.size.width ?? 0
    if _widthConstraint.constant == newWidth {
      return
    }

    // Force pending layout changes to complete
    self.superview?.layoutIfNeeded()

    // Update width constraint
    _widthConstraint.constant = newWidth
    setNeedsUpdateConstraints()

    if animated {
      UIView.animateWithDuration(0.3, delay: 0.0, options: .CurveEaseInOut,
        animations: { Void -> () in
          self.superview?.layoutIfNeeded()
        }, completion: nil)
    } else {
      self.layoutIfNeeded()
    }
  }
}
