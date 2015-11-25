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

class WorkspaceLayoutTest: XCTestCase {

  var _workspaceLayout: WorkspaceLayout!
  var _blockFactory: BlockFactory!

  // MARK: - Setup

  override func setUp() {
    let workspace = Workspace(isFlyout: false)
    _workspaceLayout = WorkspaceLayout(workspace: workspace, layoutBuilder: LayoutBuilder())
    _blockFactory = try! BlockFactory(
      jsonPath: "all_test_blocks", bundle: NSBundle(forClass: self.dynamicType))
  }

  // MARK: - Tests

  func testAllBlockLayoutsInWorkspace() {
    let workspace = _workspaceLayout.workspace

    // Add blocks to the workspace
    guard
      let _ =
        _blockFactory.obtain("no_connections", forWorkspace: workspace),
      let blockMathNumber =
        _blockFactory.obtain("math_number", forWorkspace: workspace),
      let blockInputOutput =
        _blockFactory.obtain("simple_input_output", forWorkspace: workspace),
      let blockMultipleInputOutput =
        _blockFactory.obtain("multiple_input_output", forWorkspace: workspace),
      let blockStatementValueInput =
        _blockFactory.obtain("statement_value_input", forWorkspace: workspace),
      let blockStatementStatementInput =
        _blockFactory.obtain("statement_statement_input", forWorkspace: workspace)
      else
    {
      XCTFail("Blocks couldn't be loaded into the workspace")
      return
    }

    // Build the layout tree
    do {
      try _workspaceLayout.layoutBuilder.buildLayoutTree()
    } catch let error as NSError {
      XCTFail("Couldn't build the layout tree: \(error)")
    }

    // Manually walk through tree to get all block layout descendants for workspace layout
    var treeTraversalBlockLayouts =
      treeTraversalOfBlockLayoutsUnderWorkspaceLayout(_workspaceLayout)
    var allBlockLayouts = _workspaceLayout.allBlockLayoutsInWorkspace()

    // Compare both lists
    XCTAssertEqual(treeTraversalBlockLayouts.count, allBlockLayouts.count)
    for blockLayout in allBlockLayouts {
      XCTAssertTrue(treeTraversalBlockLayouts.contains(blockLayout))
    }

    // Connect some blocks together
    do {
      try blockInputOutput.inputs[0].connection?.connectTo(
        blockMathNumber.outputConnection)

      try blockStatementValueInput.inputs[0].connection?.connectTo(
        blockMultipleInputOutput.outputConnection)

      try blockStatementStatementInput.nextConnection?.connectTo(
        blockStatementValueInput.previousConnection)
    } catch let error as NSError {
      XCTFail("Couldn't connect blocks together: \(error)")
    }

    // Check all block layout now that some layouts are no longer top-level blocks
    treeTraversalBlockLayouts =
      treeTraversalOfBlockLayoutsUnderWorkspaceLayout(_workspaceLayout)
    allBlockLayouts = _workspaceLayout.allBlockLayoutsInWorkspace()

    // Compare both lists
    XCTAssertEqual(treeTraversalBlockLayouts.count, allBlockLayouts.count)
    for blockLayout in allBlockLayouts {
      XCTAssertTrue(treeTraversalBlockLayouts.contains(blockLayout))
    }
  }

  func testAppendBlockGroupLayout() {
    var allBlockGroupLayouts = [String: BlockGroupLayout]()

    // Add block group layouts
    for _ in 0 ..< 10 {
      let blockGroupLayout = BlockGroupLayout(workspaceLayout: _workspaceLayout)
      allBlockGroupLayouts[blockGroupLayout.uuid] = blockGroupLayout
      _workspaceLayout.appendBlockGroupLayout(blockGroupLayout)
      // The block group's parent should be set to the _workspaceLayout now
      XCTAssertEqual(_workspaceLayout, blockGroupLayout.parentLayout)
    }

    // Check for their existence
    XCTAssertEqual(allBlockGroupLayouts.count, _workspaceLayout.blockGroupLayouts.count)

    for blockGroupLayout in _workspaceLayout.blockGroupLayouts {
      XCTAssertEqual(allBlockGroupLayouts[blockGroupLayout.uuid], blockGroupLayout)
    }
  }

  func testRemoveBlockGroupLayout() {
    var allBlockGroupLayouts = [BlockGroupLayout]()

    // Add block group layouts
    for _ in 0 ..< 10 {
      let blockGroupLayout = BlockGroupLayout(workspaceLayout: _workspaceLayout)
      allBlockGroupLayouts.append(blockGroupLayout)
      _workspaceLayout.appendBlockGroupLayout(blockGroupLayout)
    }

    // Remove them
    for (var i = allBlockGroupLayouts.count - 1; i >= 0; i--) {
      let blockGroupLayout = allBlockGroupLayouts.removeAtIndex(i)
      _workspaceLayout.removeBlockGroupLayout(blockGroupLayout)
      XCTAssertEqual(allBlockGroupLayouts.count, _workspaceLayout.blockGroupLayouts.count)
      // The block group's parent should be nil now
      XCTAssertNil(blockGroupLayout.parentLayout)
    }

    XCTAssertEqual(0, _workspaceLayout.blockGroupLayouts.count)
  }

  func testReset() {
    var allBlockGroupLayouts = [BlockGroupLayout]()

    // Add block group layouts
    for _ in 0 ..< 10 {
      let blockGroupLayout = BlockGroupLayout(workspaceLayout: _workspaceLayout)
      allBlockGroupLayouts.append(blockGroupLayout)
      _workspaceLayout.appendBlockGroupLayout(blockGroupLayout)
    }

    // Reset
    _workspaceLayout.reset()

    // Assert checks
    XCTAssertEqual(0, _workspaceLayout.blockGroupLayouts.count)

    for blockGroupLayout in allBlockGroupLayouts {
      // Every block group's parent should be nil now
      XCTAssertNil(blockGroupLayout.parentLayout)
    }
  }

  func testBringBlockGroupLayoutToFront() {
    // Add block group layouts
    for _ in 0 ..< 10 {
      let blockGroupLayout = BlockGroupLayout(workspaceLayout: _workspaceLayout)
      blockGroupLayout.zIndex = 0
      _workspaceLayout.appendBlockGroupLayout(blockGroupLayout)
    }

    // Try bringing every block group layout to the front.
    let allBlockGroupLayouts = _workspaceLayout.blockGroupLayouts
    for blockGroupLayout in allBlockGroupLayouts {
      _workspaceLayout.bringBlockGroupLayoutToFront(blockGroupLayout)
      XCTAssertTrue(
        isHighestBlockGroupLayout(blockGroupLayout, inWorkspaceLayout: _workspaceLayout))
    }
  }

  // MARK: - Helper methods

  func isHighestBlockGroupLayout(
    blockGroupLayout: BlockGroupLayout, inWorkspaceLayout workspaceLayout: WorkspaceLayout) -> Bool
  {
    for aBlockGroupLayout in workspaceLayout.blockGroupLayouts {
      if aBlockGroupLayout != blockGroupLayout &&
        aBlockGroupLayout.zIndex >= blockGroupLayout.zIndex
      {
        // Found another block group layout with a zIndex on the same level or higher than the
        // target
        return false
      }
    }
    return true
  }

  func treeTraversalOfBlockLayoutsUnderWorkspaceLayout(workspaceLayout: WorkspaceLayout)
    -> [BlockLayout]
  {
    var blockLayouts = [BlockLayout]()
    var layoutsToProcess = workspaceLayout.blockGroupLayouts

    while !layoutsToProcess.isEmpty {
      let blockGroupLayout = layoutsToProcess.removeFirst()
      blockLayouts += blockGroupLayout.blockLayouts

      for blockLayout in blockGroupLayout.blockLayouts {
        for inputLayout in blockLayout.inputLayouts {
          layoutsToProcess.append(inputLayout.blockGroupLayout)
        }
      }
    }

    return blockLayouts
  }
}
