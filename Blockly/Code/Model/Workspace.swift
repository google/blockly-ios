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
Point in the Workspace coordinate system (which is separate from the UIView coordinate system).
*/
public typealias WorkspacePoint = CGPoint
public var WorkspacePointZero: WorkspacePoint { return CGPointZero }
public func WorkspacePointMake(x: CGFloat, _ y: CGFloat) -> WorkspacePoint {
  return CGPointMake(x, y)
}

/**
Size in the Workspace coordinate system (which is separate from the UIView coordinate system).
*/
public typealias WorkspaceSize = CGSize
public var WorkspaceSizeZero: WorkspaceSize { return CGSizeZero }
public func WorkspaceSizeMake(width: CGFloat, _ height: CGFloat) -> WorkspaceSize {
  return CGSizeMake(width, height)
}

/**
Edge insets in the Workspace coordinate system (which is separate from the UIView coordinate
system).
*/
public typealias WorkspaceEdgeInsets = UIEdgeInsets
public var WorkspaceEdgeInsetsZero: WorkspaceEdgeInsets { return UIEdgeInsetsZero }
public func WorkspaceEdgeInsetsMake(
  top: CGFloat, _ left: CGFloat, _ bottom: CGFloat, _ right: CGFloat) -> WorkspaceEdgeInsets {
  return UIEdgeInsetsMake(top, left, bottom, right)
}

/**
 Protocol for events that occur on a `Workspace` instance.
 */
@objc(BKYWorkspaceDelegate)
public protocol WorkspaceDelegate: class {
  /**
   Event that is called when a block has been added to a workspace.

   - Parameter workspace: The workspace that added a block.
   - Parameter block: The block that was added.
  */
  func workspace(workspace: Workspace, didAddBlock block: Block)

  /**
   Event that is called when a block will be removed from a workspace.

   - Parameter workspace: The workspace that will remove a block.
   - Parameter block: The block that will be removed.
   */
  func workspace(workspace: Workspace, willRemoveBlock block: Block)
}

/**
Data structure that contains `Block` instances.
*/
@objc(BKYWorkspace)
public class Workspace : NSObject {
  // MARK: - Properties

  // TODO:(#85) Enforce this property
  /// The maximum number of blocks that this workspace may contain. If this value is set to `nil`,
  /// no maximum limit is enforced.
  public let maxBlocks: Int?

  /// Dictionary mapping all `Block` instances in this workspace to their `uuid` value
  public private(set) var allBlocks = [String: Block]()

  /// Flag indicating if this workspace is set to read-only
  public var readOnly: Bool = false

  /// The delegate for events that occur in this workspace
  public weak var delegate: WorkspaceDelegate?

  /// Convenience property for accessing `self.delegate` as a `WorkspaceLayout`
  public var layout: WorkspaceLayout? {
    return self.delegate as? WorkspaceLayout
  }

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
  Initializer for a Workspace.

  - Parameter maxBlocks: Optional parameter for setting `self.maxBlocks`.
  */
  public init(rtl: Bool? = nil, maxBlocks: Int? = nil) {
    self.maxBlocks = maxBlocks
    super.init()
  }

  // MARK: - Public

  /**
   Returns: A list of all blocks in the workspace whose `topLevel` property is true.
   */
  public func topLevelBlocks() -> [Block] {
    return allBlocks.values.filter({ $0.topLevel })
  }

  /**
   Adds a block and all of its connected blocks to the workspace.

   - Parameter rootBlock: The root block to add.
   - Throws:
   `BlocklyError`: Thrown if one of the blocks uses a uuid that is already being used by another
   block in the workspace.
   */
  public func addBlockTree(rootBlock: Block) throws {
    for block in rootBlock.allBlocksForTree() {
      if let existingBlock = allBlocks[block.uuid] {
        if existingBlock == block {
          // The block is already in the workspace
          continue
        } else {
          throw BlocklyError(.IllegalState,
            "Cannot add a block into the workspace with a uuid that is already being used by " +
            "another block")
        }
      }

      if block.shadow && block.topLevel {
        throw BlocklyError(
          .IllegalState, "Shadow block cannot be added to the workspace as a top-level block.")
      }

      allBlocks[block.uuid] = block
      block.sourceWorkspace = self
      delegate?.workspace(self, didAddBlock: block)

      addNameManager(variableNameManager, toBlock: block)
    }
  }

  /**
   Disconnects a given block from its previous/output connections, and removes it and all of its
   connected blocks from the workspace.

   - Parameter rootBlock: The root block to remove.
   */
  public func removeBlockTree(rootBlock: Block) {
    // Disconnect this block from anything
    rootBlock.previousConnection?.disconnect()
    rootBlock.outputConnection?.disconnect()

    // Remove all blocks from this block tree
    for block in rootBlock.allBlocksForTree() {
      if containsBlock(block) {
        delegate?.workspace(self, willRemoveBlock: block)
        removeNameManagerFromBlock(block)
        allBlocks[block.uuid] = nil
        block.sourceWorkspace = nil
      }
    }
  }

  /**
   Deep copies a block and adds all of the copied blocks into the workspace.

   - Parameter rootBlock: The root block to copy
   - Parameter editable: Sets whether each block is `editable` or not
   - Returns: The root block that was copied
   - Throws:
   `BlocklyError`: Thrown if the block could not be copied
   */
  public func copyBlockTree(rootBlock: Block, editable: Bool) throws -> Block {
    let copyResult = try rootBlock.deepCopy()
    try addBlockTree(copyResult.rootBlock)
    for block in copyResult.allBlocks {
      block.editable = editable
    }
    return copyResult.rootBlock
  }

  /**
  Returns if this block has been added to the workspace.
  */
  public func containsBlock(block: Block) -> Bool {
    return (allBlocks[block.uuid] == block)
  }

  // MARK: - Private

  /**
   For all `FieldVariable` instances under a given `Block`, set their `nameManager` property to a
   given `NameManager`.

   - Parameter nameManager: The `NameManager` to set
   - Parameter block: The `Block`
   */
  private func addNameManager(nameManager: NameManager?, toBlock block: Block) {
    block.inputs.flatMap({ $0.fields }).forEach {
      if let fieldVariable = $0 as? FieldVariable {
        fieldVariable.nameManager = nameManager
      }
    }
  }

  /**
   Sets the `nameManager` for all `FieldVariable` instances under the given `Block` to `nil`.

   - Parameter block: The `Block`
   */
  private func removeNameManagerFromBlock(block: Block) {
    block.inputs.flatMap({ $0.fields }).forEach {
      if let fieldVariable = $0 as? FieldVariable {
        fieldVariable.nameManager = nil
      }
    }
  }
}
