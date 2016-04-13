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
    let workspace = Workspace()
    let layoutFactory = DefaultLayoutFactory()
    _workspaceLayout = try! WorkspaceLayout(workspace: workspace,
      engine: DefaultLayoutEngine(), layoutBuilder: LayoutBuilder(layoutFactory: layoutFactory))
    _blockFactory = try! BlockFactory(
      jsonPath: "all_test_blocks.json", bundle: NSBundle(forClass: self.dynamicType))
  }

  // MARK: - Tests

  func testBuildLayoutTree() {
    let workspace = _workspaceLayout.workspace

    // Add blocks to the workspace
    guard
      let _ =
        try! _blockFactory.addBlock("no_connections", toWorkspace: workspace),
      let blockStatementOutputNoInput =
        try! _blockFactory.addBlock("output_no_input", toWorkspace: workspace),
      let blockInputOutput =
        try! _blockFactory.addBlock("simple_input_output", toWorkspace: workspace),
      let blockStatementMultipleInputValueInput =
        try! _blockFactory.addBlock("statement_multiple_value_input", toWorkspace: workspace),
      let blockStatementNoNext =
        try! _blockFactory.addBlock("statement_no_next", toWorkspace: workspace),
      let blockStatementStatementInput =
        try! _blockFactory.addBlock("statement_statement_input", toWorkspace: workspace)
      else
    {
      XCTFail("Blocks couldn't be loaded into the workspace")
      return
    }

    // Connect some blocks together
    do {
      try blockInputOutput.inputs[0].connection?.connectTo(
        blockStatementOutputNoInput.outputConnection)

      try blockStatementMultipleInputValueInput.inputs[1].connection?.connectTo(
        blockInputOutput.outputConnection)

      try blockStatementNoNext.previousConnection?.connectTo(
        blockStatementStatementInput.nextConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect blocks together: \(error)")
    }

    // Build layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    // Verify it
    verifyWorkspaceLayoutTree(_workspaceLayout)
  }

  func testBuildLayoutTreeForTopLevelBlockValid() {
    let workspace = _workspaceLayout.workspace

    // Add blocks to the workspace
    guard
      let blockStatementOutputNoInput =
        try! _blockFactory.addBlock("output_no_input", toWorkspace: workspace),
      let blockInputOutput =
        try! _blockFactory.addBlock("simple_input_output", toWorkspace: workspace),
      let blockStatementMultipleInputValueInput =
        try! _blockFactory.addBlock("statement_multiple_value_input", toWorkspace: workspace),
      let blockStatementNoNext =
        try! _blockFactory.addBlock("statement_no_next", toWorkspace: workspace),
      let blockStatementStatementInput =
        try! _blockFactory.addBlock("statement_statement_input", toWorkspace: workspace)
      else
    {
      XCTFail("Blocks couldn't be loaded")
      return
    }

    // Connect into a megazord block 
    do {
      try blockInputOutput.inputs[0].connection?.connectTo(
        blockStatementOutputNoInput.outputConnection)
      try blockStatementMultipleInputValueInput.inputs[0].connection?.connectTo(
        blockInputOutput.outputConnection)
      try blockStatementStatementInput.inputs[0].connection?.connectTo(
        blockStatementNoNext.previousConnection)
      try blockStatementStatementInput.nextConnection?.connectTo(
        blockStatementMultipleInputValueInput.previousConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect blocks together: \(error)")
    }

    do {
      // Build layout tree for the only top-level block
      if let blockGroupLayout =
        try _workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(
          blockStatementStatementInput, workspaceLayout: _workspaceLayout)
      {
        verifyBlockGroupLayoutTree(blockGroupLayout, firstBlock: blockStatementStatementInput)
      } else {
        XCTFail("Could not create layout tree for top level block")
      }

      // Try building layout trees for non top-level blocks (these should all return nil)
      var emptyBlockGroup =
        try _workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(blockInputOutput,
          workspaceLayout: _workspaceLayout)
      XCTAssertNil(emptyBlockGroup)

      emptyBlockGroup = try _workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(
        blockStatementMultipleInputValueInput, workspaceLayout: _workspaceLayout)
      XCTAssertNil(emptyBlockGroup)

      emptyBlockGroup = try _workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(
        blockStatementNoNext, workspaceLayout: _workspaceLayout)
      XCTAssertNil(emptyBlockGroup)

      emptyBlockGroup = try _workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(
        blockStatementOutputNoInput, workspaceLayout: _workspaceLayout)
      XCTAssertNil(emptyBlockGroup)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }
  }

  func testBuildLayoutTreeForTopLevelBlockWrongWorkspace() {
    let workspace2 = Workspace()

    // Add a blocks to workspace2
    guard let block = try! _blockFactory.addBlock("output_no_input", toWorkspace: workspace2) else {
      XCTFail("Block couldn't be loaded into the workspace")
      return
    }

    do {
      // Try building the layout tree this block, but in the wrong workspace
      try _workspaceLayout.layoutBuilder.buildLayoutTreeForTopLevelBlock(block,
        workspaceLayout: _workspaceLayout)
      XCTFail("A layout tree was built for a block in the wrong workspace")
    } catch _ as NSError {
      // An error should have been thrown. Everything is awesome.
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

    for i in 0 ..< blockGroupLayout.blockLayouts.count {
      guard let block = currentBlock else {
        XCTFail(
          "The number of block layouts in the group exceeds the number of blocks in the chain")
        return
      }
      if i == 0 {
        XCTAssertNil(block.previousBlock,
          "The first block in the group is not the head of the chain of blocks")
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

      currentBlock = currentBlock?.nextBlock
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

    verifyBlockGroupLayoutTree(inputLayout.blockGroupLayout, firstBlock: input.connectedBlock)
  }
  
  private func verifyFieldLayout(fieldLayout: FieldLayout) {
    XCTAssertNotNil(fieldLayout.field.layout)
    XCTAssertEqual(fieldLayout, fieldLayout.field.layout)
  }
}
