/*
 * Copyright 2016 Google Inc. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License")
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

class WorkspaceTest: XCTestCase {

  // MARK: - Properties

  var _workspace: Workspace!
  var _blockFactory: BlockFactory!

  // MARK: - Setup

  override func setUp() {
    _workspace = Workspace()
    _blockFactory = BlockFactory()
    BKYAssertDoesNotThrow { try _blockFactory.load(fromJSONPaths: ["all_test_blocks.json"],
                                                   bundle: Bundle(for: type(of: self))) }
  }

  // MARK: - Tests

  func testAddBlockTree_TopLevelShadowBlockFailure() {
    guard let shadowBlock =
      BKYAssertDoesNotThrow({ try BlockBuilder(name: "shadow").makeBlock(shadow: true) }) else
    {
      XCTFail("Could not create block")
      return
    }

    BKYAssertThrow("Cannot add shadow blocks as top-level blocks", errorType: BlocklyError.self) {
      try self._workspace.addBlockTree(shadowBlock)
    }
  }

  func testDeactivateBlockTrees() {
    let builder = BlockBuilder(name: "block")
    BKYAssertDoesNotThrow { try builder.setPreviousConnection(enabled: true) }
    BKYAssertDoesNotThrow { try builder.setNextConnection(enabled: true) }

    guard
      let orphanBlock = BKYAssertDoesNotThrow({ try builder.makeBlock() }),
      let parentBlock = BKYAssertDoesNotThrow({ try builder.makeBlock() }),
      let childBlock = BKYAssertDoesNotThrow({ try builder.makeBlock() }) else
    {
      XCTFail("Could not build blocks")
      return
    }

    // Add blocks to workspace
    BKYAssertDoesNotThrow { () -> Void in
      try parentBlock.nextConnection?.connectTo(childBlock.previousConnection)
      try self._workspace.addBlockTree(orphanBlock)
      try self._workspace.addBlockTree(parentBlock)
    }

    // Deactivate blocks with threshold = 0
    _workspace.deactivateBlockTrees(forGroupsGreaterThan: 0)
    XCTAssertEqual(orphanBlock.disabled, true)
    XCTAssertEqual(orphanBlock.movable, false)
    XCTAssertEqual(parentBlock.disabled, true)
    XCTAssertEqual(parentBlock.movable, false)
    XCTAssertEqual(childBlock.disabled, true)
    XCTAssertEqual(childBlock.movable, false)

    // Deactivate blocks with threshold = 1
    _workspace.deactivateBlockTrees(forGroupsGreaterThan: 1)
    XCTAssertEqual(orphanBlock.disabled, false)
    XCTAssertEqual(orphanBlock.movable, true)
    XCTAssertEqual(parentBlock.disabled, true)
    XCTAssertEqual(parentBlock.movable, false)
    XCTAssertEqual(childBlock.disabled, true)
    XCTAssertEqual(childBlock.movable, false)

    // Deactivate blocks with threshold = 2
    _workspace.deactivateBlockTrees(forGroupsGreaterThan: 2)
    XCTAssertEqual(orphanBlock.disabled, false)
    XCTAssertEqual(orphanBlock.movable, true)
    XCTAssertEqual(parentBlock.disabled, false)
    XCTAssertEqual(parentBlock.movable, true)
    XCTAssertEqual(childBlock.disabled, false)
    XCTAssertEqual(childBlock.movable, true)
  }

  func testReadOnly() {
    guard let block1 = BKYAssertDoesNotThrow({ try BlockBuilder(name: "block1").makeBlock() }),
      let block2 = BKYAssertDoesNotThrow({ try BlockBuilder(name: "block2").makeBlock() }) else
    {
      XCTFail("Could not create blocks")
      return
    }

    // Add non-editable block to workspace when it's not read only.
    // Nothing should happen and the block should remain non-editable.
    _workspace.readOnly = false
    XCTAssertFalse(_workspace.readOnly)
    block1.editable = false
    XCTAssertFalse(block1.editable)
    BKYAssertDoesNotThrow { try self._workspace.addBlockTree(block1) }
    XCTAssertFalse(block1.editable)

    // Change workspace to be read only. This should update all blocks to be editable.
    _workspace.readOnly = true
    XCTAssertTrue(_workspace.readOnly)
    for (_, block) in _workspace.allBlocks {
      XCTAssertFalse(block.editable)
    }

    // Add editable block to workspace when it's read only.
    // It should automatically change the block to be non-editable.
    block2.editable = true
    XCTAssertTrue(block2.editable)
    BKYAssertDoesNotThrow { try self._workspace.addBlockTree(block2) }
    XCTAssertFalse(block2.editable)

    // Change workspace to not read only.
    // Nothing should happen and all blocks should remain non-editable.
    _workspace.readOnly = false
    XCTAssertFalse(_workspace.readOnly)
    for (_, block) in _workspace.allBlocks {
      XCTAssertFalse(block.editable)
    }
  }

  func testMaxBlocks_None() {
    let workspace = Workspace()
    XCTAssertNil(workspace.maxBlocks)
    XCTAssertNil(workspace.remainingCapacity)
  }

  func testMaxBlocks_One() {
    guard
      let block1 = BKYAssertDoesNotThrow({ try BlockBuilder(name: "block1").makeBlock() }),
      let block2 = BKYAssertDoesNotThrow({ try BlockBuilder(name: "block2").makeBlock() }) else
    {
      XCTFail("Could not build blocks")
      return
    }

    let workspace = Workspace(uuid: UUID().uuidString, maxBlocks: 1)
    XCTAssertEqual(workspace.maxBlocks, 1)
    XCTAssertEqual(workspace.remainingCapacity, 1)

    // Add one block
    BKYAssertDoesNotThrow { try workspace.addBlockTree(block1) }
    XCTAssertEqual(workspace.remainingCapacity, 0)

    // Try re-adding the same block, this should pass (since nothing gets added)
    BKYAssertDoesNotThrow { try workspace.addBlockTree(block1) }
    XCTAssertEqual(workspace.remainingCapacity, 0)

    // Try adding another, this should fail
    BKYAssertThrow(errorType: BlocklyError.self) { try workspace.addBlockTree(block2) }
  }

  func testMaxBlocks_Tree() {
    let builder = BlockBuilder(name: "block")
    BKYAssertDoesNotThrow { try builder.setPreviousConnection(enabled: true) }
    BKYAssertDoesNotThrow { try builder.setNextConnection(enabled: true) }

    guard
      let orphanBlock = BKYAssertDoesNotThrow({ try builder.makeBlock() }),
      let parentBlock = BKYAssertDoesNotThrow({ try builder.makeBlock() }),
      let childBlock = BKYAssertDoesNotThrow({ try builder.makeBlock() }) else
    {
      XCTFail("Could not build blocks")
      return
    }

    BKYAssertDoesNotThrow {
      try parentBlock.nextConnection?.connectTo(childBlock.previousConnection)
    }

    let workspace = Workspace(maxBlocks: 2)
    XCTAssertEqual(workspace.maxBlocks, 2)
    XCTAssertEqual(workspace.remainingCapacity, 2)

    // Add one block
    BKYAssertDoesNotThrow { try workspace.addBlockTree(orphanBlock) }
    XCTAssertEqual(workspace.remainingCapacity, 1)

    // Try adding tree of blocks, this should fail
    BKYAssertThrow(errorType: BlocklyError.self) { try workspace.addBlockTree(parentBlock) }

    // Remove existing block
    BKYAssertDoesNotThrow { try workspace.removeBlockTree(orphanBlock) }
    XCTAssertEqual(workspace.remainingCapacity, 2)

    // Add tree of blocks
    BKYAssertDoesNotThrow { try workspace.addBlockTree(parentBlock) }
    XCTAssertEqual(workspace.remainingCapacity, 0)
  }

  func testGetAllVariables_None() {
    let variableBlocks = _workspace.allVariableBlocks(forName: "name")

    XCTAssertEqual(0, variableBlocks.count)
    XCTAssertEqual([], variableBlocks)
  }

  func testGetAllVariables_Zero() {
    let _ = BKYAssertDoesNotThrow {
      try _blockFactory.addBlock(name: "no_connections", toWorkspace: _workspace)
    }
    let variableBlocks = _workspace.allVariableBlocks(forName: "name")

    XCTAssertEqual(0, variableBlocks.count)
  }

  func testGetAllVariables_Some() {
    guard let _ = BKYAssertDoesNotThrow(
        { try _blockFactory.addBlock(name: "no_connections", toWorkspace: _workspace)} ),
      let block1 = BKYAssertDoesNotThrow(
        { try _blockFactory.addBlock(name: "field_variable_block", toWorkspace: _workspace)} ),
      let block2 = BKYAssertDoesNotThrow(
        { try _blockFactory.addBlock(name: "field_variable_block", toWorkspace: _workspace)} ) else
    {
      XCTFail("Could not create blocks")
      return
    }
    let blocks = [block1, block2]
    let variableBlocks = _workspace.allVariableBlocks(forName: "variable1")

    XCTAssertEqual(2, variableBlocks.count)
    for block in blocks {
      XCTAssertTrue(variableBlocks.contains(block))
    }

    let nonMatchingVariableBlocks = _workspace.allVariableBlocks(forName: "notVariable1")

    XCTAssertEqual(0, nonMatchingVariableBlocks.count)
    XCTAssertEqual([], nonMatchingVariableBlocks)
  }
}
