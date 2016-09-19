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
      bundle: Bundle(for: type(of: self)))

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
    XCTAssertEqual(1, toolbox.categories[0].items.count)
    XCTAssertEqual("multiple_input_output", toolbox.categories[0].items[0].rootBlock?.name)
  }

  func testParseXML_TwoBlocksWithGaps() {
    let xmlString =
    "<toolbox>" +
      "<category name='cat1'>" +
        "<block type='block_output'></block>" +
        "<sep gap='10' />" +
        "<block type='block_statement'></block>" +
        "<sep></sep>" +
      "</category>" +
    "</toolbox>"
    let toolbox = try! Toolbox.toolboxFromXMLString(xmlString, factory: factory)

    XCTAssertEqual(1, toolbox.categories.count)

    let category = toolbox.categories[0]
    XCTAssertEqual(4, category.items.count)
    XCTAssertEqual("block_output", category.items[0].rootBlock?.name)
    XCTAssertEqual(10, category.items[1].gap)
    XCTAssertEqual("block_statement", category.items[2].rootBlock?.name)
    XCTAssertNotNil(category.items[3].gap)
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
    XCTAssertEqual(1, toolbox.categories[0].items.count)

    let loopBlock = toolbox.categories[0].items[0].rootBlock
    XCTAssertEqual("controls_repeat_ext", loopBlock?.name)
    XCTAssertEqual("math_number", loopBlock?.firstInputWithName("TIMES")?.connectedBlock?.name)
  }

  func testParseXML_BadXML() {
    do {
      let xmlString = "<toolboxa></toolboxa>"
      _ = try Toolbox.toolboxFromXMLString(xmlString, factory: factory)
      XCTFail("Toolbox was parsed successfully from bad XML: '\(xmlString)'")
    } catch let error as BlocklyError {
      XCTAssertEqual(BlocklyError.Code.xmlParsing.rawValue, error.code)
    } catch let error as NSError {
      XCTFail("Caught unexpected error: \(error)")
    }
  }

  func testParseXML_UnknownBlock() {
    do {
      let xmlString = "<toolbox><category><block id='unknownblock'></block></category></toolbox>"
      _ = try Toolbox.toolboxFromXMLString(xmlString, factory: factory)
      XCTFail("Toolbox was parsed successfully from bad XML: '\(xmlString)'")
    } catch let error as BlocklyError {
      XCTAssertEqual(BlocklyError.Code.xmlUnknownBlock.rawValue, error.code)
    } catch let error as NSError {
      XCTFail("Caught unexpected error: \(error)")
    }
  }
}
