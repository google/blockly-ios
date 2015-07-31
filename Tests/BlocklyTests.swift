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

import Blockly
import UIKit
import XCTest

class BlocklyTests: XCTestCase {

  var workspace: Workspace!

  override func setUp() {
    super.setUp()

    workspace = Workspace(isFlyout: true, isRTL: false)
  }

  override func tearDown() {
    super.tearDown()
  }

  func testBlockCreation() {
    let builder = Block.Builder(identifier: "Test", name: "name", workspace: workspace)
    let block = builder.build()

    XCTAssertEqual("Test", block.identifier)
  }

  func testBlockCreationFromJSON() {
    var block: Block!
    do {
      let json = try NSJSONSerialization.bky_JSONDictionaryFromString(
        "{\"colour\":135, \"inputsInline\":true, \"name\":\"New Kid\"}")
      block = try Block.blockFromJSONDictionary(json, workspace: workspace)
    } catch let error as NSError {
      XCTAssertTrue(false, error.localizedDescription)
    }

    XCTAssertEqual("New Kid", block.name)
    XCTAssertEqual(135, block.colourHue)
    XCTAssertEqual(true, block.inputsInline)
  }
}
