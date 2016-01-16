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
 An object for grouping categories of template blocks together, so users can add them to a
 workspace.
 */
@objc(BKYToolbox)
public class Toolbox: NSObject {
  public private(set) var categoryLayouts = [WorkspaceListLayout]()

  public func addCategory(categoryName: String, color: UIColor,
    layoutBuilder: LayoutBuilder = LayoutBuilder()) -> Category
  {
    let category = Category()
    category.name = categoryName
    category.color = color

    do {
      let layout = try WorkspaceListLayout(workspaceList: category, layoutBuilder: layoutBuilder)
      categoryLayouts.append(layout)
    } catch let error as NSError {
      bky_assertionFailure("Could not create WorkspaceListLayout: \(error)")
    }

    return category
  }
}

extension Toolbox {
  /**
   Groups a collection of blocks together, for use in a `Toolbox`.
   */
  @objc(BKYToolboxCategory)
  public class Category: WorkspaceList {
    public var name = ""
    public var color: UIColor?
  }
}
