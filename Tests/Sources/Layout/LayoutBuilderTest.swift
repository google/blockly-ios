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
  var _layoutBuilder: LayoutBuilder!

  // MARK: - Setup

  override func setUp() {
    super.setUp()

    _workspaceLayout = WorkspaceLayout(workspace: Workspace(), engine: DefaultLayoutEngine())
    _layoutBuilder = LayoutBuilder(layoutFactory: LayoutFactory())
    _blockFactory = BlockFactory()
    BKYAssertDoesNotThrow {
      try _blockFactory.load(fromJSONPaths: ["all_test_blocks.json"],
                             bundle: Bundle(for: type(of: self)))
    }
  }

  // MARK: - Tests

  func testBuildLayoutTree() {
    let workspace = _workspaceLayout.workspace

    // Add blocks to the workspace
    guard
      let _ = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock(name: "no_connections", toWorkspace: workspace)
      }),
      let blockStatementOutputNoInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock(name: "output_no_input", toWorkspace: workspace)
      }),
      let blockInputOutput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock(name: "simple_input_output", toWorkspace: workspace)
      }),
      let blockStatementMultipleInputValueInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock(name: "statement_multiple_value_input",
        toWorkspace: workspace)
      }),
      let blockStatementNoNext = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock(name: "statement_no_next", toWorkspace: workspace)
      }),
      let blockStatementStatementInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock(name: "statement_statement_input", toWorkspace: workspace)
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
      try _layoutBuilder.buildLayoutTree(forWorkspaceLayout: self._workspaceLayout)
    }

    // Verify it
    verifyWorkspaceLayoutTree(_workspaceLayout)
  }

  func testBuildLayoutTreeForTopLevelBlock_ValidWithoutShadows() {
    let workspace = _workspaceLayout.workspace

    // Add blocks to the workspace
    guard
      let blockStatementOutputNoInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock(name: "output_no_input", toWorkspace: workspace)
      }),
      let blockInputOutput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock(name: "simple_input_output", toWorkspace: workspace)
      }),
      let blockStatementMultipleInputValueInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock(name: "statement_multiple_value_input",
        toWorkspace: workspace)
      }),
      let blockStatementNoNext = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock(name: "statement_no_next", toWorkspace: workspace)
      }),
      let blockStatementStatementInput = BKYAssertDoesNotThrow({
        try self._blockFactory.addBlock(name: "statement_statement_input", toWorkspace: workspace)
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
      try _layoutBuilder.buildLayoutTree(
        forTopLevelBlock: blockStatementStatementInput, workspaceLayout: self._workspaceLayout)
      })
    {
      verifyBlockGroupLayoutTree(blockGroupLayout, firstBlock: blockStatementStatementInput)
    } else {
      XCTFail("Could not create layout tree for top level block")
    }

    // Try building layout trees for non top-level blocks (these should all throw errors)
    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _layoutBuilder.buildLayoutTree(forTopLevelBlock: blockInputOutput,
        workspaceLayout: self._workspaceLayout)
    }

    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _layoutBuilder.buildLayoutTree(
        forTopLevelBlock: blockStatementMultipleInputValueInput, workspaceLayout: self._workspaceLayout)
    }

    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _layoutBuilder.buildLayoutTree(
        forTopLevelBlock: blockStatementNoNext, workspaceLayout: self._workspaceLayout)
    }

    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _layoutBuilder.buildLayoutTree(
        forTopLevelBlock: blockStatementOutputNoInput, workspaceLayout: self._workspaceLayout)
    }
  }

  func testBuildLayoutTreeForTopLevelBlock_ValidWithShadows() {
    let workspace = _workspaceLayout.workspace

    // Add blocks to the workspace
    guard
      let blockStatementMultipleInputValueInput = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "statement_multiple_value_input")
      }),
      let blockStatementStatementInput = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "statement_statement_input")
      }),
      let blockShadowInput =  BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "simple_input_output", shadow: true)
      }),
      let blockShadowPrevious =  BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "statement_no_next", shadow: true)
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
      try _layoutBuilder.buildLayoutTree(
        forTopLevelBlock: blockStatementStatementInput, workspaceLayout: self._workspaceLayout)
    })
    {
      verifyBlockGroupLayoutTree(blockGroupLayout, firstBlock: blockStatementStatementInput)
    } else {
      XCTFail("Could not create layout tree for top level block")
    }

    // Try building layout trees for non top-level shadow blocks (these should all throw errors)
    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _layoutBuilder.buildLayoutTree(
        forTopLevelBlock: blockShadowInput, workspaceLayout: self._workspaceLayout)
    }

    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _layoutBuilder.buildLayoutTree(
        forTopLevelBlock: blockShadowPrevious, workspaceLayout: self._workspaceLayout)
    }
  }

  func testBuildLayoutTreeForTopLevelBlock_WrongWorkspace() {
    let workspace2 = Workspace()

    // Add a blocks to workspace2
    guard let block = BKYAssertDoesNotThrow({
      try self._blockFactory.addBlock(name: "output_no_input", toWorkspace: workspace2)
    }) else
    {
      XCTFail("Block couldn't be loaded into the workspace")
      return
    }

    // Try building the layout tree this block, but in the wrong workspace
    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _layoutBuilder.buildLayoutTree(forTopLevelBlock: block,
                                             workspaceLayout: _workspaceLayout)
    }
  }

  // TODO(#37): Add tests for other field layouts once they're implemented

  // MARK: - Helper methods

  fileprivate func verifyWorkspaceLayoutTree(_ workspaceLayout: WorkspaceLayout) {
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

  fileprivate func verifyBlockGroupLayoutTree(_ blockGroupLayout: BlockGroupLayout,
                                              firstBlock: Block?)
  {
    var currentBlock = firstBlock

    var i = 0
    while i < blockGroupLayout.blockLayouts.count || currentBlock != nil {
      guard let block = currentBlock , i < blockGroupLayout.blockLayouts.count else {
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

  fileprivate func verifyBlockLayoutTree(_ blockLayout: BlockLayout) {
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

  fileprivate func verifyInputLayoutTree(_ inputLayout: InputLayout) {
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
        if let parentLayout = fieldLayout.parentLayout {
          XCTAssertEqual(inputLayout, parentLayout)
        } else {
          XCTFail("Parent layout has not been set for field layout: \(fieldLayout)")
        }

        verifyFieldLayout(fieldLayout)
      }
    }

    verifyBlockGroupLayoutTree(inputLayout.blockGroupLayout,
                               firstBlock: input.connectedBlock ?? input.connectedShadowBlock)
  }

  fileprivate func verifyFieldLayout(_ fieldLayout: FieldLayout) {
    XCTAssertNotNil(fieldLayout.field.layout)
    XCTAssertEqual(fieldLayout, fieldLayout.field.layout)
  }
}
