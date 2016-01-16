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
 Groups a collection of blocks together for displaying in a vertical list.
 */
@objc(BKYWorkspaceList)
public class WorkspaceList: Workspace {
  // MARK: - Properties

  /// Defines information on how to position blocks within the vertical list
  public class BlockItem {
    var blockUUID: String
    var gap: CGFloat

    private init(block: Block, gap: CGFloat) {
      self.blockUUID = block.uuid
      self.gap = gap
    }
  }

  /// List of all blocks that have been added to this list
  public private(set) var blockItems = [BlockItem]()

  // MARK: - Super

  public override func addBlock(block: Block) -> Bool {
    return addBlock(block, gap: nil)
  }

  public override func removeBlock(block: Block) {
    // Remove all block items containing this block
    blockItems = blockItems.filter({ $0.blockUUID != block.uuid })

    super.removeBlock(block)
  }

  // MARK: - Public

  /**
   Adds a block to this list.

   - Parameter block: The block to add.
   - Parameter gap: The amount of space to separate this block and the next block that is added,
   specified as a Workspace coordinate system unit. Defaults to
   `BlockLayout.sharedConfig.ySeparatorSpace` if this value is not specified.
   - Returns: True if the block was added. False if the block was not added (because it was already
  in the workspace).
   */
  public func addBlock(block: Block, gap: CGFloat?) -> Bool {
    if !super.addBlock(block) {
      return false
    }

    let gap = (gap ?? BlockLayout.sharedConfig.ySeparatorSpace)
    let blockItem = BlockItem(block: block, gap: gap)
    blockItems.append(blockItem)

    return true
  }
}
