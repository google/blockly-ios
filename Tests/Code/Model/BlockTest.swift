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
    _workspace = Workspace(isFlyout: false)
    _blockFactory = try! BlockFactory(
      jsonPath: "all_test_blocks", bundle: NSBundle(forClass: self.dynamicType))
  }

  func testTopLevel() {
    guard
      let blockNoConnections =
      _blockFactory.obtain("no_connections", forWorkspace: _workspace),
      let blockStatementOutputNoInput =
      _blockFactory.obtain("output_no_input", forWorkspace: _workspace),
      let blockInputOutput =
      _blockFactory.obtain("simple_input_output", forWorkspace: _workspace),
      let blockStatementMultipleInputValueInput =
      _blockFactory.obtain("statement_multiple_value_input", forWorkspace: _workspace),
      let blockStatementNoNext =
      _blockFactory.obtain("statement_no_next", forWorkspace: _workspace),
      let blockStatementStatementInput =
      _blockFactory.obtain("statement_statement_input", forWorkspace: _workspace)
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
    guard let block1 = _blockFactory.obtain("statement_no_input", forWorkspace: _workspace),
          let block2 = _blockFactory.obtain("statement_no_input", forWorkspace: _workspace)
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

  func testAllConnectionsForTree() {
    guard
      let blockNoConnections =
        _blockFactory.obtain("no_connections", forWorkspace: _workspace),
      let blockStatementOutputNoInput =
        _blockFactory.obtain("output_no_input", forWorkspace: _workspace),
      let blockInputOutput =
        _blockFactory.obtain("simple_input_output", forWorkspace: _workspace),
      let blockStatementMultipleInputValueInput =
        _blockFactory.obtain("statement_multiple_value_input", forWorkspace: _workspace),
      let blockStatementNoNext =
        _blockFactory.obtain("statement_no_next", forWorkspace: _workspace),
      let blockStatementStatementInput =
        _blockFactory.obtain("statement_statement_input", forWorkspace: _workspace)
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

  func testLastInputValueConnectionInChainSimples() {
    guard
      let block1 = _blockFactory.obtain("simple_input_output", forWorkspace: _workspace),
      let block2 = _blockFactory.obtain("simple_input_output", forWorkspace: _workspace)
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
    guard let block = _blockFactory.obtain("no_connections", forWorkspace: _workspace) else {
      XCTFail("Block couldn't be loaded")
      return
    }

    XCTAssertNil(block.lastInputValueConnectionInChain())
  }

  func testLastInputValueConnectionBranch() {
    guard
      let block1 = _blockFactory.obtain("simple_input_output", forWorkspace: _workspace),
      let block2 = _blockFactory.obtain("simple_input_output", forWorkspace: _workspace),
      let block3 = _blockFactory.obtain("multiple_input_output", forWorkspace: _workspace)
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
      let block1 = _blockFactory.obtain("simple_input_output", forWorkspace: _workspace),
      let block2 = _blockFactory.obtain("simple_input_output", forWorkspace: _workspace),
      let block3 = _blockFactory.obtain("output_no_input", forWorkspace: _workspace)
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
    if let block = _blockFactory.obtain("statement_no_input", forWorkspace: _workspace) {
      XCTAssertNil(block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // One value input.
    if let block = _blockFactory.obtain("statement_value_input", forWorkspace: _workspace) {
      let input = block.inputs.filter({ $0.name == "value" })
      XCTAssertEqual(1, input.count)
      XCTAssertEqual(input[0], block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // Statement input, no value inputs.
    if let block = _blockFactory.obtain("statement_statement_input", forWorkspace: _workspace) {
      XCTAssertNil(block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // Multiple value inputs.
    if let block = _blockFactory.obtain("statement_multiple_value_input", forWorkspace: _workspace)
    {
      XCTAssertNil(block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // Statement input, dummy input and value input.
    if let block = _blockFactory.obtain("controls_repeat_ext", forWorkspace: _workspace) {
      let input = block.inputs.filter({ $0.name == "TIMES" })
      XCTAssertEqual(1, input.count)
      XCTAssertEqual(input[0], block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }
  }
}
