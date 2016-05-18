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

@testable import Blockly
import XCTest

class LayoutBuilderTest: XCTestCase {

  var _workspaceLayout: WorkspaceLayout!
  var _blockFactory: BlockFactory!

  // MARK: - Setup

  override func setUp() {
    super.setUp()

    _workspaceLayout = BKYAssertDoesNotThrow {
      try WorkspaceLayout(
        workspace: Workspace(),
        engine: DefaultLayoutEngine(),
        layoutBuilder: LayoutBuilder(layoutFactory: DefaultLayoutFactory()))
    }
    _blockFactory = BKYAssertDoesNotThrow {
      try BlockFactory(
        jsonPath: "all_test_blocks.json", bundle: NSBundle(forClass: self.dynamicType))
    }
  }

  // MARK: - Tests

  func testBuildLayoutTree() {
    let workspace = _workspaceLayout.workspace

    // Add blocks to the workspace
    guard
      let _ = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock("no_connections", toWorkspace: workspace)
      }),
      let blockStatementOutputNoInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock("output_no_input", toWorkspace: workspace)
      }),
      let blockInputOutput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock("simple_input_output", toWorkspace: workspace)
      }),
      let blockStatementMultipleInputValueInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock("statement_multiple_value_input", toWorkspace: workspace)
      }),
      let blockStatementNoNext = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock("statement_no_next", toWorkspace: workspace)
      }),
      let blockStatementStatementInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock("statement_statement_input", toWorkspace: workspace)
      }) else
    {
      XCTFail("Blocks couldn't be loaded into the workspace")
      return
    }

    // Connect some blocks together
    BKYAssertDoesNotThrow { () -> Void in
      try blockInputOutput.inputs[0].connection?.connectTo(
        blockStatementOutputNoInput.outputConnection)

      try blockStatementMultipleInputValueInput.inputs[1].connection?.connectTo(
        blockInputOutput.outputConnection)

      try blockStatementNoNext.previousConnection?.connectTo(
        blockStatementStatementInput.nextConnection)
    }

    // Build layout tree
    BKYAssertDoesNotThrow {
      try self._workspaceLayout.layoutBuilder.buildLayoutTree(self._workspaceLayout)
    }

    // Verify it
    verifyWorkspaceLayoutTree(_workspaceLayout)
  }

  func testBuildLayoutTreeForTopLevelBlock_ValidWithoutShadows() {
    let workspace = _workspaceLayout.workspace

    // Add blocks to the workspace
    guard
      let blockStatementOutputNoInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock("output_no_input", toWorkspace: workspace)
      }),
      let blockInputOutput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock("simple_input_output", toWorkspace: workspace)
      }),
      let blockStatementMultipleInputValueInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock("statement_multiple_value_input", toWorkspace: workspace)
      }),
      let blockStatementNoNext = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock("statement_no_next", toWorkspace: workspace)
      }),
      let blockStatementStatementInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock("statement_statement_input", toWorkspace: workspace)
      }) else
    {
      XCTFail("Blocks couldn't be loaded")
      return
    }

    // Connect into a megazord block 
    BKYAssertDoesNotThrow { () -> Void in
      try blockInputOutput.inputs[0].connection?.connectTo(
        blockStatementOutputNoInput.outputConnection)
      try blockStatementMultipleInputValueInput.inputs[0].connection?.connectTo(
        blockInputOutput.outputConnection)
      try blockStatementStatementInput.inputs[0].connection?.connectTo(
        blockStatementNoNext.previousConnection)
      try blockStatementStatementInput.nextConnection?.connectTo(
        blockStatementMultipleInputValueInput.previousConnection)
    }

    // Build layout tree for the only top-level block
    if let blockGroupLayout = BKYAssertDoesNotThrow({
      try self._workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(
        blockStatementStatementInput, workspaceLayout: self._workspaceLayout)
      })
    {
      verifyBlockGroupLayoutTree(blockGroupLayout, firstBlock: blockStatementStatementInput)
    } else {
      XCTFail("Could not create layout tree for top level block")
    }

    // Try building layout trees for non top-level blocks (these should all return nil)
    var emptyBlockGroup = BKYAssertDoesNotThrow {
      try self._workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(blockInputOutput,
        workspaceLayout: self._workspaceLayout)
    }
    XCTAssertNil(emptyBlockGroup)

    emptyBlockGroup = BKYAssertDoesNotThrow {
      try self._workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(
        blockStatementMultipleInputValueInput, workspaceLayout: self._workspaceLayout)
    }
    XCTAssertNil(emptyBlockGroup)

    emptyBlockGroup = BKYAssertDoesNotThrow {
      try self._workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(
        blockStatementNoNext, workspaceLayout: self._workspaceLayout)
    }
    XCTAssertNil(emptyBlockGroup)

    emptyBlockGroup = BKYAssertDoesNotThrow {
      try self._workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(
        blockStatementOutputNoInput, workspaceLayout: self._workspaceLayout)
    }
    XCTAssertNil(emptyBlockGroup)
  }

  func testBuildLayoutTreeForTopLevelBlock_ValidWithShadows() {
    let workspace = _workspaceLayout.workspace

    // Add blocks to the workspace
    guard
      let blockStatementMultipleInputValueInput = BKYAssertDoesNotThrow({
        try self._blockFactory.buildBlock("statement_multiple_value_input")
      }),
      let blockStatementStatementInput = BKYAssertDoesNotThrow({
        try self._blockFactory.buildBlock("statement_statement_input")
      }),
      let blockShadowInput =  BKYAssertDoesNotThrow({
        try self._blockFactory.buildBlock("simple_input_output", shadow: true)
      }),
      let blockShadowPrevious =  BKYAssertDoesNotThrow({
        try self._blockFactory.buildBlock("statement_no_next", shadow: true)
      }) else
    {
      XCTFail("Blocks couldn't be loaded")
      return
    }

    // Connect into a megazord block and add it to the workspace
    BKYAssertDoesNotThrow { () -> Void in
      try blockStatementMultipleInputValueInput.inputs[0].connection?.connectShadowTo(
        blockShadowInput.outputConnection)
      try blockStatementMultipleInputValueInput.nextConnection?.connectShadowTo(
        blockShadowPrevious.previousConnection)
      try blockStatementStatementInput.nextConnection?.connectTo(
        blockStatementMultipleInputValueInput.previousConnection)
      try workspace.addBlockTree(blockStatementStatementInput)
    }

    // Build layout tree for the only top-level block
    if let blockGroupLayout = BKYAssertDoesNotThrow({
      try self._workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(
        blockStatementStatementInput, workspaceLayout: self._workspaceLayout)
    })
    {
      verifyBlockGroupLayoutTree(blockGroupLayout, firstBlock: blockStatementStatementInput)
    } else {
      XCTFail("Could not create layout tree for top level block")
    }

    // Try building layout trees for non top-level shadow blocks (these should all return nil)
    var emptyBlockGroup = BKYAssertDoesNotThrow {
      try self._workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(
        blockShadowInput, workspaceLayout: self._workspaceLayout)
    }
    XCTAssertNil(emptyBlockGroup)

    emptyBlockGroup = BKYAssertDoesNotThrow {
      try self._workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(
        blockShadowPrevious, workspaceLayout: self._workspaceLayout)
    }
    XCTAssertNil(emptyBlockGroup)
  }

  func testBuildLayoutTreeForTopLevelBlock_WrongWorkspace() {
    let workspace2 = Workspace()

    // Add a blocks to workspace2
    guard let block = BKYAssertDoesNotThrow({
      try self._blockFactory.addBlock("output_no_input", toWorkspace: workspace2)
    }) else
    {
      XCTFail("Block couldn't be loaded into the workspace")
      return
    }

    // Try building the layout tree this block, but in the wrong workspace
    BKYAssertThrow(errorType: BlocklyError.self) {
      try self._workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(block,
        workspaceLayout: self._workspaceLayout)
    }
  }

  // TODO:(#37) Add tests for other field layouts once they're implemented

  // MARK: - Helper methods

  private func verifyWorkspaceLayoutTree(workspaceLayout: WorkspaceLayout) {
    let workspace = workspaceLayout.workspace

    // Construct dictionary of all top level blocks in the workspace, keyed by block and a flag
    // if it's been processed (ie. if a block group layout was found for it)
    var topLevelBlocks = [Block: Bool]()
    for block in workspace.topLevelBlocks() {
      topLevelBlocks[block] = false
    }

    // Check each block group layout against each top level block
    for blockGroupLayout in workspaceLayout.blockGroupLayouts {
      if blockGroupLayout.blockLayouts.count == 0 {
        // Block group layout is empty. Technically this is still legal, skip it.
        continue
      }

      let firstBlock = blockGroupLayout.blockLayouts[0].block

      if let processedFirstBlock = topLevelBlocks[firstBlock] {
        if processedFirstBlock {
          XCTFail("Multiple block group layouts exist for the same top-level block")
        } else {
          verifyBlockGroupLayoutTree(blockGroupLayout, firstBlock: firstBlock)

          topLevelBlocks[firstBlock] = true // Set the processed flag to true
        }
      } else {
        XCTFail("First block layout in the block group does not represent a top-level block")
      }
    }

    // Make sure that all top level blocks were processed
    XCTAssertEqual(0,
      topLevelBlocks.filter({ !$0.1 /* keep those that weren't processed */ }).count)
  }

  private func verifyBlockGroupLayoutTree(blockGroupLayout: BlockGroupLayout, firstBlock: Block?) {
    var currentBlock = firstBlock

    var i = 0
    while i < blockGroupLayout.blockLayouts.count || currentBlock != nil {
      guard let block = currentBlock where i < blockGroupLayout.blockLayouts.count else {
        XCTFail("The number of block layouts in the group doesn't match the number of " +
          "blocks in the chain")
        return
      }
      if block.layout == nil {
        XCTFail("Layout is missing for block: \(block)")
      } else {
        let blockLayout = blockGroupLayout.blockLayouts[i]

        // Make sure the block matches the blockGroupLayout's block
        XCTAssertEqual(block.layout, blockLayout)

        // Check that the block layout's parent is set to this block group layout
        XCTAssertEqual(blockGroupLayout, blockLayout.parentBlockGroupLayout)

        // Check that block layout's block matches the current block
        XCTAssertEqual(block, blockLayout.block)

        // Verify the block layout itself
        verifyBlockLayoutTree(blockLayout)
      }

      currentBlock = currentBlock?.nextBlock ?? currentBlock?.nextShadowBlock
      i += 1
    }

    XCTAssertNil(currentBlock,
      "The number of blocks in the chain exceeds the number of block layouts in the group")
  }

  private func verifyBlockLayoutTree(blockLayout: BlockLayout) {
    let block = blockLayout.block

    // Make sure the number of inputLayouts matches the number of inputs
    XCTAssertEqual(block.inputs.count, blockLayout.inputLayouts.count)

    for i in 0 ..< block.inputs.count {
      let inputLayout = blockLayout.inputLayouts[i]

      if block.inputs[i].layout == nil {
        XCTFail("Layout is missing for input: \(block.inputs[i])")
      } else {
        // Make sure the input matches the inputLayout's input
        XCTAssertEqual(block.inputs[i], inputLayout.input)

        // Check that the input layout's parent is set to this block layout
        XCTAssertEqual(blockLayout, inputLayout.parentBlockLayout)
        XCTAssertEqual(block, inputLayout.input.sourceBlock)

        // Verify the input layout itself
        verifyInputLayoutTree(inputLayout)
      }
    }
  }

  private func verifyInputLayoutTree(inputLayout: InputLayout) {
    let input = inputLayout.input

    // Make sure the number of fieldLayouts matches the number of fields
    XCTAssertEqual(input.fields.count, inputLayout.fieldLayouts.count)

    for i in 0 ..< input.fields.count {
      let fieldLayout = inputLayout.fieldLayouts[i]

      if input.fields[i].layout == nil {
        XCTFail("Layout is missing for field: \(input.fields[i])")
      } else {
        // Make sure the field matches the fieldLayout's field
        XCTAssertEqual(input.fields[i], fieldLayout.field)

        // Check that the field layout's parent is set to this input layout
        if let parentInputLayout = fieldLayout.parentInputLayout {
          XCTAssertEqual(inputLayout, parentInputLayout)
        } else {
          XCTFail("Parent layout has not been set for field layout: \(fieldLayout)")
        }

        verifyFieldLayout(fieldLayout)
      }
    }

    verifyBlockGroupLayoutTree(inputLayout.blockGroupLayout,
                               firstBlock: input.connectedBlock ?? input.connectedShadowBlock)
  }

  private func verifyFieldLayout(fieldLayout: FieldLayout) {
    XCTAssertNotNil(fieldLayout.field.layout)
    XCTAssertEqual(fieldLayout, fieldLayout.field.layout)
  }
}
