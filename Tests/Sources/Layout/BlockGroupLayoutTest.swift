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

class BlockGroupLayoutTest: XCTestCase {

  var _workspaceLayout: WorkspaceLayout!
  var _blockFactory: BlockFactory!
  var _layoutFactory: LayoutFactory!
  var _layoutBuilder: LayoutBuilder!

  // MARK: - Setup

  override func setUp() {
    let workspace = Workspace()
    _layoutFactory = LayoutFactory()
    _workspaceLayout = WorkspaceLayout(workspace: workspace, engine: DefaultLayoutEngine())
    _layoutBuilder = LayoutBuilder(layoutFactory: _layoutFactory)
    _blockFactory = BlockFactory()
    BKYAssertDoesNotThrow {
      try _blockFactory.load(fromJSONPaths: ["all_test_blocks.json"],
                             bundle: Bundle(for: type(of: self)))
    }
  }

  // MARK: - Tests

  func testAppendBlockLayoutsEmpty() {
    let blockGroupLayout =
      try! _layoutFactory.makeBlockGroupLayout(engine: _workspaceLayout.engine)

    XCTAssertEqual(0, blockGroupLayout.blockLayouts.count)

    // Insert nothing
    blockGroupLayout.appendBlockLayouts([])

    XCTAssertEqual(0, blockGroupLayout.blockLayouts.count)
  }

  func testAppendBlockLayoutsNonEmpty() {
    let blockGroupLayout =
      try! _layoutFactory.makeBlockGroupLayout(engine: _workspaceLayout.engine)

    // Add a bunch of block layouts
    var blockLayouts = [BlockLayout]()
    for _ in 0 ..< 10 {
      let blockLayout = createBlockLayout()
      blockLayouts.append(blockLayout)
    }
    blockGroupLayout.appendBlockLayouts(blockLayouts)

    // Check that each layout was appended, and that their parentLayout and zIndex were updated
    let appendedBlockLayouts = blockGroupLayout.blockLayouts
    XCTAssertEqual(blockLayouts.count, appendedBlockLayouts.count)

    for blockLayout in appendedBlockLayouts {
      XCTAssertEqual(blockGroupLayout, blockLayout.parentLayout)
      XCTAssertTrue(blockLayouts.contains(blockLayout))
    }
  }

  func testRemoveBlockLayoutAtIndexFromBeginning() {
    // Create block group with a bunch of block layouts
    let blockGroupLayout = createBlockGroupLayout(numberOfBlockLayouts: 10)

    // Remove block layout from beginning
    let blockLayout = blockGroupLayout.removeBlockLayout(atIndex: 0)

    // Check that its parent is nil
    XCTAssertNil(blockLayout.parentLayout)

    // Check block layout has been removed
    XCTAssertEqual(0, blockGroupLayout.blockLayouts.filter({ $0 == blockLayout }).count)
  }

  func testRemoveBlockLayoutAtIndexFromMiddle() {
    // Create block group with a bunch of block layouts
    let blockGroupLayout = createBlockGroupLayout(numberOfBlockLayouts: 10)

    // Remove block layout from beginning
    let blockLayout = blockGroupLayout.removeBlockLayout(atIndex: 5)

    // Check that its parent is nil
    XCTAssertNil(blockLayout.parentLayout)

    // Check block layout has been removed
    XCTAssertEqual(0, blockGroupLayout.blockLayouts.filter({ $0 == blockLayout }).count)
  }

  func testRemoveBlockLayoutAtIndexFromEnd() {
    // Create block group with a bunch of block layouts
    let blockGroupLayout = createBlockGroupLayout(numberOfBlockLayouts: 10)

    // Remove block layout from beginning
    let blockLayout = blockGroupLayout.removeBlockLayout(atIndex: 9)

    // Check that its parent is nil
    XCTAssertNil(blockLayout.parentLayout)

    // Check block layout has been removed
    XCTAssertEqual(0, blockGroupLayout.blockLayouts.filter({ $0 == blockLayout }).count)
  }

  func testRemoveAllStartingFromBlockLayoutInGroup() {
    // Create block group with a bunch of block layouts
    let initialNumberOfBlockLayouts = 10
    let blockGroupLayout = createBlockGroupLayout(numberOfBlockLayouts: initialNumberOfBlockLayouts)

    // Remove all from a given block layout
    let removalIndex = 3
    let blockLayout = blockGroupLayout.blockLayouts[removalIndex]
    let removedBlockLayouts = blockGroupLayout.removeAllBlockLayouts(startingFrom: blockLayout)

    // Check array counts for block group and removedLayouts
    XCTAssertEqual(removalIndex, blockGroupLayout.blockLayouts.count)
    XCTAssertEqual(initialNumberOfBlockLayouts - removalIndex, removedBlockLayouts.count)

    // Check that each removed layout is no longer in the group and has its parent set to nil
    for removedBlockLayout in removedBlockLayouts {
      XCTAssertNil(removedBlockLayout.parentLayout)
      XCTAssertFalse(blockGroupLayout.blockLayouts.contains(removedBlockLayout))
    }
  }

  func testRemoveAllStartingFromBlockLayoutNotInGroup() {
    // Create block group with a bunch of block layouts
    let initialNumberOfBlockLayouts = 10
    let blockGroupLayout = createBlockGroupLayout(numberOfBlockLayouts: initialNumberOfBlockLayouts)

    // Try remove a block layout that doesn't actually exist in the group
    let randomBlockLayout = createBlockLayout()
    let removedBlockLayouts =
      blockGroupLayout.removeAllBlockLayouts(startingFrom: randomBlockLayout)

    // Nothing should have been removed, but the returned list should contain the target block
    XCTAssertEqual(initialNumberOfBlockLayouts, blockGroupLayout.blockLayouts.count)
    XCTAssertEqual(1, removedBlockLayouts.count)
    XCTAssertEqual(randomBlockLayout, removedBlockLayouts[0])
  }

  func testReset() {
    // Create block group with a bunch of block layouts
    let blockGroupLayout =
      try! _layoutFactory.makeBlockGroupLayout(engine: _workspaceLayout.engine)
    var blockLayouts = [BlockLayout]()
    for _ in 0 ..< 10 {
      blockLayouts.append(createBlockLayout())
    }
    blockGroupLayout.appendBlockLayouts(blockLayouts)

    // Reset the block group layout
    blockGroupLayout.reset()

    // Check that the block group is empty and each block layout has its parent set to nil
    XCTAssertEqual(0, blockGroupLayout.blockLayouts.count)
    XCTAssertEqual(0, blockLayouts.filter({ $0.parentLayout != nil}).count)
  }

  func testMoveToWorkspacePositionForTopLevelBlockGroup() {
    let blockGroupLayout =
      try! _layoutFactory.makeBlockGroupLayout(engine: _workspaceLayout.engine)
    blockGroupLayout.relativePosition = WorkspacePoint(x: 30, y: 30)

    // Add block group to workspace
    _workspaceLayout.appendBlockGroupLayout(blockGroupLayout)

    // Move to new workspace position
    let newPosition = WorkspacePoint(x: -10.134, y: 30)
    blockGroupLayout.move(toWorkspacePosition: newPosition)

    // Check that it has a new relative position
    XCTAssertEqual(newPosition, blockGroupLayout.relativePosition)
  }

  func testMoveToWorkspacePositionForNonTopLevelBlockGroup() {
    // Add a block to the workspace that has an input value (which automatically contains a block
    // group layout).
    let workspace = _workspaceLayout.workspace
    guard let blockInputOutput = try! _blockFactory.addBlock(name: "simple_input_output",
      toWorkspace: workspace) else {
        XCTFail("Blocks couldn't be loaded into the workspace")
        return
    }

    // Build its layout tree
    do {
      try _layoutBuilder.buildLayoutTree(forWorkspaceLayout: _workspaceLayout)
    } catch let error {
      XCTFail("Couldn't build the layout tree: \(error)")
    }

    if let blockGroupLayout = blockInputOutput.inputs[0].layout?.blockGroupLayout {
      // Try to move the block group layout belonging to the input to a new workspace position.
      // Nothing should happen
      let currentPosition = blockGroupLayout.relativePosition
      let newPosition = currentPosition + WorkspacePoint(x: 10, y: 10)
      blockGroupLayout.move(toWorkspacePosition: newPosition)

      XCTAssertEqual(currentPosition, blockGroupLayout.relativePosition)
    } else {
      XCTFail("Couldn't find block group layout on the input")
    }
  }

  // MARK: - Helper methods

  func createBlockGroupLayout(numberOfBlockLayouts: Int) -> BlockGroupLayout {
    let blockGroupLayout =
      try! _layoutFactory.makeBlockGroupLayout(engine: _workspaceLayout.engine)

    // Add a bunch of block layouts
    var blockLayouts = [BlockLayout]()
    for _ in 0 ..< numberOfBlockLayouts {
      let blockLayout = createBlockLayout()
      blockLayouts.append(blockLayout)
    }
    blockGroupLayout.appendBlockLayouts(blockLayouts)

    return blockGroupLayout
  }

  func createBlockLayout() -> BlockLayout {
    let block = try! BlockBuilder(name: "test").makeBlock()
    try! _workspaceLayout.workspace.addBlockTree(block)
    let layout = try! _layoutFactory.makeBlockLayout(block: block, engine: _workspaceLayout.engine)
    block.layout = layout
    return layout
  }
}
