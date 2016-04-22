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
import AEXML

class ToolboxXMLTest: XCTestCase {

  var factory: BlockFactory!

  override func setUp() {
    factory = try! BlockFactory(jsonPath: "all_test_blocks.json",
      bundle: NSBundle(forClass: self.dynamicType))

    super.setUp()
  }

  // MARK: - XML Parsing Tests

  func testParseXML_EmptyToolbox() {
    let xmlString = "<toolbox></toolbox>"
    let toolbox = try! Toolbox.toolboxFromXMLString(xmlString, factory: factory)

    XCTAssertEqual(0, toolbox.categories.count)
  }

  func testParseXML_EmptyCategory() {
    let xmlString = "<toolbox><category name='abc' colour='180'></category></toolbox>"
    let toolbox = try! Toolbox.toolboxFromXMLString(xmlString, factory: factory)

    XCTAssertEqual(1, toolbox.categories.count)
    XCTAssertEqual("abc", toolbox.categories[0].name)
    XCTAssertEqualWithAccuracy(0.5, toolbox.categories[0].color.bky_hsba().hue,
      accuracy: TestConstants.ACCURACY_CGF)
  }

  func testParseXML_TwoCategory() {
    let xmlString =
      "<toolbox>" +
        "<category name='cat1'></category>" +
        "<category name='cat2'></category>" +
      "</toolbox>"
    let toolbox = try! Toolbox.toolboxFromXMLString(xmlString, factory: factory)

    XCTAssertEqual(2, toolbox.categories.count)
    XCTAssertEqual("cat1", toolbox.categories[0].name)
    XCTAssertEqual("cat2", toolbox.categories[1].name)
  }

  func testParseXML_SimpleBlock() {
    let xmlString =
    "<toolbox>" +
      "<category name='cat1'><block type='multiple_input_output'></block></category>" +
    "</toolbox>"
    let toolbox = try! Toolbox.toolboxFromXMLString(xmlString, factory: factory)

    XCTAssertEqual(1, toolbox.categories.count)
    XCTAssertEqual(1, toolbox.categories[0].allBlocks.count)
    XCTAssertEqual("multiple_input_output", toolbox.categories[0].topLevelBlocks()[0].name)
  }

  func testParseXML_TwoBlocks() {
    let xmlString =
    "<toolbox>" +
      "<category name='cat1'>" +
        "<block type='block_output'></block>" +
        "<block type='block_statement'></block>" +
      "</category>" +
    "</toolbox>"
    let toolbox = try! Toolbox.toolboxFromXMLString(xmlString, factory: factory)

    XCTAssertEqual(1, toolbox.categories.count)
    XCTAssertEqual(2, toolbox.categories[0].allBlocks.count)
    XCTAssertEqual("block_output", toolbox.categories[0].topLevelBlocks()[0].name)
    XCTAssertEqual("block_statement", toolbox.categories[0].topLevelBlocks()[1].name)
  }

  func testParseXML_NestedBlocks() {
    let xmlString =
    "<toolbox>" +
      "<category name='cat1'>" +
        "<block type='controls_repeat_ext'>" +
          "<value name='TIMES'>" +
            "<block type='math_number'><field name='NUM'>10</field></block>" +
          "</value>" +
        "</block>" +
      "</category>" +
    "</toolbox>"
    let toolbox = try! Toolbox.toolboxFromXMLString(xmlString, factory: factory)

    XCTAssertEqual(1, toolbox.categories.count)
    XCTAssertEqual(2, toolbox.categories[0].allBlocks.count)
    XCTAssertEqual(1, toolbox.categories[0].topLevelBlocks().count)

    let loopBlock = toolbox.categories[0].topLevelBlocks()[0]
    XCTAssertEqual("controls_repeat_ext", loopBlock.name)
    XCTAssertEqual("math_number", loopBlock.firstInputWithName("TIMES")?.connectedBlock?.name)
  }

  func testParseXML_BadXML() {
    do {
      let xmlString = "<toolboxa></toolboxa>"
      try Toolbox.toolboxFromXMLString(xmlString, factory: factory)
      XCTFail("Toolbox was parsed successfully from bad XML: '\(xmlString)'")
    } catch let error as BlocklyError {
      XCTAssertEqual(BlocklyError.Code.XMLParsing.rawValue, error.code)
    } catch let error as NSError {
      XCTFail("Caught unexpected error: \(error)")
    }
  }

  func testParseXML_UnknownBlock() {
    do {
      let xmlString = "<toolbox><category><block id='unknownblock'></block></category></toolbox>"
      try Toolbox.toolboxFromXMLString(xmlString, factory: factory)
      XCTFail("Toolbox was parsed successfully from bad XML: '\(xmlString)'")
    } catch let error as BlocklyError {
      XCTAssertEqual(BlocklyError.Code.XMLUnknownBlock.rawValue, error.code)
    } catch let error as NSError {
      XCTFail("Caught unexpected error: \(error)")
    }
  }
}
