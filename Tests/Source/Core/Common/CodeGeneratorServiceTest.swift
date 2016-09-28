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

import Foundation
@testable import Blockly
import XCTest

/** Tests for the `CodeGeneratorService` class. */
class CodeGeneratorServiceTest: XCTestCase {

  var _codeGeneratorService: CodeGeneratorService!

  var _blockFactory: BlockFactory!

  override func setUp() {
    super.setUp()

    let testBundle = Bundle(for: type(of: self))
    // Create the code generator
    _codeGeneratorService = CodeGeneratorService(
      jsCoreDependencies: [
        /// The JS file containing the Blockly engine
        (file: "blockly_web/blockly_compressed.js", bundle: testBundle),
        /// The JS file containing all Blockly default blocks
        (file: "blockly_web/blocks_compressed.js", bundle: testBundle),
        /// The JS file containing a list of internationalized messages
        (file: "blockly_web/msg/js/en.js", bundle: testBundle),
      ])

    // Create the block factory
    _blockFactory = BlockFactory()
    BKYAssertDoesNotThrow {
      try _blockFactory.load(fromJSONPaths: ["all_test_blocks.json"], bundle: testBundle)
    }
  }

  // MARK: - Tests

  func testPythonCodeGeneration() {
    // Build workspace with simple repeat loop
    let workspace = Workspace()
    guard
      let loopBlock = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "controls_repeat_ext")
      }),
      let loopValueBlock = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "math_number")
      }),
      let parentInput = loopBlock.firstInput(withName: "TIMES"),
      let fieldInput = loopValueBlock.firstField(withName: "NUM") as? FieldInput else
    {
      XCTFail("Could not build blocks")
      return
    }
    BKYAssertDoesNotThrow { () -> Void in
      fieldInput.text = "10"
      try parentInput.connection?.connectTo(loopValueBlock.inferiorConnection)
      try workspace.addBlockTree(loopBlock)
    }

    // Set up timeout expectation
    let expectation = self.expectation(description: "Code Generation")

    // Execute request
    let testBundle = Bundle(for: type(of: self))
    guard let request = BKYAssertDoesNotThrow({
        try CodeGeneratorService.Request(workspace: workspace,
          jsGeneratorObject: "Blockly.Python",
          jsBlockGenerators: [(file: "blockly_web/python_compressed.js", bundle: testBundle)],
          jsonBlockDefinitions: [])
      }) else
    {
      XCTFail("Could not build code generation request")
      return
    }
    request.onCompletion = { code in
      XCTAssertEqual("for count in range(10):  pass",
                     code.replacingOccurrences(of: "\n", with: ""))
      expectation.fulfill()
    }
    request.onError = { error in
      XCTFail("Error occurred during code generation: \(error)")
      expectation.fulfill()
    }
    _codeGeneratorService.generateCode(forRequest: request)

    // Wait 10s for code generation to finish
    waitForExpectations(timeout: 10.0, handler: { error in
      if let error = error {
        XCTFail("Code generation timed out: \(error)")
      }
    })
  }

  func testCodeGenerationWithManyRequests() {
    // Build workspace with simple repeat loop
    let workspace = Workspace()

    guard
      let loopBlock = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "controls_repeat_ext")
      }),
      let loopValueBlock = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "math_number")
      }),
      let parentInput = loopBlock.firstInput(withName: "TIMES"),
      let fieldInput = loopValueBlock.firstField(withName: "NUM") as? FieldInput else
    {
      XCTFail("Could not build blocks")
      return
    }
    BKYAssertDoesNotThrow { () -> Void in
      fieldInput.text = "10"
      try parentInput.connection?.connectTo(loopValueBlock.inferiorConnection)
      try workspace.addBlockTree(loopBlock)
    }

    let testBundle = Bundle(for: type(of: self))

    for _ in 0 ..< 100 {
      // Set up timeout expectation
      let expectation = self.expectation(description: "Code Generation")

      // Execute request
      guard let request = BKYAssertDoesNotThrow({
        try CodeGeneratorService.Request(workspace: workspace,
          jsGeneratorObject: "Blockly.Python",
          jsBlockGenerators: [(file: "blockly_web/python_compressed.js", bundle: testBundle)],
          jsonBlockDefinitions: [])
      }) else {
        XCTFail("Could not build code generation request")
        return
      }
      request.onCompletion = { code in
        XCTAssertEqual("for count in range(10):  pass",
          code.replacingOccurrences(of: "\n", with: ""))
        expectation.fulfill()
      }
      request.onError = { error in
        XCTFail("Error occurred during code generation: \(error)")
        expectation.fulfill()
      }
      _codeGeneratorService.generateCode(forRequest: request)
    }

    // Wait 100s for code generation to finish
    waitForExpectations(timeout: 100.0, handler: { error in
      if let error = error {
        XCTFail("Code generation timed out: \(error)")
      }
    })
  }
}
