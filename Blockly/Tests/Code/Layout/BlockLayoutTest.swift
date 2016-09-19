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
  var _layoutFactory: LayoutFactory!
  var _layoutBuilder: LayoutBuilder!

  // MARK: - Setup

  override func setUp() {
    let workspace = Workspace()
    _layoutFactory = DefaultLayoutFactory()
    _workspaceLayout = WorkspaceLayout(workspace: workspace, engine: DefaultLayoutEngine())
    _layoutBuilder = LayoutBuilder(layoutFactory: _layoutFactory)
    _blockFactory = try! BlockFactory(
      jsonPath: "all_test_blocks.json", bundle: Bundle(for: type(of: self)))
  }

  // MARK: - Tests

  func testInputLayoutBeforeLayoutEmpty() {
    // Create block with no input's
    let builder = Block.Builder(name: "test")
    let block = try! builder.build()
    try! _workspaceLayout.workspace.addBlockTree(block)

    // Build layout tree
    do {
      try _layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    if let blockLayout = block.layout {
      // Test for an input layout that doesn't exist in blockLayout
      let dummyInput = Input.Builder(type: .dummy, name: "test").build()
      let dummyInputLayout =
        try! _layoutFactory.layoutForInput(dummyInput, engine: _workspaceLayout.engine)
      XCTAssertNil(blockLayout.inputLayoutBefore(layout: dummyInputLayout))
    } else {
      XCTFail("Couldn't build block layout")
    }
  }

  func testInputLayoutBeforeLayoutMultipleValues() {
    // Create block with many inputs
    let builder = Block.Builder(name: "test")
    builder.inputBuilders.append(Input.Builder(type: .value, name: "input1"))
    builder.inputBuilders.append(Input.Builder(type: .dummy, name: "input2"))
    builder.inputBuilders.append(Input.Builder(type: .statement, name: "input3"))
    builder.inputBuilders.append(Input.Builder(type: .value, name: "input4"))
    let block = try! builder.build()
    try! _workspaceLayout.workspace.addBlockTree(block)

    // Build layout tree
    do {
      try _layoutBuilder.buildLayoutTree(_workspaceLayout)
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
        XCTAssertEqual(previousInputLayout,
          blockLayout.inputLayoutBefore(layout: currentInputLayout))
      }

      // Test for an input layout that doesn't exist in blockLayout
      let dummyInput = Input.Builder(type: .dummy, name: "test").build()
      let dummyInputLayout =
        try! _layoutFactory.layoutForInput(dummyInput, engine: _workspaceLayout.engine)
      XCTAssertNil(blockLayout.inputLayoutBefore(layout: dummyInputLayout))
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
      try _layoutBuilder.buildLayoutTree(_workspaceLayout)
    } catch let error as NSError {
      XCTFail("Couldn't build layout tree: \(error)")
    }

    if let blockLayout = block.layout {
      // Test for an input layout that doesn't exist in blockLayout
      let dummyInput = Input.Builder(type: .dummy, name: "test").build()
      let dummyInputLayout =
        try! _layoutFactory.layoutForInput(dummyInput, engine: _workspaceLayout.engine)
      XCTAssertNil(blockLayout.inputLayoutAfter(layout: dummyInputLayout))
    } else {
      XCTFail("Couldn't build block layout")
    }
  }

  func testInputLayoutAfterLayoutMultipleValues()  {
    // Create block with many inputs
    let builder = Block.Builder(name: "test")
    builder.inputBuilders.append(Input.Builder(type: .value, name: "input1"))
    builder.inputBuilders.append(Input.Builder(type: .dummy, name: "input2"))
    builder.inputBuilders.append(Input.Builder(type: .statement, name: "input3"))
    builder.inputBuilders.append(Input.Builder(type: .value, name: "input4"))
    let block = try! builder.build()
    try! _workspaceLayout.workspace.addBlockTree(block)

    // Build layout tree
    do {
      try _layoutBuilder.buildLayoutTree(_workspaceLayout)
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
        XCTAssertEqual(nextInputLayout, blockLayout.inputLayoutAfter(layout: currentInputLayout))
      }

      // Test for an input layout that doesn't exist in blockLayout
      let dummyInput = Input.Builder(type: .dummy, name: "test").build()
      let dummyInputLayout =
        try! _layoutFactory.layoutForInput(dummyInput, engine: _workspaceLayout.engine)
      XCTAssertNil(blockLayout.inputLayoutAfter(layout: dummyInputLayout))
    } else {
      XCTFail("Couldn't build block layout")
    }
  }
}
