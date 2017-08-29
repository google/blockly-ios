/*
 * Copyright 2016 Google Inc. All Rights Reserved.
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

class LayoutTest: XCTestCase {

  // MARK: - Properties

  var layoutEngine: LayoutEngine!

  // MARK: - Setup

  override func setUp() {
    super.setUp()
    layoutEngine = LayoutEngine()
  }

  // MARK: - Tests

  func testFlattenedLayoutTree_SingleLevel() {
    let layout = Layout(engine: layoutEngine)

    let flattenedTree = layout.flattenedLayoutTree()

    XCTAssertEqual(1, flattenedTree.count)

    if flattenedTree.count == 1 {
      XCTAssertTrue(flattenedTree.contains(layout))
    }
  }

  func testFlattenedLayoutTree_MultipleLevels() {
    let grandParentLayout = Layout(engine: layoutEngine)
    let parentLayout = Layout(engine: layoutEngine)
    let childLayout = Layout(engine: layoutEngine)

    grandParentLayout.adoptChildLayout(parentLayout)
    parentLayout.adoptChildLayout(childLayout)

    let flattenedTree = grandParentLayout.flattenedLayoutTree()

    XCTAssertEqual(3, flattenedTree.count)

    if flattenedTree.count == 3 {
      XCTAssertTrue(flattenedTree.contains(childLayout))
      XCTAssertTrue(flattenedTree.contains(parentLayout))
    }
  }

  func testFlattenedLayoutTree_ByTypeFoundParentLevel() throws {
    let block = try BlockBuilder(name: "test").makeBlock()
    let grandParentLayout = BlockLayout(block: block, engine: layoutEngine)
    let parentLayout = Layout(engine: layoutEngine)
    let childLayout = Layout(engine: layoutEngine)

    grandParentLayout.adoptChildLayout(parentLayout)
    parentLayout.adoptChildLayout(childLayout)

    let flattenedTree = grandParentLayout.flattenedLayoutTree(ofType: BlockLayout.self)

    XCTAssertEqual(1, flattenedTree.count)

    if flattenedTree.count == 1 {
      XCTAssertTrue(flattenedTree.contains(grandParentLayout))
    }
  }

  func testFlattenedLayoutTree_ByTypeFoundChildLevel() throws {
    let block = try BlockBuilder(name: "test").makeBlock()
    let grandParentLayout = Layout(engine: layoutEngine)
    let parentLayout = Layout(engine: layoutEngine)
    let childLayout = BlockLayout(block: block, engine: layoutEngine)

    grandParentLayout.adoptChildLayout(parentLayout)
    parentLayout.adoptChildLayout(childLayout)

    let flattenedTree = grandParentLayout.flattenedLayoutTree(ofType: BlockLayout.self)

    XCTAssertEqual(1, flattenedTree.count)

    if flattenedTree.count == 1 {
      XCTAssertTrue(flattenedTree.contains(childLayout))
    }
  }

  func testFlattenedLayoutTree_ByTypeNoneFound() {
    let layout = Layout(engine: layoutEngine)

    let flattenedTree = layout.flattenedLayoutTree(ofType: FieldLayout.self)

    XCTAssertEqual(0, flattenedTree.count)
  }
}
