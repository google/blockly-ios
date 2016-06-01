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

  // MARK: - Setup

  override func setUp() {
    _workspace = Workspace()
  }

  // MARK: - Tests

  func testWorkspaceAddBlockTree_TopLevelShadowBlockFailure() {
    guard let shadowBlock =
      BKYAssertDoesNotThrow({ try Block.Builder(name: "shadow").build(shadow: true) }) else
    {
      XCTFail("Could not create block")
      return
    }

    BKYAssertThrow("Cannot add shadow blocks as top-level blocks", errorType: BlocklyError.self) {
      try self._workspace.addBlockTree(shadowBlock)
    }
  }

  func testWorkspaceReadOnly() {
    guard let block1 = BKYAssertDoesNotThrow({ try Block.Builder(name: "block1").build() }),
      let block2 = BKYAssertDoesNotThrow({ try Block.Builder(name: "block2").build() }) else
    {
      XCTFail("Could not create blocks")
      return
    }

    // Add non-editable block to workspace when it's not read only.
    // It should automatically change the block to be editable.
    _workspace.readOnly = false
    XCTAssertFalse(_workspace.readOnly)
    block1.editable = false
    XCTAssertFalse(block1.editable)
    BKYAssertDoesNotThrow { try self._workspace.addBlockTree(block1) }
    XCTAssertTrue(block1.editable)

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
    // This should update all blocks to be non-editable.
    _workspace.readOnly = false
    XCTAssertFalse(_workspace.readOnly)
    for (_, block) in _workspace.allBlocks {
      XCTAssertTrue(block.editable)
    }
  }
}
