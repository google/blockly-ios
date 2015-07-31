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

class BlockTest: XCTestCase {

  // MARK: - tokenizeMessage

  func testTokenizeMessage_emptyMessage() {
    let tokens = Block.tokenizeMessage("")
    XCTAssertEqual(0, tokens.count)
  }

  func testTokenizeMessage_emojiMessage() {
    let tokens = Block.tokenizeMessage("👋 %1 🌏")
    XCTAssertEqual(["👋 ", 1, " 🌏"], tokens)
  }

  func testTokenizeMessage_simpleMessage() {
    let tokens = Block.tokenizeMessage("Simple text")
    XCTAssertEqual(["Simple text"], tokens)
  }

  func testTokenizeMessage_complexMessage() {
    let tokens = Block.tokenizeMessage("  token1%1%%%3another\n%29 😸📺 %1234567890")
    XCTAssertEqual(["  token1", 1, "%", 3, "another\n", 29, " 😸📺 ", 1234567890], tokens)
  }

  func testTokenizeMessage_unescapePercent() {
    let tokens = Block.tokenizeMessage("blah%blahblah")
    XCTAssertEqual(["blah%blahblah"], tokens)
  }

  func testTokenizeMessage_trailingPercent() {
    let tokens = Block.tokenizeMessage("%")
    XCTAssertEqual(["%"], tokens)
  }
}
