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
    XCTAssertEqual("BAR10", _nameManager.generateUniqueName("BAR10", addToList: true))
    XCTAssertEqual("BAR11", _nameManager.generateUniqueName("BAR10", addToList: true))
  }

  func testCaseInsensitiveUniqueName() {
    let name1 = _nameManager.generateUniqueName("string", addToList: true)
    let name2 = _nameManager.generateUniqueName("String", addToList: true)
    XCTAssertNotEqual(name1, name2)
    XCTAssertNotEqual(name1.lowercased(), name2.lowercased())
  }

  func testListFunctions() {
    BKYAssertDoesNotThrow({ try _nameManager.addName("foo") })
    XCTAssertEqual(1, _nameManager.count)
    _ = _nameManager.generateUniqueName("bar", addToList: true)
    XCTAssertEqual(2, _nameManager.count)

    _ = _nameManager.generateUniqueName("bar", addToList: false)
    XCTAssertEqual(2, _nameManager.count)

    _nameManager.clearNames()
    XCTAssertEqual(0, _nameManager.count)
  }

  func testAddName_Standard() {
    let listener = NameManagerTestListener()
    _nameManager.listeners.add(listener)

    BKYAssertDoesNotThrow({ try _nameManager.addName("bar") })
    XCTAssertEqual(["bar"], _nameManager.names)
    XCTAssertTrue(listener.addedName)
  }

  func testAddName_CaseInsensitiveName() {
    let listener = NameManagerTestListener()
    _nameManager.listeners.add(listener)

    BKYAssertDoesNotThrow({ try _nameManager.addName("foo") })
    XCTAssertEqual(["foo"], _nameManager.names)
    XCTAssertTrue(listener.addedName)
    listener.clearState()

    BKYAssertThrow(errorType: BlocklyError.self) {
      try _nameManager.addName("FOO")
    }
  }

  func testRequestRemovalForName() {
    BKYAssertDoesNotThrow({ try _nameManager.addName("foo") })
    XCTAssertTrue(_nameManager.containsName("FOO"))
    XCTAssertTrue(_nameManager.removeName("Foo"))
    XCTAssertFalse(_nameManager.containsName("foo"))
    XCTAssertFalse(_nameManager.removeName("foo"))
  }

  func testRequestRemovalForName_BlockRemoval() {
    let listener = NameManagerTestListener()
    listener.allowRemoveName = false
    _nameManager.listeners.add(listener)

    BKYAssertDoesNotThrow({ try _nameManager.addName("foo") })
    XCTAssertTrue(_nameManager.containsName("foo"))
    XCTAssertFalse(_nameManager.removeName("foo"))
    XCTAssertTrue(_nameManager.containsName("foo"))
  }

  func testRenameDisplayName_Standard() {
    let listener = NameManagerTestListener()
    _nameManager.listeners.add(listener)

    BKYAssertDoesNotThrow({ try _nameManager.addName("bar") })
    XCTAssertTrue(_nameManager.renameDisplayName("BaR"))
    XCTAssertTrue(listener.renamedName)
    XCTAssertTrue(_nameManager.containsName("BaR"))
  }

  func testRenameDisplayName_SameName() {
    let listener = NameManagerTestListener()
    _nameManager.listeners.add(listener)

    BKYAssertDoesNotThrow({ try _nameManager.addName("foo") })
    XCTAssertFalse(_nameManager.renameDisplayName("foo"))
    XCTAssertFalse(listener.renamedName)
  }

  func testRenameDisplayName_NonExistentName() {
    let listener = NameManagerTestListener()
    _nameManager.listeners.add(listener)

    BKYAssertDoesNotThrow({ try _nameManager.addName("foo") })
    XCTAssertFalse(_nameManager.renameDisplayName("foo "))
    XCTAssertFalse(listener.renamedName)
  }

  func testRenameName_Standard() {
    let listener = NameManagerTestListener()
    _nameManager.listeners.add(listener)

    BKYAssertDoesNotThrow({ try _nameManager.addName("foo") })
    XCTAssertTrue(_nameManager.renameName("foo", to: "BAR"))
    XCTAssertEqual(["BAR"], _nameManager.names)
    XCTAssertTrue(listener.renamedName)
  }

  func testRenameName_CaseInsensitive() {
    BKYAssertDoesNotThrow({ try _nameManager.addName("bar") })
    XCTAssertTrue(_nameManager.renameName("BAR", to: "XYZ"))
    XCTAssertEqual(["XYZ"], _nameManager.names)
  }

  func testRenameName_ToAnotherExistingName() {
    BKYAssertDoesNotThrow({ try _nameManager.addName("foo") })
    BKYAssertDoesNotThrow({ try _nameManager.addName("bar") })
    XCTAssertTrue(_nameManager.renameName("bar", to: "FOO"))
    XCTAssertEqual(["FOO"], _nameManager.names) // There should only be one name now
  }

  func testRenameName_NonExistentName() {
    let listener = NameManagerTestListener()
    _nameManager.listeners.add(listener)

    XCTAssertFalse(_nameManager.renameName("NON EXISTENT NAME", to: "SOME NAME"))
    XCTAssertFalse(listener.renamedName)
  }

  func testRenameName_emptyString() {
    let listener = NameManagerTestListener()
    _nameManager.listeners.add(listener)

    XCTAssertFalse(_nameManager.renameName("", to: "a"))
    XCTAssertFalse(listener.renamedName)
  }

  func testRenameName_SameName() {
    let listener = NameManagerTestListener()
    _nameManager.listeners.add(listener)

    BKYAssertDoesNotThrow({ try _nameManager.addName("a") })
    XCTAssertFalse(_nameManager.renameName("a", to: "a"))
    XCTAssertFalse(listener.renamedName)
  }
}

/**
 Mock listener for testing `NameManagerListener`.
 */
class NameManagerTestListener: NameManagerListener {
  var addedName = false
  var renamedName = false
  var removedName = false
  var allowRemoveName = true

  func clearState() {
    addedName = false
    renamedName = false
    removedName = false
  }

  @objc func nameManager(_ nameManager: NameManager, didAddName name: String) {
    addedName = true
  }

  @objc func nameManager(_ nameManager: NameManager, didRemoveName name: String) {
    removedName = true
  }

  @objc func nameManager(
    _ nameManager: NameManager, didRenameName oldName: String, toName newName: String)
  {
    renamedName = true
  }

  @objc func nameManager(_ nameManager: NameManager, shouldRemoveName name: String) -> Bool {
    return allowRemoveName
  }
}
