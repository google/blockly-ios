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

class BlockTest: XCTestCase {

  var _workspace: Workspace!
  var _blockFactory: BlockFactory!

  override func setUp() {
    _workspace = Workspace()
    _blockFactory = try! BlockFactory(
      jsonPath: "all_test_blocks.json", bundle: NSBundle(forClass: self.dynamicType))
  }

  func testTopLevel() {
    guard
      let blockNoConnections =
        try! _blockFactory.addBlock("no_connections", toWorkspace: _workspace),
      let blockStatementOutputNoInput =
        try! _blockFactory.addBlock("output_no_input", toWorkspace: _workspace),
      let blockInputOutput =
        try! _blockFactory.addBlock("simple_input_output", toWorkspace: _workspace),
      let blockStatementMultipleInputValueInput =
        try! _blockFactory.addBlock("statement_multiple_value_input", toWorkspace: _workspace),
      let blockStatementNoNext =
        try! _blockFactory.addBlock("statement_no_next", toWorkspace: _workspace),
      let blockStatementStatementInput =
        try! _blockFactory.addBlock("statement_statement_input", toWorkspace: _workspace)
      else
    {
      XCTFail("Blocks couldn't be loaded")
      return
    }

    // All blocks are at the top level when created
    XCTAssertTrue(blockNoConnections.topLevel)
    XCTAssertTrue(blockStatementOutputNoInput.topLevel)
    XCTAssertTrue(blockInputOutput.topLevel)
    XCTAssertTrue(blockStatementMultipleInputValueInput.topLevel)
    XCTAssertTrue(blockStatementNoNext.topLevel)
    XCTAssertTrue(blockStatementStatementInput.topLevel)

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

    // Test again
    XCTAssertTrue(blockNoConnections.topLevel)
    XCTAssertTrue(blockStatementMultipleInputValueInput.topLevel)
    XCTAssertTrue(blockStatementStatementInput.topLevel)

    XCTAssertFalse(blockStatementOutputNoInput.topLevel)
    XCTAssertFalse(blockInputOutput.topLevel)
    XCTAssertFalse(blockStatementNoNext.topLevel)
  }

  func testLastBlockInChain() {
    guard let block1 = try! _blockFactory.addBlock("statement_no_input", toWorkspace: _workspace),
          let block2 = try! _blockFactory.addBlock("statement_no_input", toWorkspace: _workspace)
      else
    {
      XCTFail("Blocks couldn't be loaded")
      return
    }

    // One block
    XCTAssertEqual(block1, block1.lastBlockInChain())
    XCTAssertEqual(block2, block2.lastBlockInChain())

    // Two blocks.
    XCTAssertNotNil(block1.nextConnection)
    XCTAssertNotNil(block2.previousConnection)

    do {
      try block1.nextConnection?.connectTo(block2.previousConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect blocks together: \(error)")
    }
    XCTAssertEqual(block2, block1.lastBlockInChain())
    XCTAssertEqual(block2, block2.lastBlockInChain())
  }

  func testAllBlocksForTree() {
    guard
      let blockStatementOutputNoInput =
        try! _blockFactory.addBlock("output_no_input", toWorkspace: _workspace),
      let blockInputOutput =
        try! _blockFactory.addBlock("simple_input_output", toWorkspace: _workspace),
      let blockStatementMultipleInputValueInput =
        try! _blockFactory.addBlock("statement_multiple_value_input", toWorkspace: _workspace),
      let blockStatementNoNext =
        try! _blockFactory.addBlock("statement_no_next", toWorkspace: _workspace),
      let blockStatementStatementInput =
        try! _blockFactory.addBlock("statement_statement_input", toWorkspace: _workspace)
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

    // Make sure that all blocks exist in the root
    let allBlocks = blockStatementStatementInput.allBlocksForTree()
    XCTAssertEqual(5, allBlocks.count)
    XCTAssertTrue(allBlocks.contains(blockStatementOutputNoInput))
    XCTAssertTrue(allBlocks.contains(blockInputOutput))
    XCTAssertTrue(allBlocks.contains(blockStatementMultipleInputValueInput))
    XCTAssertTrue(allBlocks.contains(blockStatementNoNext))
    XCTAssertTrue(allBlocks.contains(blockStatementStatementInput))
  }

  func testAllConnectionsForTree() {
    guard
      let blockNoConnections =
        try! _blockFactory.addBlock("no_connections", toWorkspace: _workspace),
      let blockStatementOutputNoInput =
        try! _blockFactory.addBlock("output_no_input", toWorkspace: _workspace),
      let blockInputOutput =
        try! _blockFactory.addBlock("simple_input_output", toWorkspace: _workspace),
      let blockStatementMultipleInputValueInput =
        try! _blockFactory.addBlock("statement_multiple_value_input", toWorkspace: _workspace),
      let blockStatementNoNext =
        try! _blockFactory.addBlock("statement_no_next", toWorkspace: _workspace),
      let blockStatementStatementInput =
        try! _blockFactory.addBlock("statement_statement_input", toWorkspace: _workspace)
      else
    {
      XCTFail("Blocks couldn't be loaded")
      return
    }

    // Test each block individually
    let noConnectionsCount = 0
    XCTAssertEqual(noConnectionsCount, blockNoConnections.allConnectionsForTree().count)

    let statementOutputNoInputCount = 1
    XCTAssertEqual(
      statementOutputNoInputCount, blockStatementOutputNoInput.allConnectionsForTree().count)

    var inputOutputCount = 2
    XCTAssertEqual(inputOutputCount, blockInputOutput.allConnectionsForTree().count)

    var statementMultipleInputValueInputCount = 4
    XCTAssertEqual(statementMultipleInputValueInputCount,
      blockStatementMultipleInputValueInput.allConnectionsForTree().count)

    let statementNoNextCount = 1
    XCTAssertEqual(statementNoNextCount, blockStatementNoNext.allConnectionsForTree().count)

    var statementStatementInputCount = 3
    XCTAssertEqual(
      statementStatementInputCount, blockStatementStatementInput.allConnectionsForTree().count)

    // Connect into a megazord block and test against each node of tree
    do {
      try blockInputOutput.inputs[0].connection?.connectTo(
        blockStatementOutputNoInput.outputConnection)
      inputOutputCount += statementOutputNoInputCount
      XCTAssertEqual(inputOutputCount, blockInputOutput.allConnectionsForTree().count)

      try blockStatementMultipleInputValueInput.inputs[0].connection?.connectTo(
        blockInputOutput.outputConnection)
      statementMultipleInputValueInputCount += inputOutputCount
      XCTAssertEqual(statementMultipleInputValueInputCount,
        blockStatementMultipleInputValueInput.allConnectionsForTree().count)

      try blockStatementStatementInput.inputs[0].connection?.connectTo(
        blockStatementNoNext.previousConnection)
      statementStatementInputCount += statementNoNextCount
      XCTAssertEqual(
        statementStatementInputCount, blockStatementStatementInput.allConnectionsForTree().count)

      try blockStatementStatementInput.nextConnection?.connectTo(
        blockStatementMultipleInputValueInput.previousConnection)
      statementStatementInputCount += statementMultipleInputValueInputCount
      XCTAssertEqual(
        statementStatementInputCount, blockStatementStatementInput.allConnectionsForTree().count)
    } catch let error as NSError {
      XCTFail("Couldn't connect blocks together: \(error)")
    }
  }

  func testDeepCopy() {
    guard
      let blockStatementOutputNoInput =
        try! _blockFactory.addBlock("output_no_input", toWorkspace: _workspace),
      let blockInputOutput =
        try! _blockFactory.addBlock("simple_input_output", toWorkspace: _workspace),
      let blockStatementMultipleInputValueInput =
        try! _blockFactory.addBlock("statement_multiple_value_input", toWorkspace: _workspace),
      let blockStatementNoNext =
        try! _blockFactory.addBlock("statement_no_next", toWorkspace: _workspace),
      let blockStatementStatementInput =
        try! _blockFactory.addBlock("statement_statement_input", toWorkspace: _workspace)
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
      let copyResult = try blockStatementStatementInput.deepCopy()
      XCTAssertEqual(5, copyResult.allBlocks.count)
      assertSimilarBlockTrees(copyResult.rootBlock, blockStatementStatementInput)
    } catch let error as NSError {
      XCTFail("Couldn't deep copy block: \(error)")
    }
  }

  func testLastInputValueConnectionInChainSimples() {
    guard
      let block1 = try! _blockFactory.addBlock("simple_input_output", toWorkspace: _workspace),
      let block2 = try! _blockFactory.addBlock("simple_input_output", toWorkspace: _workspace)
      else
    {
        XCTFail("Blocks couldn't be loaded")
        return
    }

    do {
      XCTAssertNotNil(block1.inputs[0].connection)
      XCTAssertNotNil(block2.outputConnection)
      try block1.inputs[0].connection?.connectTo(block2.outputConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect blocks together: \(error)")
    }

    XCTAssertEqual(block2.inputs[0].connection, block1.lastInputValueConnectionInChain())
    XCTAssertEqual(block2.inputs[0].connection, block2.lastInputValueConnectionInChain())
  }

  func testLastInputValueConnectionEmpty() {
    guard let block = try! _blockFactory.addBlock("no_connections", toWorkspace: _workspace) else {
      XCTFail("Block couldn't be loaded")
      return
    }

    XCTAssertNil(block.lastInputValueConnectionInChain())
  }

  func testLastInputValueConnectionBranch() {
    guard
      let block1 = try! _blockFactory.addBlock("simple_input_output", toWorkspace: _workspace),
      let block2 = try! _blockFactory.addBlock("simple_input_output", toWorkspace: _workspace),
      let block3 = try! _blockFactory.addBlock("multiple_input_output", toWorkspace: _workspace)
      else
    {
      XCTFail("Blocks couldn't be loaded")
      return
    }

    do {
      XCTAssertNotNil(block1.inputs[0].connection)
      XCTAssertNotNil(block2.outputConnection)
      try block1.inputs[0].connection?.connectTo(block2.outputConnection)

      XCTAssertNotNil(block2.inputs[0].connection)
      XCTAssertNotNil(block3.outputConnection)
      try block2.inputs[0].connection?.connectTo(block3.outputConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect blocks together: \(error)")
    }

    XCTAssertNil(block1.lastInputValueConnectionInChain())
    XCTAssertNil(block2.lastInputValueConnectionInChain())
    XCTAssertNil(block3.lastInputValueConnectionInChain())
  }

  func testLastInputValueConnectionNoInput() {
    guard
      let block1 = try! _blockFactory.addBlock("simple_input_output", toWorkspace: _workspace),
      let block2 = try! _blockFactory.addBlock("simple_input_output", toWorkspace: _workspace),
      let block3 = try! _blockFactory.addBlock("output_no_input", toWorkspace: _workspace)
      else
    {
      XCTFail("Blocks couldn't be loaded")
      return
    }

    do {
      XCTAssertNotNil(block1.inputs[0].connection)
      XCTAssertNotNil(block2.outputConnection)
      try block1.inputs[0].connection?.connectTo(block2.outputConnection)

      XCTAssertNotNil(block2.inputs[0].connection)
      XCTAssertNotNil(block3.outputConnection)
      try block2.inputs[0].connection?.connectTo(block3.outputConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect blocks together: \(error)")
    }

    XCTAssertNil(block1.lastInputValueConnectionInChain())
    XCTAssertNil(block2.lastInputValueConnectionInChain())
    XCTAssertNil(block3.lastInputValueConnectionInChain())
  }

  func testOnlyValueInput() {
    // No value input
    if let block = try! _blockFactory.addBlock("statement_no_input", toWorkspace: _workspace) {
      XCTAssertNil(block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // One value input.
    if let block = try! _blockFactory.addBlock("statement_value_input", toWorkspace: _workspace) {
      let input = block.inputs.filter({ $0.name == "value" })
      XCTAssertEqual(1, input.count)
      XCTAssertEqual(input[0], block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // Statement input, no value inputs.
    if let block = try! _blockFactory.addBlock("statement_statement_input", toWorkspace: _workspace)
    {
      XCTAssertNil(block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // Multiple value inputs.
    if let block = try! _blockFactory.addBlock("statement_multiple_value_input",
      toWorkspace: _workspace) {
      XCTAssertNil(block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // Statement input, dummy input and value input.
    if let block = try! _blockFactory.addBlock("controls_repeat_ext", toWorkspace: _workspace) {
      let input = block.inputs.filter({ $0.name == "TIMES" })
      XCTAssertEqual(1, input.count)
      XCTAssertEqual(input[0], block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }
  }

  // MARK: - Helper methods

  /**
   Compares two trees of blocks and asserts that their tree of connections is the same.
   */
  func assertSimilarBlockTrees(block1: Block, _ block2: Block) {
    // Test existence of all connections and follow next/input connections
    XCTAssertTrue(
      (block1.previousConnection == nil && block2.previousConnection == nil) ||
      (block1.previousConnection != nil && block2.previousConnection != nil))

    XCTAssertTrue(
      (block1.outputConnection == nil && block2.outputConnection == nil) ||
      (block1.outputConnection != nil && block2.outputConnection != nil))

    XCTAssertTrue(
      (block1.nextConnection == nil && block2.nextConnection == nil) ||
      (block1.nextConnection != nil && block2.nextConnection != nil))

    XCTAssertTrue(
      (block1.nextBlock == nil && block2.nextBlock == nil) ||
      (block1.nextBlock != nil && block2.nextBlock != nil))

    if block1.nextBlock != nil && block2.nextBlock != nil {
      assertSimilarBlockTrees(block1.nextBlock!, block2.nextBlock!)
    }

    XCTAssertEqual(block1.inputs.count, block2.inputs.count)
    for i in 0 ..< block1.inputs.count {
      XCTAssertTrue(
        (block1.inputs[i].connection == nil && block2.inputs[i].connection == nil) ||
        (block1.inputs[i].connection != nil && block2.inputs[i].connection != nil))

      XCTAssertTrue(
        (block1.inputs[i].connectedBlock == nil && block2.inputs[i].connectedBlock == nil) ||
        (block1.inputs[i].connectedBlock != nil && block2.inputs[i].connectedBlock != nil))

      if block1.inputs[i].connectedBlock != nil && block2.inputs[i].connectedBlock != nil {
        assertSimilarBlockTrees(block1.inputs[i].connectedBlock!, block2.inputs[i].connectedBlock!)
      }
    }
  }
}
