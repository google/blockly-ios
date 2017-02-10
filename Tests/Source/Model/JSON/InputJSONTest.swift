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

class InputJSONTest: XCTestCase {

  var workspace: Workspace!
  var block: Block!

  override func setUp() {
    workspace = Workspace()
    let builder = BlockBuilder(name: "Test")
    block = try! builder.makeBlock()
    try! workspace.addBlockTree(block)

    super.setUp()
  }

  // MARK: - inputFromJSON - Value

  func testInputFromJSON_ValueValid() {
    let json = [
      "type": "input_value",
      "name": "input value",
      "align": "CENTRE",
      "check": ["String", "Boolean"]
    ] as [String : Any]
    guard let builder = Input.makeBuilder(json: json) else {
      XCTFail("Could not parse json into an Input")
      return
    }

    let input = builder.makeInput()
    XCTAssertEqual(Input.InputType.value, input.type)
    XCTAssertEqual("input value", input.name)
    XCTAssertEqual(Input.Alignment.center, input.alignment)
    XCTAssertNotNil(input.connection)
    XCTAssertNotNil(input.connection!.typeChecks)
    XCTAssertEqual(2, input.connection!.typeChecks!.count)
    XCTAssertEqual("String", input.connection!.typeChecks![0])
    XCTAssertEqual("Boolean", input.connection!.typeChecks![1])
  }

  // MARK: - inputFromJSON - Statement

  func testInputFromJSON_StatementValid() {
    let json = [
      "type": "input_statement",
      "name": "input statement",
      "align": "LEFT",
      "check": "CustomCheckType"
    ]
    guard let builder = Input.makeBuilder(json: json) else {
      XCTFail("Could not parse json into an Input")
      return
    }

    let input = builder.makeInput()
    XCTAssertEqual(Input.InputType.statement, input.type)
    XCTAssertEqual("input statement", input.name)
    XCTAssertEqual(Input.Alignment.left, input.alignment)
    XCTAssertNotNil(input.connection)
    XCTAssertNotNil(input.connection!.typeChecks)
    XCTAssertEqual(1, input.connection!.typeChecks!.count)
    XCTAssertEqual("CustomCheckType", input.connection!.typeChecks![0])
  }

  // MARK: - inputFromJSON - Dummy

  func testInputFromJSON_DummyValid() {
    let json = [
      "type": "input_dummy",
      "name": "input dummy",
      "check": "Broken!" // This shouldn't be used
    ]
    guard let builder = Input.makeBuilder(json: json) else {
      XCTFail("Could not parse json into an Input")
      return
    }

    let input = builder.makeInput()
    XCTAssertEqual(Input.InputType.dummy, input.type)
    XCTAssertEqual("input dummy", input.name)
    XCTAssertNil(input.connection)
  }
}
