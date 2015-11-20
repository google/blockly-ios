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

class BlockFactoryJSONTest: XCTestCase {

    func testLoadBlocks() {
      let workspace = Workspace(isFlyout: false)
      do {
        let factory = try BlockFactory(jsonPath: "block_factory_json_test",
          bundle: NSBundle(forClass: self.dynamicType))
        if let _ = factory.obtain("block_id_1", forWorkspace: workspace) {
          // expected
        } else {
          XCTFail("Factory is missing block_id_1")
        }
        if let _ = factory.obtain("block_id_2", forWorkspace: workspace) {
          // expected
        } else {
          XCTFail("Factory is missing block_id_2");
        }
      } catch let error as NSError {
        XCTFail("Error: \(error.localizedDescription)")
      }
    }

  func testMultipleBlocks() {
    let workspace = Workspace(isFlyout: false)
    do {
      let factory = try BlockFactory(jsonPath: "block_factory_json_test",
        bundle: NSBundle(forClass: self.dynamicType))
      if let block1 = factory.obtain("block_id_1", forWorkspace: workspace) {
        let block2 = factory.obtain("block_id_1", forWorkspace: workspace)
        XCTAssertTrue(block1 !== block2, "BlockFactory returned the same block instance twice");
      } else {
        XCTFail("Factory is missing block_id_1")
      }
    } catch let error as NSError {
      XCTFail("Error: \(error.localizedDescription)")
    }
  }
}
