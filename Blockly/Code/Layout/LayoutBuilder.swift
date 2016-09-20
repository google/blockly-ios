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
Class for building a `Layout` hierarchy from a model object.
*/
@objc(BKYLayoutBuilder)
open class LayoutBuilder: NSObject {
  // MARK: - Properties

  /// Factory responsible for creating new `Layout` instances
  public let layoutFactory: LayoutFactory

  // MARK: - Initializer

  public init(layoutFactory: LayoutFactory) {
    self.layoutFactory = layoutFactory
  }

  // MARK: - Public

  /**
  Builds the entire layout tree for `self.workspaceLayout` based on the current model
  (ie. `self.workspaceLayout.workspace`).

  - Throws:
  `BlocklyError`: Thrown if the layout tree could not be created for this workspace.
  - Note: To increase performance during initialization, this should only be called after the entire
  workspace model has been constructed.
  */
  open func buildLayoutTree(_ workspaceLayout: WorkspaceLayout) throws {
    let workspace = workspaceLayout.workspace

    // Remove all child layouts
    workspaceLayout.reset(updateLayout: false)

    // Create layouts for every top-level block in the workspace
    for topLevelBlock in workspace.topLevelBlocks() {
      _ = try buildLayoutTreeForTopLevelBlock(topLevelBlock, workspaceLayout: workspaceLayout)
    }
  }

  /**
  Builds the layout tree for a top-level block.

  - Parameter block: The top-level block
  - Returns: A block group layout for the block, or nil if the block was not a top-level block.
  - Throws:
  `BlocklyError`: Thrown if the block is not part of the workspace this builder is associated with,
  or if the layout tree could not be created for this block.
  */
  open func buildLayoutTreeForTopLevelBlock(_ block: Block, workspaceLayout: WorkspaceLayout)
    throws -> BlockGroupLayout?
  {
    // Check that block is part of this workspace and is a top-level block
    if !workspaceLayout.workspace.containsBlock(block) {
      throw BlocklyError(.illegalState,
        "Can't build a layout tree for a block that has not been added to the workspace")
    }

    if !block.topLevel {
      // Can't build layout trees for non top-level block
      return nil
    }

    let blockGroupLayout =
      try layoutFactory.makeBlockGroupLayout(engine: workspaceLayout.engine)
    let position = block.position
    // If this Block has a position use it to initialize the layout's position.
    blockGroupLayout.move(toWorkspacePosition: position)

    try buildLayoutTreeForBlockGroupLayout(blockGroupLayout, block: block)

    workspaceLayout.appendBlockGroupLayout(blockGroupLayout, updateLayout: false)
    workspaceLayout.bringBlockGroupLayoutToFront(blockGroupLayout)

    return blockGroupLayout
  }

  /**
  Builds an entire `BlockGroupLayout` tree from a given top-level block.

  - Parameter blockGroupLayout: The block group layout to build
  - Parameter block: The top-level block to use as the first child of `blockGroupLayout`.
  */
  open func buildLayoutTreeForBlockGroupLayout(_ blockGroupLayout: BlockGroupLayout, block: Block)
    throws
  {
    blockGroupLayout.reset(updateLayout: false)

    // Create block layouts
    var blockLayouts = [BlockLayout]()
    var currentBlock: Block? = block
    while let block = currentBlock {
      let blockLayout = try buildLayoutTreeForBlock(block, engine: blockGroupLayout.engine)
      blockLayouts.append(blockLayout)
      currentBlock = currentBlock?.nextBlock ?? currentBlock?.nextShadowBlock
    }

    // Add to block group layout
    blockGroupLayout.appendBlockLayouts(blockLayouts, updateLayout: false)
  }

  /**
  Builds a `BlockLayout` tree for a given block and assigns it to the block's `delegate` property.
  This includes all connected blocks.

  - Parameter block: The block
  - Parameter engine: The `LayoutEngine` to associate with the returned `BlockLayout`.
  - Returns: The associated layout for the block.
  - Throws:
  `BlocklyError`: Thrown if the layout could not be created for any of the block's inputs.
  */
  open func buildLayoutTreeForBlock(_ block: Block, engine: LayoutEngine) throws -> BlockLayout
  {
    let blockLayout = try layoutFactory.makeBlockLayout(block: block, engine: engine)
    block.delegate = blockLayout // Have the layout listen for events on the block

    // Build the input layouts for this block
    for input in block.inputs {
      let inputLayout = try buildLayoutTreeForInput(input, engine: engine)
      blockLayout.appendInputLayout(inputLayout)
    }

    return blockLayout
  }

  /**
  Builds an `InputLayout` tree for a given input and assigns it to the input's `delegate` property.

  - Parameter input: The input
  - Parameter engine: The `LayoutEngine` to associate with the returned `InputLayout`.
  - Returns: The associated layout for the input.
  - Throws:
  `BlocklyError`: Thrown if the layout could not be created for any of the input's fields.
  */
  open func buildLayoutTreeForInput(_ input: Input, engine: LayoutEngine) throws -> InputLayout {
    let inputLayout = try layoutFactory.makeInputLayout(input: input, engine: engine)
    input.delegate = inputLayout // Have the layout listen for events on the input

    // Build field layouts for this input
    for field in input.fields {
      let fieldLayout = try buildLayoutForField(field, engine: engine)
      inputLayout.appendFieldLayout(fieldLayout)
    }

    if let connectedBlock = input.connectedBlock {
      // Build the block group layout underneath this input
      try buildLayoutTreeForBlockGroupLayout(inputLayout.blockGroupLayout, block: connectedBlock)
    } else if let connectedShadowBlock = input.connectedShadowBlock {
      // Build the shadow block group layout underneath this input
      try buildLayoutTreeForBlockGroupLayout(
        inputLayout.blockGroupLayout, block: connectedShadowBlock)
    }

    return inputLayout
  }

  /**
   Builds the layout for a given field and assigns it to the field's `delegate` property.

   - Parameter field: The field
   - Parameter engine: The `LayoutEngine` to associate with the returned `FieldLayout`.
   - Returns: The associated layout for the field.
   - Throws:
   `BlocklyError`: Thrown by `layoutFactory` if the layout could not be created for the field.
   */
  open func buildLayoutForField(_ field: Field, engine: LayoutEngine) throws -> FieldLayout {
    let fieldLayout = try layoutFactory.makeFieldLayout(field: field, engine: engine)
    field.delegate = fieldLayout // Have the layout listen for events on the field
    return fieldLayout
  }
}
