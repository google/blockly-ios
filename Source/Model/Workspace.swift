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
 Listener protocol for events that occur on a `Workspace` instance.
 */
@objc(BKYWorkspaceListener)
public protocol WorkspaceListener: class {
  /**
   Event that is called when a block has been added to a workspace.

   - parameter workspace: The workspace that added a block.
   - parameter block: The block that was added.
  */
  func workspace(_ workspace: Workspace, didAddBlock block: Block)

  /**
   Event that is called when a block will be removed from a workspace.

   - parameter workspace: The workspace that will remove a block.
   - parameter block: The block that will be removed.
   */
  func workspace(_ workspace: Workspace, willRemoveBlock block: Block)
}

/**
Data structure that contains `Block` instances.
*/
@objc(BKYWorkspace)
open class Workspace : NSObject {
  // MARK: - Properties

  /// The maximum number of blocks that this workspace may contain. If this value is set to `nil`,
  /// no maximum limit is enforced.
  public let maxBlocks: Int?

  /// The maximum number of blocks that can be currently added to the workspace. If this value is
  /// `nil`, no maximum limit is being enforced.
  public var remainingCapacity: Int? {
    if let maxBlocks = self.maxBlocks {
      return max(maxBlocks - allBlocks.count, 0)
    } else {
      return nil
    }
  }

  /// Dictionary mapping all `Block` instances in this workspace to their `uuid` value
  public fileprivate(set) var allBlocks = [String: Block]()

  /// Flag indicating if this workspace is set to read-only
  public var readOnly: Bool = false {
    didSet {
      if readOnly == oldValue {
        return
      }

      for block in allBlocks.values {
        block.editable = block.editable && !self.readOnly
      }
    }
  }

  /// The listener for events that occur in this workspace
  public var listeners = WeakSet<WorkspaceListener>()

  /// The layout associated with this workspace
  public weak var layout: WorkspaceLayout?

  /// Manager responsible for keeping track of all variable names under this workspace
  public var variableNameManager: NameManager? = NameManager() {
    didSet {
      if variableNameManager == oldValue {
        return
      }
      if oldValue != nil {
        allBlocks.values.forEach { removeNameManagerFromBlock($0) }
      }
      if let newManager = variableNameManager {
        allBlocks.values.forEach { addNameManager(newManager, toBlock: $0) }
      }
    }
  }

  // MARK: - Initializers

  /**
   Creates a Workspace, with no maximum capacity.
   */
  public override init() {
    self.maxBlocks = nil
    super.init()
  }

  /**
   Creates a Workspace, specifying a maximum capacity.

   - parameter maxBlocks: The maximum number of blocks allowed in this workspace.
   */
  public init(maxBlocks: Int) {
    self.maxBlocks = maxBlocks
    super.init()
  }

  // MARK: - Public

  /**
   Returns: A list of all blocks in the workspace whose `topLevel` property is true.
   */
  open func topLevelBlocks() -> [Block] {
    return allBlocks.values.filter({ $0.topLevel })
  }

  /**
   Adds a block and all of its connected blocks to the workspace.

   - parameter rootBlock: The root block to add.
   - throws:
   `BlocklyError`: Thrown if one of the blocks uses a uuid that is already being used by another
   block in the workspace or if adding the new set of blocks would exceed the maximum amount
   allowed.
   */
  open func addBlockTree(_ rootBlock: Block) throws {
    var newBlocks = [Block]()

    // Gather list of all new blocks and perform state checks.

    for block in rootBlock.allBlocksForTree() {
      if let existingBlock = allBlocks[block.uuid] {
        if existingBlock == block {
          // The block is already in the workspace
          continue
        } else {
          throw BlocklyError(.illegalState,
            "Cannot add a block into the workspace with a uuid that is already being used by " +
            "another block")
        }
      }

      if block.shadow && block.topLevel {
        throw BlocklyError(
          .illegalState, "Shadow block cannot be added to the workspace as a top-level block.")
      }

      newBlocks.append(block)
    }

    if let maxBlocks = self.maxBlocks , (allBlocks.count + newBlocks.count) > maxBlocks {
      throw BlocklyError(.workspaceExceedsCapacity,
        "Adding more blocks would exceed the maximum amount allowed (\(maxBlocks))")
    }

    // All checks passed. Add the new blocks to the workspace.
    for block in newBlocks {
      block.editable = block.editable && !readOnly
      allBlocks[block.uuid] = block
      addNameManager(variableNameManager, toBlock: block)
    }

    // Notify delegate for each block addition, now that all of them have been added to the
    // workspace
    for block in newBlocks {
      listeners.forEach { $0.workspace(self, didAddBlock: block) }
    }
  }

  /**
   Removes a given block and all of its connected child blocks from the workspace.

   - parameter rootBlock: The root block to remove.
   - throws:
   `BlocklyError`: Thrown if the tree of blocks could not be removed from the workspace.
   */
  open func removeBlockTree(_ rootBlock: Block) throws {
    if (rootBlock.previousConnection?.connected ?? false) ||
      (rootBlock.outputConnection?.connected ?? false)
    {
      throw BlocklyError(.illegalOperation,
        "The root block must be disconnected from its previous and/or output connections prior " +
        "to being removed from the workspace")
    }

    var blocksToRemove = [Block]()

    // Gather all blocks to be removed and notify the delegate
    for block in rootBlock.allBlocksForTree() {
      if containsBlock(block) {
        blocksToRemove.append(block)
        listeners.forEach { $0.workspace(self, willRemoveBlock: block) }
      }
    }

    // Remove blocks
    for block in blocksToRemove {
      removeNameManagerFromBlock(block)
      allBlocks[block.uuid] = nil
    }
  }

  /**
   Deep copies a block and adds all of the copied blocks into the workspace.

   - parameter rootBlock: The root block to copy
   - parameter editable: Sets whether each block is `editable` or not
   - returns: The root block that was copied
   - throws:
   `BlocklyError`: Thrown if the block could not be copied
   */
  @discardableResult
  open func copyBlockTree(_ rootBlock: Block, editable: Bool) throws -> Block {
    // Create a copy of the tree
    let copyResult = try rootBlock.deepCopy()

    // Set the `editable` property of each block prior to adding them to the workspace so we don't
    // overfire the listeners on each block (currently, each block has no listeners, but it could
    // have once it's been added to the workspace)
    for block in copyResult.allBlocks {
      block.editable = editable
    }

    // Add copy of tree to the workspace
    try addBlockTree(copyResult.rootBlock)

    return copyResult.rootBlock
  }

  /**
  Returns if this block has been added to the workspace.
  */
  open func containsBlock(_ block: Block) -> Bool {
    return (allBlocks[block.uuid] == block)
  }

  /**
   For each top-level block tree in the workspace, deactivates those that contain blocks exceeding
   a given threshold and activates those that don't exceed the given threshold.

   - note: This method should only be called for toolbox categories or trash cans. It is not
   intended to be used for the main editing workspace.

   - parameter threshold: The maximum number of blocks that a block tree may contain before it is
   disabled.
   */
  open func deactivateBlockTrees(forGroupsGreaterThan threshold: Int) {
    for rootBlock in topLevelBlocks() {
      let blocks = rootBlock.allBlocksForTree()
      let deactivated = blocks.count > threshold

      for block in blocks {
        block.disabled = deactivated
        block.movable = !deactivated
      }
    }
  }

  /**
   Finds all blocks that have a field using a specific variable name.

   - param name: The name to search
   */
  public func allVariableBlocks(forName name: String) -> [Block] {
    var variableBlocks: [Block] = []
    for (_, block) in allBlocks {
      for input in block.inputs {
        for field in input.fields {
          if let varField = field as? FieldVariable,
            varField.variable == name
          {
            variableBlocks.append(block)
          }
        }
      }
    }

    return variableBlocks
  }

  // MARK: - Private

  /**
   For all `FieldVariable` instances under a given `Block`, set their `nameManager` property to a
   given `NameManager`.

   - parameter nameManager: The `NameManager` to set
   - parameter block: The `Block`
   */
  private func addNameManager(_ nameManager: NameManager?, toBlock block: Block) {
    block.inputs.flatMap({ $0.fields }).forEach {
      if let fieldVariable = $0 as? FieldVariable {
        fieldVariable.nameManager = nameManager
      }
    }
  }

  /**
   Sets the `nameManager` for all `FieldVariable` instances under the given `Block` to `nil`.

   - parameter block: The `Block`
   */
  private func removeNameManagerFromBlock(_ block: Block) {
    block.inputs.flatMap({ $0.fields }).forEach {
      if let fieldVariable = $0 as? FieldVariable {
        fieldVariable.nameManager = nil
      }
    }
  }
}
