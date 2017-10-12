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

// MARK: - Toolbox Class

/**
 An object for grouping categories of template blocks together, so users can add them to a
 workspace.
 */
@objc(BKYToolbox)
@objcMembers open class Toolbox: NSObject {

  // MARK: - Properties

  /// A list of all categories in the toolbox
  open private(set) var categories = [Category]()

  /// Flag to set all categories in the toolbox to readOnly
  open var readOnly: Bool = true {
    didSet {
      for category in categories {
        category.readOnly = self.readOnly
      }
    }
  }

  // MARK: - Public

  /**
   Adds a category to the toolbox.

   - parameter name: The name of the new category.
   - parameter color: The color of the new category.
   - returns: The new category.
   */
  open func addCategory(name: String, color: UIColor) -> Category {
    return addCategory(name: name, color: color, icon: nil)
  }

  /**
   Adds a category to the toolbox.

  - parameter name: The name of the new category.
  - parameter color: The color of the new category.
  - parameter icon: The `UIImage` icon for the new category.
  - returns: The new category.
  */
  open func addCategory(name: String, color: UIColor, icon: UIImage?) -> Category {
    let category = Category(name: name, color: color, icon: icon)
    category.readOnly = self.readOnly
    category.workspaceType = .toolbox

    self.categories.append(category)

    return category
  }
}

// MARK: - Toolbox.Category Class

extension Toolbox {
  /**
   Groups a collection of blocks together, for use in a `Toolbox`.
   */
  @objc(BKYToolboxCategory)
  @objcMembers open class Category: WorkspaceFlow {

    // MARK: - Constants

    /** Represents all possible types of toolbox categories. */
    public enum CategoryType: Int {
      case
      /// Specifies a category that is used for generic purposes.
      generic = 0,
      /// Specifies a category that is used for "variable" blocks.
      variable,
      /// Specifies a category that is used for "procedure" blocks.
      procedure
    }

    // MARK: - Properties

    /// The name of the category
    open var name: String
    /// The color of the category
    open var color: UIColor
    /// An icon used to represent the category
    open var icon: UIImage?
    /// The type of the category
    open var categoryType: CategoryType = .generic

    // MARK: - Initializers

    fileprivate init(name: String, color: UIColor, icon: UIImage?) {
      self.name = name
      self.color = color
      self.icon = icon
      super.init()
    }
  }
}
