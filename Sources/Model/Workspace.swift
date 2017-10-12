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
   Event that is called when a list of block trees will be added to a workspace.

   - parameter workspace: The workspace that will add a list of block trees.
   - parameter blockTrees: The list of root blocks that will be added.
   */
  @objc optional func workspace(_ workspace: Workspace, willAddBlockTrees blockTrees: [Block])

  /**
   Event that is called when a list of block trees have been added to a workspace.

   - parameter workspace: The workspace that added a list of block trees.
   - parameter blockTrees: The list of root blocks that have been added.
  */
  @objc optional func workspace(_ workspace: Workspace, didAddBlockTrees blockTrees: [Block])

  /**
   Event that is called when a list of block trees will be removed from a workspace.

   - parameter workspace: The workspace that will remove a list of block trees.
   - parameter blockTrees: The list of root blocks that will be removed.
   */
  @objc optional func workspace(_ workspace: Workspace, willRemoveBlockTrees blockTrees: [Block])

  /**
   Event that is called when a list of block trees have been removed from a workspace.

   - parameter workspace: The workspace that removed a list of block trees.
   - parameter blockTrees: The list of root blocks that have been removed.
   */
  @objc optional func workspace(_ workspace: Workspace, didRemoveBlockTrees blockTrees: [Block])
}

/**
Data structure that contains `Block` instances.
*/
@objc(BKYWorkspace)
@objcMembers open class Workspace : NSObject {
  // MARK: - Properties

  /// A unique identifier used to identify this workspace for its lifetime
  public let uuid: String

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

  /// Specifies the type of workspace this one is.
  internal enum WorkspaceType: Int {
    case
    // A "normal" workspace, which supports dragging, import/export, code generation, etc.
    interactive = 0,
    // A toolbox workspace
    toolbox,
    // A trash workspace
    trash
  }

  internal var workspaceType: WorkspaceType = .interactive

  // MARK: - Initializers

  /**
   Creates a Workspace, with no maximum capacity.
   */
  public override init() {
    self.uuid = UUID().uuidString
    self.maxBlocks = nil
    super.init()
  }

  /**
   Creates a Workspace, specifying a maximum capacity.

   - parameter uuid: [Optional] A specific UUID to assign to this workspace. If none is specified,
   one is automatically created and assigned to the workspace.
   - parameter maxBlocks: [Optional] The maximum number of blocks allowed in this workspace.
   */
  public init(uuid: String? = nil, maxBlocks: Int? = nil) {
    self.uuid = uuid ?? UUID().uuidString
    self.maxBlocks = maxBlocks
    super.init()
  }

  // MARK: - Public

  /**
   Returns a list of all blocks in the workspace whose `topLevel` property is true.

   - returns: A list of all top-level blocks in the workspace.
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
    try addBlockTrees([rootBlock])
  }

  /**
   Adds a list of blocks and all of their connected blocks to the workspace.

   - parameter rootBlocks: The list of root blocks to add.
   - throws:
   `BlocklyError`: Thrown if one of the blocks uses a uuid that is already being used by another
   block in the workspace or if adding the new list of blocks would exceed the maximum amount
   allowed.
   */
  open func addBlockTrees(_ rootBlocks: [Block]) throws {
    var newRootBlocks = [String: Block]()
    var newBlocks = [String: Block]()

    // Check that all new blocks will not mess up the state of the workspace.
    for rootBlock in rootBlocks {
      if containsBlock(rootBlock) {
        // This root block is already in the workspace. Skip it.
        continue
      } else if !rootBlock.topLevel {
        throw BlocklyError(.illegalArgument,
          "A non-top level block tree cannot be added to the workspace.")
      }

      for block in rootBlock.allBlocksForTree() {
        if allBlocks[block.uuid] != nil {
          throw BlocklyError(.illegalState,
            "A block cannot be added into the workspace with a uuid ('\(block.uuid)') " +
            "that is already being used by another block.")
        } else if newBlocks[block.uuid] != nil {
          throw BlocklyError(.illegalArgument,
            "Two blocks with the same uuid ('\(block.uuid)') cannot be added into the " +
            "workspace at the same time.")
        } else if block.shadow && block.topLevel {
          throw BlocklyError(
            .illegalState, "A shadow block cannot be added to the workspace as a top-level block.")
        }

        newBlocks[block.uuid] = block
      }

      // This block tree passes all checks. Add it to the list.
      newRootBlocks[rootBlock.uuid] = rootBlock
    }

    if let maxBlocks = self.maxBlocks , (allBlocks.count + newBlocks.count) > maxBlocks {
      throw BlocklyError(.workspaceExceedsCapacity,
        "Adding more blocks would exceed the maximum amount allowed (\(maxBlocks)).")
    }

    // Fire listeners for all blocks that will be added to the workspace
    let newRootBlockTrees = Array(newRootBlocks.values)
    listeners.forEach { $0.workspace?(self, willAddBlockTrees: newRootBlockTrees) }

    // All checks passed. Add the new blocks to the workspace.
    for (_, block) in newBlocks {
      block.editable = block.editable && !readOnly
      allBlocks[block.uuid] = block
    }

    // Notify delegate for each block addition, now that all of them have been added to the
    // workspace
    listeners.forEach { $0.workspace?(self, didAddBlockTrees: newRootBlockTrees) }
  }

  /**
   Removes a given block and all of its connected child blocks from the workspace.

   - parameter rootBlock: The root block to remove.
   - throws:
   `BlocklyError`: Thrown if the tree of blocks could not be removed from the workspace.
   */
  open func removeBlockTree(_ rootBlock: Block) throws {
    try removeBlockTrees([rootBlock])
  }

  /**
   Removes a given list of blocks and all of their connected child blocks from the workspace.

   - parameter rootBlocks: The list of root blocks to remove.
   - throws:
   `BlocklyError`: Thrown if the list of blocks could not be removed from the workspace.
   */
  open func removeBlockTrees(_ rootBlocks: [Block]) throws {
    for rootBlock in rootBlocks {
      if !rootBlock.topLevel {
        throw BlocklyError(.illegalOperation,
          "A root block must be disconnected from its previous and/or output connections prior " +
          "to being removed from the workspace.")
      }
    }

    // Fire listeners for block trees that will be removed from the workspace
    listeners.forEach { $0.workspace?(self, willRemoveBlockTrees: rootBlocks) }

    // Remove blocks at the same time
    for rootBlock in rootBlocks {
      for block in rootBlock.allBlocksForTree() {
        allBlocks[block.uuid] = nil
      }
    }

    // Fire listeners for all blocks that were removed
    listeners.forEach { $0.workspace?(self, didRemoveBlockTrees: rootBlocks) }
  }

  /**
   Deep copies a block and adds all of the copied blocks into the workspace.

   - parameter rootBlock: The root block to copy
   - parameter editable: Sets whether each block is `editable` or not
   - parameter position: The position of where the copied block should be placed in the workspace.
   - returns: The root block that was copied
   - throws:
   `BlocklyError`: Thrown if the block could not be copied
   */
  @discardableResult
  open func copyBlockTree(
    _ rootBlock: Block, editable: Bool, position: WorkspacePoint) throws -> Block
  {
    // Create a copy of the tree
    let copyResult = try rootBlock.deepCopy()

    // Set the `editable` property of each block prior to adding them to the workspace so we don't
    // overfire the listeners on each block (currently, each block has no listeners, but it could
    // have once it's been added to the workspace)
    for block in copyResult.allBlocks {
      block.editable = editable
    }

    copyResult.rootBlock.position = position

    // Add copy of tree to the workspace
    try addBlockTree(copyResult.rootBlock)

    return copyResult.rootBlock
  }

  /**
   Returns if this block has been added to the workspace.

   - parameter block: The `Block` to check.
   - returns: `true` if this block has been added to the workspace. `false` otherwise.
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
        block.editable = !deactivated && !readOnly
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
}
