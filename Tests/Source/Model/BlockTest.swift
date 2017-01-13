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
    _blockFactory = BlockFactory()
    BKYAssertDoesNotThrow {
      try _blockFactory.load(fromJSONPaths: ["all_test_blocks.json"],
                             bundle: Bundle(for: type(of: self)))
    }
  }

  func testTopLevel() {
    guard
      let blockNoConnections =
        try! _blockFactory.addBlock(name: "no_connections", toWorkspace: _workspace),
      let blockStatementOutputNoInput =
        try! _blockFactory.addBlock(name: "output_no_input", toWorkspace: _workspace),
      let blockInputOutput =
        try! _blockFactory.addBlock(name: "simple_input_output", toWorkspace: _workspace),
      let blockStatementMultipleInputValueInput =
        try! _blockFactory.addBlock(name: "statement_multiple_value_input",
        toWorkspace: _workspace),
      let blockStatementNoNext =
        try! _blockFactory.addBlock(name: "statement_no_next", toWorkspace: _workspace),
      let blockStatementStatementInput =
        try! _blockFactory.addBlock(name: "statement_statement_input", toWorkspace: _workspace)
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
    } catch let error {
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
    guard let block1 = try! _blockFactory.addBlock(name: "statement_no_input",
                                                   toWorkspace: _workspace),
          let block2 = try! _blockFactory.addBlock(name: "statement_no_input",
                                                   toWorkspace: _workspace)
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
    } catch let error {
      XCTFail("Couldn't connect blocks together: \(error)")
    }
    XCTAssertEqual(block2, block1.lastBlockInChain())
    XCTAssertEqual(block2, block2.lastBlockInChain())
  }

  func testAllBlocksForTree() {
    guard
      let blockStatementOutputNoInput =
        try! _blockFactory.addBlock(name: "output_no_input", toWorkspace: _workspace),
      let blockInputOutput =
        try! _blockFactory.addBlock(name: "simple_input_output", toWorkspace: _workspace),
      let blockStatementMultipleInputValueInput =
        try! _blockFactory.addBlock(name: "statement_multiple_value_input",
        toWorkspace: _workspace),
      let blockStatementNoNext =
        try! _blockFactory.addBlock(name: "statement_no_next", toWorkspace: _workspace),
      let blockStatementStatementInput =
        try! _blockFactory.addBlock(name: "statement_statement_input", toWorkspace: _workspace)
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
    } catch let error {
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
        try! _blockFactory.addBlock(name: "no_connections", toWorkspace: _workspace),
      let blockStatementOutputNoInput =
        try! _blockFactory.addBlock(name: "output_no_input", toWorkspace: _workspace),
      let blockInputOutput =
        try! _blockFactory.addBlock(name: "simple_input_output", toWorkspace: _workspace),
      let blockStatementMultipleInputValueInput =
        try! _blockFactory.addBlock(name: "statement_multiple_value_input", toWorkspace:
        _workspace),
      let blockStatementNoNext =
        try! _blockFactory.addBlock(name: "statement_no_next", toWorkspace: _workspace),
      let blockStatementStatementInput =
        try! _blockFactory.addBlock(name: "statement_statement_input", toWorkspace: _workspace)
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
    } catch let error {
      XCTFail("Couldn't connect blocks together: \(error)")
    }
  }

  func testDeepCopy() {
    guard
      let blockStatementOutputNoInput =
        try! _blockFactory.addBlock(name: "output_no_input", toWorkspace: _workspace),
      let blockInputOutput =
        try! _blockFactory.addBlock(name: "simple_input_output", toWorkspace: _workspace),
      let blockStatementMultipleInputValueInput =
        try! _blockFactory.addBlock(name: "statement_multiple_value_input", toWorkspace: _workspace),
      let blockStatementNoNext =
        try! _blockFactory.addBlock(name: "statement_no_next", toWorkspace: _workspace),
      let blockStatementStatementInput =
        try! _blockFactory.addBlock(name: "statement_statement_input", toWorkspace: _workspace)
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
    } catch let error {
      XCTFail("Couldn't connect blocks together: \(error)")
    }

    do {
      let copyResult = try blockStatementStatementInput.deepCopy()
      XCTAssertEqual(5, copyResult.allBlocks.count)
      assertSimilarBlockTrees(copyResult.rootBlock, blockStatementStatementInput)
    } catch let error {
      XCTFail("Couldn't deep copy block: \(error)")
    }
  }

  func testDeepCopy_ShadowBlock() {
    guard
      let root = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "statement_value_input", shadow: false, uuid: "1")
      }),
      let output = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "simple_input_output", shadow: false, uuid: "2")
      }),
      let outputShadow = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "simple_input_output", shadow: true, uuid: "3")
      }),
      let next = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "statement_no_next", shadow: false, uuid: "2")
      }),
      let shadowNext = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "statement_no_next", shadow: true, uuid: "2")
      }) else
    {
      XCTFail("Couldn't initialize blocks")
      return
    }

    BKYAssertDoesNotThrow {
      try root.onlyValueInput()?.connection?.connectTo(output.outputConnection)
    }
    BKYAssertDoesNotThrow {
      try root.onlyValueInput()?.connection?.connectShadowTo(outputShadow.outputConnection)
    }
    BKYAssertDoesNotThrow {
      try root.nextConnection?.connectTo(next.previousConnection)
    }
    BKYAssertDoesNotThrow {
      try root.nextConnection?.connectShadowTo(shadowNext.previousConnection)
    }

    guard let copy = BKYAssertDoesNotThrow({ try root.deepCopy() }) else {
      XCTFail("Couldn't deep copy block")
      return
    }
    assertSimilarBlockTrees(copy.rootBlock, root)
  }

  func testDeepCopy_DoesNotCopyUUID() {
    let original = BKYAssertDoesNotThrow { try BlockBuilder(name: "test").makeBlock() }
    let copy = BKYAssertDoesNotThrow { try original?.deepCopy() }

    XCTAssertNotNil(original)
    XCTAssertNotNil(copy)
    XCTAssertNotEqual(original?.uuid, copy?.rootBlock.uuid)
  }

  func testEditable() {
    let inputBuilder = InputBuilder(type: .dummy, name: "dummy")
    inputBuilder.appendField(FieldLabel(name: "label", text: "label"))
    let blockBuilder = BlockBuilder(name: "test")
    blockBuilder.editable = true
    blockBuilder.inputBuilders = [inputBuilder]

    guard let block = BKYAssertDoesNotThrow({ try blockBuilder.makeBlock() }) else {
      XCTFail("Couldn't create block")
      return
    }

    XCTAssertTrue(block.editable)
    let allFields = block.inputs.flatMap { $0.fields }
    for field in allFields {
      XCTAssertTrue(field.editable)
    }

    block.editable = false

    XCTAssertFalse(block.editable)
    for field in allFields {
      XCTAssertFalse(field.editable)
    }
  }

  func testEditable_LoadAsReadOnly() {
    let inputBuilder = InputBuilder(type: .dummy, name: "dummy")
    inputBuilder.appendField(FieldLabel(name: "label", text: "label"))
    let blockBuilder = BlockBuilder(name: "test")
    blockBuilder.editable = false
    blockBuilder.inputBuilders = [inputBuilder]

    guard let block = BKYAssertDoesNotThrow({ try blockBuilder.makeBlock() }) else {
      XCTFail("Couldn't create block")
      return
    }

    XCTAssertFalse(block.editable)
    let allFields = block.inputs.flatMap { $0.fields }
    for field in allFields {
      XCTAssertFalse(field.editable)
    }
  }

  func testLastInputValueConnectionInChainSimples() {
    guard
      let block1 = try! _blockFactory.addBlock(name: "simple_input_output",
                                               toWorkspace: _workspace),
      let block2 = try! _blockFactory.addBlock(name: "simple_input_output", toWorkspace: _workspace)
      else
    {
        XCTFail("Blocks couldn't be loaded")
        return
    }

    do {
      XCTAssertNotNil(block1.inputs[0].connection)
      XCTAssertNotNil(block2.outputConnection)
      try block1.inputs[0].connection?.connectTo(block2.outputConnection)
    } catch let error {
      XCTFail("Couldn't connect blocks together: \(error)")
    }

    XCTAssertEqual(block2.inputs[0].connection, block1.lastInputValueConnectionInChain())
    XCTAssertEqual(block2.inputs[0].connection, block2.lastInputValueConnectionInChain())
  }

  func testLastInputValueConnectionEmpty() {
    guard let block = try! _blockFactory.addBlock(name: "no_connections",
                                                  toWorkspace: _workspace) else {
      XCTFail("Block couldn't be loaded")
      return
    }

    XCTAssertNil(block.lastInputValueConnectionInChain())
  }

  func testLastInputValueConnectionBranch() {
    guard
      let block1 = try! _blockFactory.addBlock(name: "simple_input_output",
                                               toWorkspace: _workspace),
      let block2 = try! _blockFactory.addBlock(name: "simple_input_output",
                                               toWorkspace: _workspace),
      let block3 = try! _blockFactory.addBlock(name: "multiple_input_output",
                                               toWorkspace: _workspace)
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
    } catch let error {
      XCTFail("Couldn't connect blocks together: \(error)")
    }

    XCTAssertNil(block1.lastInputValueConnectionInChain())
    XCTAssertNil(block2.lastInputValueConnectionInChain())
    XCTAssertNil(block3.lastInputValueConnectionInChain())
  }

  func testLastInputValueConnectionNoInput() {
    guard
      let block1 = try! _blockFactory.addBlock(name: "simple_input_output", toWorkspace: _workspace),
      let block2 = try! _blockFactory.addBlock(name: "simple_input_output", toWorkspace: _workspace),
      let block3 = try! _blockFactory.addBlock(name: "output_no_input", toWorkspace: _workspace)
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
    } catch let error {
      XCTFail("Couldn't connect blocks together: \(error)")
    }

    XCTAssertNil(block1.lastInputValueConnectionInChain())
    XCTAssertNil(block2.lastInputValueConnectionInChain())
    XCTAssertNil(block3.lastInputValueConnectionInChain())
  }

  func testOnlyValueInput() {
    // No value input
    if let block = try! _blockFactory.addBlock(name: "statement_no_input",
                                               toWorkspace: _workspace) {
      XCTAssertNil(block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // One value input.
    if let block = try! _blockFactory.addBlock(name: "statement_value_input",
                                               toWorkspace: _workspace) {
      let input = block.inputs.filter({ $0.name == "value" })
      XCTAssertEqual(1, input.count)
      XCTAssertEqual(input[0], block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // Statement input, no value inputs.
    if let block = try! _blockFactory.addBlock(name: "statement_statement_input",
                                               toWorkspace: _workspace)
    {
      XCTAssertNil(block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // Multiple value inputs.
    if let block = try! _blockFactory.addBlock(name: "statement_multiple_value_input",
      toWorkspace: _workspace) {
      XCTAssertNil(block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }

    // Statement input, dummy input and value input.
    if let block = try! _blockFactory.addBlock(name: "controls_repeat_ext",
                                               toWorkspace: _workspace) {
      let input = block.inputs.filter({ $0.name == "TIMES" })
      XCTAssertEqual(1, input.count)
      XCTAssertEqual(input[0], block.onlyValueInput())
    } else {
      XCTFail("Couldn't load block")
    }
  }

  func testInsertInput() {
    // Create block with one input
    let blockBuilder = BlockBuilder(name: "test")
    blockBuilder.inputBuilders.append(InputBuilder(type: .statement, name: "statement"))
    guard let block = BKYAssertDoesNotThrow({ try blockBuilder.makeBlock() }) else {
      XCTFail("Couldn't build block")
      return
    }

    XCTAssertEqual(1, block.inputs.count)
    XCTAssertEqual(1, block.directConnections.count)

    // Insert new input
    let inputBuilder = InputBuilder(type: .value, name: "value")
    let newInput = inputBuilder.makeInput()
    block.insertInput(newInput, at: 0)

    XCTAssertEqual(2, block.inputs.count)
    XCTAssertEqual(newInput, block.inputs[0])
    XCTAssertEqual(2, block.directConnections.count)
  }

  func testAppendInput() {
    // Create block with one input
    let blockBuilder = BlockBuilder(name: "test")
    blockBuilder.inputBuilders.append(InputBuilder(type: .statement, name: "statement"))
    guard let block = BKYAssertDoesNotThrow({ try blockBuilder.makeBlock() }) else {
      XCTFail("Couldn't build block")
      return
    }

    XCTAssertEqual(1, block.inputs.count)
    XCTAssertEqual(1, block.directConnections.count)

    // Append new input
    let inputBuilder = InputBuilder(type: .value, name: "value")
    let newInput = inputBuilder.makeInput()

    block.appendInput(newInput)

    XCTAssertEqual(2, block.inputs.count)
    XCTAssertEqual(newInput, block.inputs[1])
    XCTAssertEqual(2, block.directConnections.count)
  }

  func testRemoveInput() {
    // Create "main" block with two inputs, and 3 child blocks (2 non-shadow, 1 shadow)
    let mainBlockBuilder = BlockBuilder(name: "main")
    mainBlockBuilder.inputBuilders.append(InputBuilder(type: .value, name: "value"))
    mainBlockBuilder.inputBuilders.append(InputBuilder(type: .statement, name: "statement"))
    let outputBlockBuilder = BlockBuilder(name: "output")
    BKYAssertDoesNotThrow { try outputBlockBuilder.setOutputConnection(enabled: true) }
    let previousBlockBuilder = BlockBuilder(name: "previous")
    BKYAssertDoesNotThrow { try previousBlockBuilder.setPreviousConnection(enabled: true) }

    guard
      let mainBlock = BKYAssertDoesNotThrow({ try mainBlockBuilder.makeBlock() }),
      let outputBlock = BKYAssertDoesNotThrow({ try outputBlockBuilder.makeBlock() }),
      let outputConnection = outputBlock.outputConnection,
      let shadowOutputBlock =
        BKYAssertDoesNotThrow({ try outputBlockBuilder.makeBlock(shadow: true) }),
      let shadowOutputConnection = shadowOutputBlock.outputConnection,
      let previousBlock = BKYAssertDoesNotThrow({ try previousBlockBuilder.makeBlock() }),
      let previousConnection = previousBlock.previousConnection else
    {
      XCTFail("Couldn't build blocks and/or connections")
      return
    }

    // Connect child blocks to "main" block
    BKYAssertDoesNotThrow {
      try mainBlock.inputs[0].connection?.connectTo(outputConnection)
      try mainBlock.inputs[0].connection?.connectShadowTo(shadowOutputConnection)
      try mainBlock.inputs[1].connection?.connectTo(previousConnection)
    }

    XCTAssertEqual(2, mainBlock.inputs.count)
    XCTAssertEqual(2, mainBlock.directConnections.count)
    XCTAssertTrue(outputConnection.connected)
    XCTAssertEqual(outputConnection, mainBlock.inputs[0].connection?.targetConnection)
    XCTAssertTrue(shadowOutputConnection.shadowConnected)
    XCTAssertEqual(shadowOutputConnection, mainBlock.inputs[0].connection?.shadowConnection)
    XCTAssertTrue(previousConnection.connected)
    XCTAssertEqual(previousConnection, mainBlock.inputs[1].connection?.targetConnection)

    // Try to remove first input. This should throw an error since we can't remove inputs with
    // connected blocks.
    let valueInput = mainBlock.inputs[0]
    BKYAssertThrow(errorType: BlocklyError.self) { try mainBlock.removeInput(valueInput) }

    // Disconnect first input's connection and try removing it again. This should still throw an
    // error, since it's still connected to a shadow block.
    valueInput.connection?.disconnect()
    BKYAssertThrow(errorType: BlocklyError.self) { try mainBlock.removeInput(valueInput) }

    // Disconnect input's shadow connection and try removing it again. This should succeed.
    valueInput.connection?.disconnectShadow()
    BKYAssertDoesNotThrow { try mainBlock.removeInput(valueInput) }

    XCTAssertEqual(1, mainBlock.inputs.count)
    XCTAssertEqual(1, mainBlock.directConnections.count)
    XCTAssertNotEqual(mainBlock.inputs[0], valueInput)
    XCTAssertNil(valueInput.connectedBlock)
    XCTAssertFalse(outputConnection.connected)
    XCTAssertNil(valueInput.connectedShadowBlock)
    XCTAssertFalse(shadowOutputConnection.connected)

    // Try to remove second input. This should throw an error since we can't remove inputs with
    // connected blocks.
    let statementInput = mainBlock.inputs[0]
    BKYAssertThrow(errorType: BlocklyError.self) { try mainBlock.removeInput(statementInput) }

    // Disconnect second input's connection and try removing it again. This should succeed.
    statementInput.connection?.disconnect()
    BKYAssertDoesNotThrow { try mainBlock.removeInput(statementInput) }

    XCTAssertEqual(0, mainBlock.inputs.count)
    XCTAssertEqual(0, mainBlock.directConnections.count)
    XCTAssertNil(statementInput.connectedBlock)
    XCTAssertFalse(previousConnection.connected)
  }

  func testMutatorOnCreation() {
    // Create mutator that simply creates an input on the block
    let dummyMutator = DummyMutator()
    dummyMutator.id = ""
    dummyMutator.mutationClosure = { dummyMutator in
      // Signal the mutator has been applied
      dummyMutator.id = "mutator applied"
    }

    // Create block with the mutator
    let mainBlockBuilder = BlockBuilder(name: "main")
    mainBlockBuilder.mutator = dummyMutator

    guard let block = BKYAssertDoesNotThrow({ try mainBlockBuilder.makeBlock() }) else {
      XCTFail("Could not build block")
      return
    }

    // Check to see that the mutator was applied on creation
    XCTAssertNotNil(block.mutator)
    XCTAssertEqual("mutator applied", (block.mutator as? DummyMutator)?.id)
  }

  // MARK: - Helper methods

  /**
   Compares two trees of blocks and asserts that their tree of connections is the same.
   */
  func assertSimilarBlockTrees(_ block1: Block, _ block2: Block) {
    XCTAssertEqual(block1.shadow, block2.shadow)

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

    if let nextBlock1 = block1.nextBlock,
      let nextBlock2 = block2.nextBlock
    {
      assertSimilarBlockTrees(nextBlock1, nextBlock2)
    }

    XCTAssertTrue(
      (block1.nextShadowBlock == nil && block2.nextShadowBlock == nil) ||
      (block1.nextShadowBlock != nil && block2.nextShadowBlock != nil))

    if let nextShadowBlock1 = block1.nextShadowBlock,
      let nextShadowBlock2 = block2.nextShadowBlock
    {
      assertSimilarBlockTrees(nextShadowBlock1, nextShadowBlock2)
    }

    XCTAssertEqual(block1.inputs.count, block2.inputs.count)

    var i = 0
    while i < block1.inputs.count && i < block2.inputs.count {
      let input1 = block1.inputs[i]
      let input2 = block2.inputs[i]

      XCTAssertTrue(
        (input1.connection == nil && input2.connection == nil) ||
        (input1.connection != nil && input2.connection != nil))

      // Check connected block trees
      XCTAssertTrue(
        (input1.connectedBlock == nil && input2.connectedBlock == nil) ||
        (input1.connectedBlock != nil && input2.connectedBlock != nil))

      if let connectedBlock1 = input1.connectedBlock,
        let connectedBlock2 = input2.connectedBlock
      {
        assertSimilarBlockTrees(connectedBlock1, connectedBlock2)
      }

      // Check connected shadow block trees
      XCTAssertTrue(
        (input1.connectedShadowBlock == nil && input2.connectedShadowBlock == nil) ||
        (input1.connectedShadowBlock != nil && input2.connectedShadowBlock != nil))

      if let connectedShadowBlock1 = input1.connectedShadowBlock,
        let connectedShadowBlock2 = input2.connectedShadowBlock
      {
        assertSimilarBlockTrees(connectedShadowBlock1, connectedShadowBlock2)
      }
      
      i += 1
    }
  }
}
