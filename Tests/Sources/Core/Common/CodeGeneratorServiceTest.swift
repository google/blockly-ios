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
        "blockly_web/blockly_compressed.js",
        /// The JS file containing a list of internationalized messages
        "blockly_web/msg/js/en.js",
      ], bundle: testBundle)

    // Create the block factory
    _blockFactory = BlockFactory()
  }

  // MARK: - Tests

  func testPythonCodeGeneration() {
    _blockFactory.load(fromDefaultFiles: [.loopDefault, .mathDefault])

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
      let fieldNumber = loopValueBlock.firstField(withName: "NUM") as? FieldNumber else
    {
      XCTFail("Could not build blocks")
      return
    }
    BKYAssertDoesNotThrow { () -> Void in
      fieldNumber.value = 10
      try parentInput.connection?.connectTo(loopValueBlock.inferiorConnection)
      try workspace.addBlockTree(loopBlock)
    }

    // Set up timeout expectation
    let expectation = self.expectation(description: "Code Generation")

    // Set builder
    let testBundle = Bundle(for: type(of: self))
    let builder = CodeGeneratorServiceRequestBuilder(jsGeneratorObject: "Blockly.Python")
    builder.addJSBlockGeneratorFiles(["blockly_web/python_compressed.js"], bundle: testBundle)
    builder.addJSONBlockDefinitionFiles(fromDefaultFiles: .allDefault)
    _codeGeneratorService.setRequestBuilder(builder, shouldCache: false)

    let abc = ""

    // Execute request
    let _ = BKYAssertDoesNotThrow {
      try _codeGeneratorService.generateCode(
        forWorkspace: workspace,
        onCompletion: { _, code in
          XCTAssertEqual("for count in range(10):  pass",
                         code.replacingOccurrences(of: "\n", with: ""))
          expectation.fulfill()
        }, onError: { _, error in
          XCTFail("Error occurred during code generation: \(error)")
          expectation.fulfill()
      })
    }

    // Wait 10s for code generation to finish
    waitForExpectations(timeout: 10.0, handler: { error in
      if let error = error {
        XCTFail("Code generation timed out: \(error)")
      }
    })
  }

  func testPythonCodeGenerationWithManyRequests() {
    _blockFactory.load(fromDefaultFiles: [.loopDefault, .mathDefault])

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
      let fieldInput = loopValueBlock.firstField(withName: "NUM") as? FieldNumber else
    {
      XCTFail("Could not build blocks")
      return
    }
    BKYAssertDoesNotThrow { () -> Void in
      fieldInput.value = 10
      try parentInput.connection?.connectTo(loopValueBlock.inferiorConnection)
      try workspace.addBlockTree(loopBlock)
    }

    let testBundle = Bundle(for: type(of: self))

    for _ in 0 ..< 100 {
      // Set up timeout expectation
      let expectation = self.expectation(description: "Code Generation")

      // Set builder
      let builder = CodeGeneratorServiceRequestBuilder(jsGeneratorObject: "Blockly.Python")
      builder.addJSBlockGeneratorFiles(["blockly_web/python_compressed.js"], bundle: testBundle)
      builder.addJSONBlockDefinitionFiles(fromDefaultFiles: .allDefault)
      _codeGeneratorService.setRequestBuilder(builder, shouldCache: true)

      // Execute request
      let _ = BKYAssertDoesNotThrow {
        try _codeGeneratorService.generateCode(
          forWorkspace: workspace,
          onCompletion: { _, code in
            XCTAssertEqual("for count in range(10):  pass",
                           code.replacingOccurrences(of: "\n", with: ""))
            expectation.fulfill()
          }, onError: { _, error in
            XCTFail("Error occurred during code generation: \(error)")
            expectation.fulfill()
          })
      }
    }

    // Wait 100s for code generation to finish
    waitForExpectations(timeout: 100.0, handler: { error in
      if let error = error {
        XCTFail("Code generation timed out: \(error)")
      }
    })
  }

  func testJSCodeGenerationWithCustomDefinitions() {
    let testBundle = Bundle(for: type(of: self))

    // Load custom block into block factory
    BKYAssertDoesNotThrow {
      try _blockFactory.load(fromJSONPaths: ["code_generator_blocks.json"], bundle: testBundle)
    }

    // Build workspace with the custom colour block
    let workspace = Workspace()
    guard
      let colorBlock = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "custom_colour_block")
      }),
      let fieldColor = colorBlock.firstField(withName: "COLOUR") as? FieldColor else
    {
      XCTFail("Could not build block")
      return
    }

    guard let color = ColorHelper.makeColor(rgb: "abcdef") else {
      XCTFail("Could not create color")
      return
    }
    fieldColor.color = color

    BKYAssertDoesNotThrow {
      try workspace.addBlockTree(colorBlock)
    }

    // Set up timeout expectation
    let expectation = self.expectation(description: "Code Generation")

    // Set builder
    let builder = CodeGeneratorServiceRequestBuilder(jsGeneratorObject: "Blockly.JavaScript")
    builder.addJSBlockGeneratorFiles(["blockly_web/javascript_compressed.js",
                                  "code_generator_generators.js"],
                                 bundle: testBundle)
    builder.addJSONBlockDefinitionFiles(fromDefaultFiles: .allDefault)
    builder.addJSONBlockDefinitionFiles(["code_generator_blocks.json"], bundle: testBundle)
    _codeGeneratorService.setRequestBuilder(builder, shouldCache: false)

    // Execute request
    let _ = BKYAssertDoesNotThrow {
      try _codeGeneratorService.generateCode(
        forWorkspace: workspace,
        onCompletion: { _, code in
          XCTAssertEqual("#abcdef", code)
          expectation.fulfill()
        }, onError: { _, error in
          XCTFail("Error occurred during code generation: \(error)")
          expectation.fulfill()
        })
    }

    // Wait 10s for code generation to finish
    waitForExpectations(timeout: 10.0, handler: { error in
      if let error = error {
        XCTFail("Code generation timed out: \(error)")
      }
    })
  }

  func testJSCodeGenerationWithMutators() {
    _blockFactory.load(fromDefaultFiles: [.logicDefault])

    // Build workspace with if/else-if block
    let workspace = Workspace()
    guard
      let ifBlock = BKYAssertDoesNotThrow({ () -> Block in 
        let block = try self._blockFactory.makeBlock(name: "controls_if")

        if let mutatorIfElse = block.mutator as? MutatorIfElse {
          mutatorIfElse.elseIfCount = 2
          try mutatorIfElse.mutateBlock()
        }

        return block
      }),
      let booleanBlock = BKYAssertDoesNotThrow({
        try self._blockFactory.makeBlock(name: "logic_boolean")
      }),
      let elseIfInput = ifBlock.firstInput(withName: "IF2"),
      let fieldBool = booleanBlock.firstField(withName: "BOOL") as? FieldDropdown else
    {
      XCTFail("Could not build blocks")
      return
    }

    BKYAssertDoesNotThrow { () -> Void in
      if let index = fieldBool.options.index(where: { $0.displayName == "true" }) {
        fieldBool.selectedIndex = index
      } else {
        XCTFail("Could not find `true` value on boolean block.")
      }
      try elseIfInput.connection?.connectTo(booleanBlock.inferiorConnection)
      try workspace.addBlockTree(ifBlock)
    }

    // Set up timeout expectation
    let expectation = self.expectation(description: "Code Generation")

    // Set builder
    let testBundle = Bundle(for: type(of: self))
    let builder = CodeGeneratorServiceRequestBuilder(jsGeneratorObject: "Blockly.JavaScript")
    builder.addJSBlockGeneratorFiles(["blockly_web/javascript_compressed.js"], bundle: testBundle)
    builder.addJSONBlockDefinitionFiles(fromDefaultFiles: [.logicDefault])
    _codeGeneratorService.setRequestBuilder(builder, shouldCache: false)

    // Execute request
    let _ = BKYAssertDoesNotThrow {
      try _codeGeneratorService.generateCode(
        forWorkspace: workspace,
        onCompletion: { _, code in
          XCTAssertEqual("if (false) {} else if (false) {} else if (true) {}",
                         code.replacingOccurrences(of: "\n", with: ""))
          expectation.fulfill()
      }, onError: { _, error in
        XCTFail("Error occurred during code generation: \(error)")
        expectation.fulfill()
      })
    }

    // Wait 10s for code generation to finish
    waitForExpectations(timeout: 10.0, handler: { error in
      if let error = error {
        XCTFail("Code generation timed out: \(error)")
      }
    })
  }
}
