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

/**
Tests for BlockLayout.
 
- Note: Tests for appendInputLayout, removeInputLayoutAtIndex, and reset were omitted, since they
are functionally tested by `LayoutBuilderTest`.
*/
class BlockLayoutTest: XCTestCase {

  var _workspaceLayout: WorkspaceLayout!
  var _blockFactory: BlockFactory!

  // MARK: - Setup

  override func setUp() {
    let workspace = Workspace()
    _workspaceLayout = try! WorkspaceLayout(workspace: workspace,
      engine: LayoutEngine(), layoutBuilder: LayoutBuilder())
    _blockFactory = try! BlockFactory(
      jsonPath: "all_test_blocks.json", bundle: NSBundle(forClass: self.dynamicType))
  }

  // MARK: - Tests

  /// The top most block group layout for this block
  func testRootBlockGroupLayout() {
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
      XCTFail("Blocks couldn't be loaded into the workspace")
      return
    }

    // Build layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    // Each block's parent should be a root block
    XCTAssertNotNil(blockStatementOutputNoInput.layout?.parentBlockGroupLayout)
    XCTAssertEqual(blockStatementOutputNoInput.layout?.parentBlockGroupLayout,
      blockStatementOutputNoInput.layout?.rootBlockGroupLayout)

    XCTAssertNotNil(blockInputOutput.layout?.parentBlockGroupLayout)
    XCTAssertEqual(blockInputOutput.layout?.parentBlockGroupLayout,
      blockInputOutput.layout?.rootBlockGroupLayout)

    XCTAssertNotNil(blockStatementMultipleInputValueInput.layout?.parentBlockGroupLayout)
    XCTAssertEqual(blockStatementMultipleInputValueInput.layout?.parentBlockGroupLayout,
      blockStatementMultipleInputValueInput.layout?.rootBlockGroupLayout)

    XCTAssertNotNil(blockStatementNoNext.layout?.parentBlockGroupLayout)
    XCTAssertEqual(blockStatementNoNext.layout?.parentBlockGroupLayout,
      blockStatementNoNext.layout?.rootBlockGroupLayout)

    XCTAssertNotNil(blockStatementStatementInput.layout?.parentBlockGroupLayout)
    XCTAssertEqual(blockStatementStatementInput.layout?.parentBlockGroupLayout,
      blockStatementStatementInput.layout?.rootBlockGroupLayout)

    // Connect all blocks into a giant tree
    do {
      try blockInputOutput.inputs[0].connection?.connectTo(
        blockStatementOutputNoInput.outputConnection)

      try blockStatementMultipleInputValueInput.inputs[1].connection?.connectTo(
        blockInputOutput.outputConnection)

      try blockStatementStatementInput.nextConnection?.connectTo(
        blockStatementNoNext.previousConnection)

      // blockStatementMultipleInputValueInput is the head honcho for all blocks now
      try blockStatementMultipleInputValueInput.nextConnection?.connectTo(
        blockStatementStatementInput.previousConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect blocks together: \(error)")
    }

    // Test that each block now shares the same root block group layout
    let blockGroupLayout = blockStatementMultipleInputValueInput.layout?.parentBlockGroupLayout
    XCTAssertNotNil(blockGroupLayout)
    XCTAssertEqual(blockGroupLayout, blockStatementOutputNoInput.layout?.rootBlockGroupLayout)
    XCTAssertEqual(blockGroupLayout, blockInputOutput.layout?.rootBlockGroupLayout)
    XCTAssertEqual(
      blockGroupLayout, blockStatementMultipleInputValueInput.layout?.rootBlockGroupLayout)
    XCTAssertEqual(blockGroupLayout, blockStatementNoNext.layout?.rootBlockGroupLayout)
    XCTAssertEqual(blockGroupLayout, blockStatementStatementInput.layout?.rootBlockGroupLayout)
  }

  func testZIndex() {
    // Add block to the workspace
    let workspace = _workspaceLayout.workspace
    guard
      let block = try! _blockFactory.addBlock("statement_multiple_value_input", toWorkspace: workspace)
      else
    {
      XCTFail("Blocks couldn't be loaded into the workspace")
      return
    }

    // Build layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    if let blockLayout = block.layout {
      let newZIndex = blockLayout.zIndex + 1 // Increment zIndex by 1
      blockLayout.zIndex = newZIndex

      // Verify zIndex was changed on block layout and all direct block group layouts
      XCTAssertEqual(newZIndex, blockLayout.zIndex)

      for inputLayout in blockLayout.inputLayouts {
        XCTAssertEqual(newZIndex, inputLayout.blockGroupLayout.zIndex)
      }
    } else {
      XCTFail("Block layout wasn't created")
    }
  }

  func testInputLayoutBeforeLayoutEmpty() {
    // Create block with no input's
    let builder = Block.Builder(name: "test")
    let block = try! builder.build()
    try! _workspaceLayout.workspace.addBlockTree(block)

    // Build layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    if let blockLayout = block.layout {
      // Test for an input layout that doesn't exist in blockLayout
      let dummyInput = Input.Builder(type: .Dummy, name: "test").build()
      let dummyInputLayout = InputLayout(input: dummyInput, engine: _workspaceLayout.engine)
      XCTAssertNil(blockLayout.inputLayoutBeforeLayout(dummyInputLayout))
    } else {
      XCTFail("Couldn't build block layout")
    }
  }

  func testInputLayoutBeforeLayoutMultipleValues() {
    // Create block with many inputs
    let builder = Block.Builder(name: "test")
    builder.inputBuilders.append(Input.Builder(type: .Value, name: "input1"))
    builder.inputBuilders.append(Input.Builder(type: .Dummy, name: "input2"))
    builder.inputBuilders.append(Input.Builder(type: .Statement, name: "input3"))
    builder.inputBuilders.append(Input.Builder(type: .Value, name: "input4"))
    let block = try! builder.build()
    try! _workspaceLayout.workspace.addBlockTree(block)

    // Build layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    if let blockLayout = block.layout {
      let inputLayouts = blockLayout.inputLayouts
      XCTAssertEqual(block.inputs.count, inputLayouts.count)

      // Test inputLayoutBeforeLayout() on each inputLayout
      for i in 0 ..< inputLayouts.count {
        let previousInputLayout : InputLayout? = (i > 0 ? inputLayouts[i - 1] : nil)
        let currentInputLayout = inputLayouts[i]
        XCTAssertEqual(previousInputLayout, blockLayout.inputLayoutBeforeLayout(currentInputLayout))
      }

      // Test for an input layout that doesn't exist in blockLayout
      let dummyInput = Input.Builder(type: .Dummy, name: "test").build()
      let dummyInputLayout = InputLayout(input: dummyInput, engine: _workspaceLayout.engine)
      XCTAssertNil(blockLayout.inputLayoutBeforeLayout(dummyInputLayout))
    } else {
      XCTFail("Couldn't build block layout")
    }
  }

  func testInputLayoutAfterLayoutEmpty() {
    // Create block with no inputs
    let builder = Block.Builder(name: "test")
    let block = try! builder.build()
    try! _workspaceLayout.workspace.addBlockTree(block)

    // Build layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    if let blockLayout = block.layout {
      // Test for an input layout that doesn't exist in blockLayout
      let dummyInput = Input.Builder(type: .Dummy, name: "test").build()
      let dummyInputLayout = InputLayout(input: dummyInput, engine: _workspaceLayout.engine)
      XCTAssertNil(blockLayout.inputLayoutAfterLayout(dummyInputLayout))
    } else {
      XCTFail("Couldn't build block layout")
    }
  }

  func testInputLayoutAfterLayoutMultipleValues()  {
    // Create block with many inputs
    let builder = Block.Builder(name: "test")
    builder.inputBuilders.append(Input.Builder(type: .Value, name: "input1"))
    builder.inputBuilders.append(Input.Builder(type: .Dummy, name: "input2"))
    builder.inputBuilders.append(Input.Builder(type: .Statement, name: "input3"))
    builder.inputBuilders.append(Input.Builder(type: .Value, name: "input4"))
    let block = try! builder.build()
    try! _workspaceLayout.workspace.addBlockTree(block)

    // Build layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    if let blockLayout = block.layout {
      let inputLayouts = blockLayout.inputLayouts
      XCTAssertEqual(block.inputs.count, inputLayouts.count)

      // Test inputLayoutAfterLayout() on each inputLayout
      for i in 0 ..< inputLayouts.count {
        let currentInputLayout = inputLayouts[i]
        let nextInputLayout : InputLayout? =
          (i < inputLayouts.count - 1 ? inputLayouts[i + 1] : nil)
        XCTAssertEqual(nextInputLayout, blockLayout.inputLayoutAfterLayout(currentInputLayout))
      }

      // Test for an input layout that doesn't exist in blockLayout
      let dummyInput = Input.Builder(type: .Dummy, name: "test").build()
      let dummyInputLayout = InputLayout(input: dummyInput, engine: _workspaceLayout.engine)
      XCTAssertNil(blockLayout.inputLayoutAfterLayout(dummyInputLayout))
    } else {
      XCTFail("Couldn't build block layout")
    }
  }

  func testConnectValueConnections() {
    // Create blocks with opposite value connections
    let builder1 = Block.Builder(name: "test1")
    builder1.inputBuilders.append(Input.Builder(type: .Value, name: "input1"))
    let builder2 = Block.Builder(name: "test2")
    try! builder2.setOutputConnectionEnabled(true)

    let block1 = try! builder1.build()
    let block2 = try! builder2.build()
    try! _workspaceLayout.workspace.addBlockTree(block1)
    try! _workspaceLayout.workspace.addBlockTree(block2)

    // Build layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    guard
      let blockLayout1 = block1.layout,
      let blockLayout2 = block2.layout else
    {
      XCTFail("No layouts were created for the blocks")
      return
    }

    // Check the structure for blockLayout1 that it has nothing to do with blockLayout2
    XCTAssertNotEqual(blockLayout1.rootBlockGroupLayout, blockLayout2.rootBlockGroupLayout)
    XCTAssertEqual(0, blockLayout1.inputLayouts[0].blockGroupLayout.blockLayouts.count)

    // Connect the blocks
    do {
      try block1.inputs[0].connection?.connectTo(block2.outputConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect the blocks together: \(error)")
    }

    // Check that the block layouts are now connected in the tree
    XCTAssertEqual(blockLayout1.rootBlockGroupLayout, blockLayout2.rootBlockGroupLayout)
    XCTAssertEqual(1, blockLayout1.inputLayouts[0].blockGroupLayout.blockLayouts.count)
    XCTAssertEqual(blockLayout2, blockLayout1.inputLayouts[0].blockGroupLayout.blockLayouts[0])
  }

  func testDisconnectValueConnections() {
    // Create blocks with opposite value connections
    let builder1 = Block.Builder(name: "test1")
    builder1.inputBuilders.append(Input.Builder(type: .Value, name: "input1"))
    let builder2 = Block.Builder(name: "test2")
    try! builder2.setOutputConnectionEnabled(true)

    let block1 = try! builder1.build()
    let block2 = try! builder2.build()
    try! _workspaceLayout.workspace.addBlockTree(block1)
    try! _workspaceLayout.workspace.addBlockTree(block2)

    // Connect the blocks
    do {
      try block1.inputs[0].connection?.connectTo(block2.outputConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect the blocks together: \(error)")
    }

    // Build layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    guard
      let blockLayout1 = block1.layout,
      let blockLayout2 = block2.layout else
    {
      XCTFail("No layouts were created for the blocks")
      return
    }

    // Check that the block layouts are now connected in the tree
    XCTAssertTrue(_workspaceLayout.blockGroupLayouts.contains(blockLayout1.parentBlockGroupLayout!))
    XCTAssertFalse(_workspaceLayout.blockGroupLayouts.contains(blockLayout2.parentBlockGroupLayout!))
    XCTAssertEqual(blockLayout1.rootBlockGroupLayout, blockLayout2.rootBlockGroupLayout)

    XCTAssertEqual(1, blockLayout1.inputLayouts[0].blockGroupLayout.blockLayouts.count)
    XCTAssertEqual(blockLayout2, blockLayout1.inputLayouts[0].blockGroupLayout.blockLayouts[0])

    // Disconnect the blocks
    block1.inputs[0].connection?.disconnect()

    // Check the structure for blockLayout1 that it has nothing to do with blockLayout2
    XCTAssertTrue(_workspaceLayout.blockGroupLayouts.contains(blockLayout1.parentBlockGroupLayout!))
    XCTAssertTrue(_workspaceLayout.blockGroupLayouts.contains(blockLayout2.parentBlockGroupLayout!))
    XCTAssertNotEqual(blockLayout1.rootBlockGroupLayout, blockLayout2.rootBlockGroupLayout)

    XCTAssertEqual(0, blockLayout1.inputLayouts[0].blockGroupLayout.blockLayouts.count)
  }

  func testConnectStatementConnections() {
    // Create blocks with opposite value connections
    let builder1 = Block.Builder(name: "test1")
    try! builder1.setNextConnectionEnabled(true)
    let builder2 = Block.Builder(name: "test2")
    try! builder2.setPreviousConnectionEnabled(true)

    let block1 = try! builder1.build()
    let block2 = try! builder2.build()
    try! _workspaceLayout.workspace.addBlockTree(block1)
    try! _workspaceLayout.workspace.addBlockTree(block2)

    // Build layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    guard
      let blockLayout1 = block1.layout,
      let blockLayout2 = block2.layout else
    {
      XCTFail("No layouts were created for the blocks")
      return
    }

    // Check the structure for blockLayout1 that it has nothing to do with blockLayout2
    XCTAssertNotNil(blockLayout1.parentBlockGroupLayout)
    XCTAssertNotNil(blockLayout2.parentBlockGroupLayout)
    XCTAssertNotEqual(blockLayout1.parentBlockGroupLayout, blockLayout2.parentBlockGroupLayout)

    XCTAssertEqual(1, blockLayout1.parentBlockGroupLayout!.blockLayouts.count)
    XCTAssertEqual(blockLayout1, blockLayout1.parentBlockGroupLayout!.blockLayouts[0])

    XCTAssertEqual(1, blockLayout2.parentBlockGroupLayout!.blockLayouts.count)
    XCTAssertEqual(blockLayout2, blockLayout2.parentBlockGroupLayout!.blockLayouts[0])

    // Connect the blocks
    do {
      try block1.nextConnection!.connectTo(block2.previousConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect the blocks together: \(error)")
    }

    // Check that the block layouts now share the same block group layout
    XCTAssertNotNil(blockLayout1.parentBlockGroupLayout)
    XCTAssertNotNil(blockLayout2.parentBlockGroupLayout)
    XCTAssertEqual(blockLayout1.parentBlockGroupLayout, blockLayout2.parentBlockGroupLayout)

    XCTAssertEqual(2, blockLayout1.parentBlockGroupLayout!.blockLayouts.count)
    XCTAssertEqual(blockLayout1, blockLayout1.parentBlockGroupLayout!.blockLayouts[0])
    XCTAssertEqual(blockLayout2, blockLayout1.parentBlockGroupLayout!.blockLayouts[1])
  }

  func testDisconnectStatementConnections() {
    // Create blocks with opposite value connections
    let builder1 = Block.Builder(name: "test1")
    try! builder1.setNextConnectionEnabled(true)
    let builder2 = Block.Builder(name: "test2")
    try! builder2.setPreviousConnectionEnabled(true)

    let block1 = try! builder1.build()
    let block2 = try! builder2.build()
    try! _workspaceLayout.workspace.addBlockTree(block1)
    try! _workspaceLayout.workspace.addBlockTree(block2)

    // Connect the blocks
    do {
      try block1.nextConnection!.connectTo(block2.previousConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect the blocks together: \(error)")
    }

    // Build layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    guard
      let blockLayout1 = block1.layout,
      let blockLayout2 = block2.layout else
    {
      XCTFail("No layouts were created for the blocks")
      return
    }

    // Check that the block layouts share the same block group layout
    XCTAssertNotNil(blockLayout1.parentBlockGroupLayout)
    XCTAssertNotNil(blockLayout2.parentBlockGroupLayout)
    XCTAssertEqual(blockLayout1.parentBlockGroupLayout, blockLayout2.parentBlockGroupLayout)

    XCTAssertEqual(2, blockLayout1.parentBlockGroupLayout!.blockLayouts.count)
    XCTAssertEqual(blockLayout1, blockLayout1.parentBlockGroupLayout!.blockLayouts[0])
    XCTAssertEqual(blockLayout2, blockLayout1.parentBlockGroupLayout!.blockLayouts[1])

    // Disconnect the blocks
    block2.previousConnection!.disconnect()

    // Check the structure for blockLayout1 that it has nothing to do with blockLayout2
    XCTAssertNotNil(blockLayout1.parentBlockGroupLayout)
    XCTAssertNotNil(blockLayout2.parentBlockGroupLayout)
    XCTAssertNotEqual(blockLayout1.parentBlockGroupLayout, blockLayout2.parentBlockGroupLayout)

    XCTAssertEqual(1, blockLayout1.parentBlockGroupLayout!.blockLayouts.count)
    XCTAssertEqual(blockLayout1, blockLayout1.parentBlockGroupLayout!.blockLayouts[0])

    XCTAssertEqual(1, blockLayout2.parentBlockGroupLayout!.blockLayouts.count)
    XCTAssertEqual(blockLayout2, blockLayout2.parentBlockGroupLayout!.blockLayouts[0])
  }
}
