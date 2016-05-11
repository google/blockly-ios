/*
 * Copyright 2015 Google Inc. All Rights Reserved.
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
import Foundation
import XCTest

/**
 Tests for `NameManager`.
 */
class NameManagerTest: XCTestCase {

  // MARK: - Properties

  /// The `NameManager` to test
  var _nameManager: NameManager!

  // MARK: - Setup

  override func setUp() {
    super.setUp()
    _nameManager = NameManager()
  }

  // MARK: - Tests

  func testGenerateUniqueName(){
    let name1 = _nameManager.generateUniqueName("string", addToList: true)
    XCTAssertNotEqual(name1, _nameManager.generateUniqueName("string", addToList: true))

    XCTAssertEqual("foo", _nameManager.generateUniqueName("foo", addToList: true))
    XCTAssertEqual("foo2", _nameManager.generateUniqueName("foo", addToList: true))
    XCTAssertEqual("foo3", _nameManager.generateUniqueName("foo2", addToList: true))
    XCTAssertEqual("222", _nameManager.generateUniqueName("222", addToList: true))
    XCTAssertEqual("223", _nameManager.generateUniqueName("222", addToList: true))
  }

  func testCaseInsensitiveUniqueName() {
    let name1 = _nameManager.generateUniqueName("string", addToList: true)
    let name2 = _nameManager.generateUniqueName("String", addToList: true)
    XCTAssertNotEqual(name1, name2)
    XCTAssertNotEqual(name1.lowercaseString, name2.lowercaseString)
  }

  func testListFunctions() {
    _nameManager.addName("foo")
    XCTAssertEqual(1, _nameManager.count)
    _nameManager.generateUniqueName("bar", addToList: true)
    XCTAssertEqual(2, _nameManager.count)

    _nameManager.generateUniqueName("bar", addToList: false)
    XCTAssertEqual(2, _nameManager.count)

    _nameManager.clearNames()
    XCTAssertEqual(0, _nameManager.count)
  }

  func testRemove() {
    _nameManager.addName("foo")
    XCTAssertTrue(_nameManager.containsName("FOO"))
    _nameManager.removeName("Foo")
    XCTAssertFalse(_nameManager.containsName("foo"))
    XCTAssertFalse(_nameManager.removeName("foo"))
  }
}
