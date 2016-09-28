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

  var _blockFactory: BlockFactory!

  override func setUp() {
    super.setUp()
    _blockFactory = BlockFactory()
  }

  func testLoadBlocksFromColorDefault() {
    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _blockFactory.makeBlock(name: "colour_picker")
    }
    _blockFactory.load(fromDefaultFiles: .ColorDefault)

    let block = BKYAssertDoesNotThrow { try _blockFactory.makeBlock(name: "colour_picker") }
    XCTAssertNotNil(block)
  }

  func testLoadBlocksFromLogicDefault() {
    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _blockFactory.makeBlock(name: "controls_if")
    }
    _blockFactory.load(fromDefaultFiles: .LogicDefault)

    let block = BKYAssertDoesNotThrow { try _blockFactory.makeBlock(name: "controls_if") }
    XCTAssertNotNil(block)
  }

  func testLoadBlocksFromLoopDefault() {
    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _blockFactory.makeBlock(name: "controls_repeat_ext")
    }
    _blockFactory.load(fromDefaultFiles: .LoopDefault)

    let block = BKYAssertDoesNotThrow { try _blockFactory.makeBlock(name: "controls_repeat_ext") }
    XCTAssertNotNil(block)
  }

  func testLoadBlocksFromMathDefault() {
    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _blockFactory.makeBlock(name: "math_number")
    }
    _blockFactory.load(fromDefaultFiles: .MathDefault)

    let block = BKYAssertDoesNotThrow { try _blockFactory.makeBlock(name: "math_number") }
    XCTAssertNotNil(block)
  }

  func testLoadBlocksFromVariableDefault() {
    BKYAssertThrow(errorType: BlocklyError.self) {
      _ = try _blockFactory.makeBlock(name: "variables_get")
    }
    _blockFactory.load(fromDefaultFiles: .VariableDefault)

    let block = BKYAssertDoesNotThrow { try _blockFactory.makeBlock(name: "variables_get") }
    XCTAssertNotNil(block)
  }

  func testLoadBlocksFromJSONPaths() {
    BKYAssertDoesNotThrow {
      try _blockFactory.load(fromJSONPaths: ["block_factory_json_test.json"],
                             bundle: Bundle(for: type(of: self)))
    }

    let block1 = BKYAssertDoesNotThrow { try _blockFactory.makeBlock(name: "block_id_1") }
    XCTAssertNotNil(block1, "Factory is missing block_id_1")

    let block2 = BKYAssertDoesNotThrow { try _blockFactory.makeBlock(name: "block_id_2") }
    XCTAssertNotNil(block2, "Factory is missing block_id_2")
  }

  func testMultipleBlocks() {
    BKYAssertDoesNotThrow {
      try _blockFactory.load(fromJSONPaths: ["block_factory_json_test.json"],
                             bundle: Bundle(for: type(of: self)))
    }

    let firstBlockCopy = BKYAssertDoesNotThrow { try _blockFactory.makeBlock(name: "block_id_1") }
    let secondBlockCopy = BKYAssertDoesNotThrow { try _blockFactory.makeBlock(name: "block_id_1") }
    XCTAssertNotNil(firstBlockCopy)
    XCTAssertNotNil(secondBlockCopy)
    XCTAssertTrue(firstBlockCopy !== secondBlockCopy,
                  "BlockFactory returned the same block instance twice")
  }
}
