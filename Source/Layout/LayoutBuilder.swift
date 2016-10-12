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

  /**
   Initializes the layout builder.

   - parameter layoutFactory: The `LayoutFactory` for layout creation.
   */
  public init(layoutFactory: LayoutFactory) {
    self.layoutFactory = layoutFactory
  }

  // MARK: - Public

  /**
  Builds the entire layout tree for `self.workspaceLayout` based on the current model
  (ie. `self.workspaceLayout.workspace`).

  - throws:
  `BlocklyError`: Thrown if the layout tree could not be created for this workspace.
  - note: To increase performance during initialization, this should only be called after the entire
  workspace model has been constructed.
  */
  open func buildLayoutTree(forWorkspaceLayout workspaceLayout: WorkspaceLayout) throws {
    let workspace = workspaceLayout.workspace

    // Remove all child layouts
    workspaceLayout.reset(updateLayout: false)

    // Create layouts for every top-level block in the workspace
    for topLevelBlock in workspace.topLevelBlocks() {
      _ = try buildLayoutTree(forTopLevelBlock: topLevelBlock, workspaceLayout: workspaceLayout)
    }
  }

  /**
  Builds the layout tree for a top-level block.

  - parameter block: The top-level block
  - returns: A block group layout for the block, or nil if the block was not a top-level block.
  - throws:
  `BlocklyError`: Thrown if the block is not part of the workspace this builder is associated with,
  or if the layout tree could not be created for this block.
  */
  open func buildLayoutTree(forTopLevelBlock block: Block, workspaceLayout: WorkspaceLayout)
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

    try buildLayoutTree(forBlockGroupLayout: blockGroupLayout, block: block)

    workspaceLayout.appendBlockGroupLayout(blockGroupLayout, updateLayout: false)
    workspaceLayout.bringBlockGroupLayoutToFront(blockGroupLayout)

    // If this Block had a position, use it to initialize the layout's position.
    blockGroupLayout.move(toWorkspacePosition: block.position)

    return blockGroupLayout
  }

  /**
  Builds an entire `BlockGroupLayout` tree from a given top-level block.

  - parameter blockGroupLayout: The block group layout to build
  - parameter block: The top-level block to use as the first child of `blockGroupLayout`.
  */
  open func buildLayoutTree(forBlockGroupLayout blockGroupLayout: BlockGroupLayout, block: Block)
    throws
  {
    blockGroupLayout.reset(updateLayout: false)

    // Create block layouts
    var blockLayouts = [BlockLayout]()
    var currentBlock: Block? = block
    while let block = currentBlock {
      let blockLayout = try buildLayoutTree(forBlock: block, engine: blockGroupLayout.engine)
      blockLayouts.append(blockLayout)
      currentBlock = currentBlock?.nextBlock ?? currentBlock?.nextShadowBlock
    }

    // Add to block group layout
    blockGroupLayout.appendBlockLayouts(blockLayouts, updateLayout: false)
  }

  /**
  Builds a `BlockLayout` tree for a given block and assigns it to the block's `delegate` property.
  This includes all connected blocks.

  - parameter block: The block
  - parameter engine: The `LayoutEngine` to associate with the returned `BlockLayout`.
  - returns: The associated layout for the block.
  - throws:
  `BlocklyError`: Thrown if the layout could not be created for any of the block's inputs.
  */
  open func buildLayoutTree(forBlock block: Block, engine: LayoutEngine) throws -> BlockLayout
  {
    let blockLayout = try layoutFactory.makeBlockLayout(block: block, engine: engine)
    block.delegate = blockLayout // Have the layout listen for events on the block

    // Build the input layouts for this block
    for input in block.inputs {
      let inputLayout = try buildLayoutTree(forInput: input, engine: engine)
      blockLayout.appendInputLayout(inputLayout)
    }

    return blockLayout
  }

  /**
  Builds an `InputLayout` tree for a given input and assigns it to the input's `delegate` property.

  - parameter input: The input
  - parameter engine: The `LayoutEngine` to associate with the returned `InputLayout`.
  - returns: The associated layout for the input.
  - throws:
  `BlocklyError`: Thrown if the layout could not be created for any of the input's fields.
  */
  open func buildLayoutTree(forInput input: Input, engine: LayoutEngine) throws -> InputLayout {
    let inputLayout = try layoutFactory.makeInputLayout(input: input, engine: engine)
    input.delegate = inputLayout // Have the layout listen for events on the input

    // Build field layouts for this input
    for field in input.fields {
      let fieldLayout = try buildLayout(forField: field, engine: engine)
      inputLayout.appendFieldLayout(fieldLayout)
    }

    if let connectedBlock = input.connectedBlock {
      // Build the block group layout underneath this input
      try buildLayoutTree(forBlockGroupLayout: inputLayout.blockGroupLayout, block: connectedBlock)
    } else if let connectedShadowBlock = input.connectedShadowBlock {
      // Build the shadow block group layout underneath this input
      try buildLayoutTree(forBlockGroupLayout: inputLayout.blockGroupLayout,
        block: connectedShadowBlock)
    }

    return inputLayout
  }

  /**
   Builds the layout for a given field and assigns it to the field's `delegate` property.

   - parameter field: The field
   - parameter engine: The `LayoutEngine` to associate with the returned `FieldLayout`.
   - returns: The associated layout for the field.
   - throws:
   `BlocklyError`: Thrown by `layoutFactory` if the layout could not be created for the field.
   */
  open func buildLayout(forField field: Field, engine: LayoutEngine) throws -> FieldLayout {
    let fieldLayout = try layoutFactory.makeFieldLayout(field: field, engine: engine)
    field.delegate = fieldLayout // Have the layout listen for events on the field
    return fieldLayout
  }
}
