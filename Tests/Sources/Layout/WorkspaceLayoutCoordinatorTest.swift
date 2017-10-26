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

class WorkspaceLayoutCoordinatorTest: XCTestCase {
  var _workspaceLayoutCoordinator: WorkspaceLayoutCoordinator!
  var _blockFactory: BlockFactory!

  // MARK: - Setup

  override func setUp() {
    _blockFactory = BlockFactory()
    BKYAssertDoesNotThrow {
      try _blockFactory.load(fromJSONPaths: ["all_test_blocks.json"],
                             bundle: Bundle(for: type(of: self)))
    }
    _workspaceLayoutCoordinator = BKYAssertDoesNotThrow {
      let workspaceLayout = WorkspaceLayout(workspace: Workspace(), engine: DefaultLayoutEngine())
      let layoutBuilder = LayoutBuilder(layoutFactory: LayoutFactory())
      return try WorkspaceLayoutCoordinator(workspaceLayout: workspaceLayout,
                                            layoutBuilder: layoutBuilder,
                                            connectionManager: ConnectionManager())
    }
  }

  func testMonsterBlockGroupLayout() {
    // Create blocks
    guard
      let blockStatementOutputNoInput = BKYAssertDoesNotThrow({
        try _blockFactory.makeBlock(name: "output_no_input")
      }),
      let blockInputOutput = BKYAssertDoesNotThrow({
        try _blockFactory.makeBlock(name: "simple_input_output")
      }),
      let blockStatementMultipleInputValueInput = BKYAssertDoesNotThrow({
        try _blockFactory.makeBlock(name: "statement_multiple_value_input")
      }),
      let blockStatementNoNext = BKYAssertDoesNotThrow({
        try _blockFactory.makeBlock(name: "statement_no_next")
      }),
      let blockStatementStatementInput = BKYAssertDoesNotThrow({
        try _blockFactory.makeBlock(name: "statement_statement_input")
      }) else
    {
      XCTFail("Could not create blocks")
      return
    }

    // Add blocks to the workspace
    BKYAssertDoesNotThrow {
      try _workspaceLayoutCoordinator.addBlockTree(blockStatementOutputNoInput)
      try _workspaceLayoutCoordinator.addBlockTree(blockInputOutput)
      try _workspaceLayoutCoordinator.addBlockTree(blockStatementMultipleInputValueInput)
      try _workspaceLayoutCoordinator.addBlockTree(blockStatementNoNext)
      try _workspaceLayoutCoordinator.addBlockTree(blockStatementStatementInput)
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
    if let conn1 = blockInputOutput.inputs[0].connection,
      let conn2 = blockStatementOutputNoInput.outputConnection
    {
      BKYAssertDoesNotThrow { try _workspaceLayoutCoordinator.connect(conn1, conn2) }
    } else {
      XCTFail("Could not locate connections")
    }

    if let conn1 = blockStatementMultipleInputValueInput.inputs[1].connection,
      let conn2 = blockInputOutput.outputConnection
    {
      BKYAssertDoesNotThrow { try _workspaceLayoutCoordinator.connect(conn1, conn2) }
    } else {
      XCTFail("Could not locate connections")
    }

    if let conn1 = blockStatementStatementInput.nextConnection,
      let conn2 = blockStatementNoNext.previousConnection
    {
      BKYAssertDoesNotThrow { try _workspaceLayoutCoordinator.connect(conn1, conn2) }
    } else {
      XCTFail("Could not locate connections")
    }

    if let conn1 = blockStatementMultipleInputValueInput.nextConnection,
      let conn2 = blockStatementStatementInput.previousConnection
    {
      BKYAssertDoesNotThrow { try _workspaceLayoutCoordinator.connect(conn1, conn2) }
    } else {
      XCTFail("Could not locate connections")
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

  func testConnectValueConnections() {
    // Create blocks with opposite value connections
    guard let block1 = BKYAssertDoesNotThrow({ () -> Block in
        let builder1 = BlockBuilder(name: "test1")
        builder1.inputBuilders.append(InputBuilder(type: .value, name: "input1"))
        return try builder1.makeBlock()
      }),
      let block2 = BKYAssertDoesNotThrow({ () -> Block in
        let builder2 = BlockBuilder(name: "test2")
        try builder2.setOutputConnection(enabled: true)
        return try builder2.makeBlock()
      }) else
    {
      XCTFail("Could not create blocks")
      return
    }

    BKYAssertDoesNotThrow {
      try _workspaceLayoutCoordinator.addBlockTree(block1)
      try _workspaceLayoutCoordinator.addBlockTree(block2)
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
    guard let conn1 = block1.inputs[0].connection,
      let conn2 = block2.outputConnection else
    {
      XCTFail("Could not locate connections")
      return
    }

    BKYAssertDoesNotThrow { try _workspaceLayoutCoordinator.connect(conn1, conn2) }

    // Check that the block layouts are now connected in the tree
    XCTAssertEqual(blockLayout1.rootBlockGroupLayout, blockLayout2.rootBlockGroupLayout)
    XCTAssertEqual(1, blockLayout1.inputLayouts[0].blockGroupLayout.blockLayouts.count)
    XCTAssertEqual(blockLayout2, blockLayout1.inputLayouts[0].blockGroupLayout.blockLayouts[0])
  }

  func testDisconnectValueConnections() {
    // Create blocks with opposite value connections
    guard let block1 = BKYAssertDoesNotThrow({ () -> Block in
        let builder1 = BlockBuilder(name: "test1")
        builder1.inputBuilders.append(InputBuilder(type: .value, name: "input1"))
        return try builder1.makeBlock()
      }),
      let block2 = BKYAssertDoesNotThrow({ () -> Block in
        let builder2 = BlockBuilder(name: "test2")
        try builder2.setOutputConnection(enabled: true)
        return try builder2.makeBlock()
      }) else
    {
      XCTFail("Could not create blocks")
      return
    }

    BKYAssertDoesNotThrow {
      try _workspaceLayoutCoordinator.addBlockTree(block1)
      try _workspaceLayoutCoordinator.addBlockTree(block2)
    }

    guard
      let blockLayout1 = block1.layout,
      let blockLayout2 = block2.layout else
    {
      XCTFail("No layouts were created for the blocks")
      return
    }

    // Connect the blocks
    guard let conn1 = block1.inputs[0].connection,
      let conn2 = block2.outputConnection else
    {
      XCTFail("Could not locate connections")
      return
    }

    BKYAssertDoesNotThrow { try _workspaceLayoutCoordinator.connect(conn1, conn2) }

    // Check that the block layouts are now connected in the tree
    let workspaceLayout = _workspaceLayoutCoordinator.workspaceLayout
    XCTAssertTrue(workspaceLayout.blockGroupLayouts.contains(blockLayout1.parentBlockGroupLayout!))
    XCTAssertFalse(workspaceLayout.blockGroupLayouts.contains(blockLayout2.parentBlockGroupLayout!))
    XCTAssertEqual(blockLayout1.rootBlockGroupLayout, blockLayout2.rootBlockGroupLayout)

    XCTAssertEqual(1, blockLayout1.inputLayouts[0].blockGroupLayout.blockLayouts.count)
    XCTAssertEqual(blockLayout2, blockLayout1.inputLayouts[0].blockGroupLayout.blockLayouts[0])

    // Disconnect the blocks
    BKYAssertDoesNotThrow { try _workspaceLayoutCoordinator.disconnect(conn1) }

    // Check the structure for blockLayout1 that it has nothing to do with blockLayout2
    XCTAssertTrue(workspaceLayout.blockGroupLayouts.contains(blockLayout1.parentBlockGroupLayout!))
    XCTAssertTrue(workspaceLayout.blockGroupLayouts.contains(blockLayout2.parentBlockGroupLayout!))
    XCTAssertNotEqual(blockLayout1.rootBlockGroupLayout, blockLayout2.rootBlockGroupLayout)

    XCTAssertEqual(0, blockLayout1.inputLayouts[0].blockGroupLayout.blockLayouts.count)
  }

  func testConnectStatementConnections() {
    // Create blocks with opposite value connections
    guard let block1 = BKYAssertDoesNotThrow({ () -> Block in
        let builder1 = BlockBuilder(name: "test1")
      try builder1.setNextConnection(enabled: true)
        return try builder1.makeBlock()
      }),
      let block2 = BKYAssertDoesNotThrow({ () -> Block in
        let builder2 = BlockBuilder(name: "test2")
        try builder2.setPreviousConnection(enabled: true)
        return try builder2.makeBlock()
      }) else
    {
      XCTFail("Could not create blocks")
      return
    }

    BKYAssertDoesNotThrow {
      try _workspaceLayoutCoordinator.addBlockTree(block1)
      try _workspaceLayoutCoordinator.addBlockTree(block2)
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
    guard let conn1 = block1.nextConnection,
      let conn2 = block2.previousConnection else
    {
      XCTFail("Could not locate connections")
      return
    }

    BKYAssertDoesNotThrow { try _workspaceLayoutCoordinator.connect(conn1, conn2) }

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
    guard let block1 = BKYAssertDoesNotThrow({ () -> Block in
      let builder1 = BlockBuilder(name: "test1")
      try builder1.setNextConnection(enabled: true)
      return try builder1.makeBlock()
    }),
      let block2 = BKYAssertDoesNotThrow({ () -> Block in
        let builder2 = BlockBuilder(name: "test2")
        try builder2.setPreviousConnection(enabled: true)
        return try builder2.makeBlock()
      }) else
    {
      XCTFail("Could not create blocks")
      return
    }

    BKYAssertDoesNotThrow {
      try _workspaceLayoutCoordinator.addBlockTree(block1)
      try _workspaceLayoutCoordinator.addBlockTree(block2)
    }

    guard
      let blockLayout1 = block1.layout,
      let blockLayout2 = block2.layout else
    {
      XCTFail("No layouts were created for the blocks")
      return
    }

    // Connect the blocks
    guard let conn1 = block1.nextConnection,
      let conn2 = block2.previousConnection else
    {
      XCTFail("Could not locate connections")
      return
    }

    BKYAssertDoesNotThrow { try _workspaceLayoutCoordinator.connect(conn1, conn2) }

    // Check that the block layouts share the same block group layout
    XCTAssertNotNil(blockLayout1.parentBlockGroupLayout)
    XCTAssertNotNil(blockLayout2.parentBlockGroupLayout)
    XCTAssertEqual(blockLayout1.parentBlockGroupLayout, blockLayout2.parentBlockGroupLayout)

    XCTAssertEqual(2, blockLayout1.parentBlockGroupLayout!.blockLayouts.count)
    XCTAssertEqual(blockLayout1, blockLayout1.parentBlockGroupLayout!.blockLayouts[0])
    XCTAssertEqual(blockLayout2, blockLayout1.parentBlockGroupLayout!.blockLayouts[1])

    // Disconnect the blocks
    BKYAssertDoesNotThrow { try _workspaceLayoutCoordinator.disconnect(conn2) }

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
