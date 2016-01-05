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
  public let isRTL: Bool
  public private(set) var categories = [Category]()

  public init(isRTL: Bool = false) {
    self.isRTL = isRTL
    super.init()
  }

  public func addCategory(categoryName: String, color: UIColor,
    layoutBuilder: LayoutBuilder = LayoutBuilder()) -> Category
  {
    let category = Category(toolbox: self, layoutBuilder: layoutBuilder)
    category.name = categoryName
    category.color = color
    categories.append(category)
    return category
  }
}

extension Toolbox {
  /**
   Groups a collection of blocks together, for use in a `Toolbox`.
   */
  @objc(BKYToolboxCategory)
  public class Category: NSObject {
    /// Defines information on how to position blocks within the Category
    public class BlockItem {
      var block: Block
      var gap: CGFloat

      private init(block: Block, gap: CGFloat) {
        self.block = block
        self.gap = gap
      }
    }

    public var name = ""
    public var color: UIColor?
    public unowned let toolbox: Toolbox
    /// Each category is essentially its own workspace of blocks
    public let workspace: Workspace

    /// List of all blocks that have been added to this category
    public private(set) var blockItems = [BlockItem]()

    private init(toolbox: Toolbox, layoutBuilder: LayoutBuilder) {
      self.toolbox = toolbox
      self.workspace = Workspace()
      super.init()

      // Automatically create a layout for this category
      self.workspace.layout =
        ToolboxCategoryLayout(category: self, layoutBuilder: layoutBuilder)
    }

    /**
     Adds a block to this category.

     - Parameter block: The block to add.
     - Parameter gap: The amount of space to separate this block and the next block that is added,
     specified as a Workspace coordinate system unit. Defaults to
     `BlockLayout.sharedConfig.ySeparatorSpace` if this value is not specified.
     */
    public func addBlock(block: Block, gap: CGFloat?) {
      workspace.addBlock(block)

      let gap = (gap ?? BlockLayout.sharedConfig.ySeparatorSpace)
      let blockItem = BlockItem(block: block, gap: gap)
      blockItems.append(blockItem)
    }
  }
}
