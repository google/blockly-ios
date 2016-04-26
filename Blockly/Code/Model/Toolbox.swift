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
public class Toolbox: NSObject {

  // MARK: - Properties

  /// A list of all categories in the toolbox
  public private(set) var categories = [Category]()

  /// Flag to set all categories in the toolbox to readOnly
  public var readOnly: Bool = true {
    didSet {
      for category in categories {
        category.readOnly = self.readOnly
      }
    }
  }

  // MARK: - Public

  public func addCategory(categoryName: String, color: UIColor, icon: UIImage? = nil) -> Category {
    let category = Category(name: categoryName, color: color, icon: icon)
    category.readOnly = self.readOnly

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
  public class Category: WorkspaceFlow {

    // MARK: - Properties

    /// The name of the category
    public var name: String
    /// The color of the category
    public var color: UIColor
    /// An icon used to represent the category
    public var icon: UIImage?

    // MARK: - Initializers

    private init(name: String, color: UIColor, icon: UIImage?) {
      self.name = name
      self.color = color
      self.icon = icon
    }
  }
}
