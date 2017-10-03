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
    factory = BlockFactory()
    BKYAssertDoesNotThrow {
      try factory.load(fromJSONPaths: ["all_test_blocks.json"], bundle: Bundle(for: type(of: self)))
    }

    super.setUp()
  }

  // MARK: - XML Parsing Tests

  func testParseXML_EmptyToolboxWithXMLRoot() {
    let xmlString = "<xml></xml>"
    guard let toolbox = BKYAssertDoesNotThrow({
      try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
    }) else
    {
      XCTFail("Could not create toolbox")
      return
    }

    XCTAssertEqual(0, toolbox.categories.count)
  }

  func testParseXML_EmptyToolboxWithToolboxRoot() {
    let xmlString = "<toolbox></toolbox>"
    guard let toolbox = BKYAssertDoesNotThrow({
      try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
    }) else
    {
      XCTFail("Could not create toolbox")
      return
    }

    XCTAssertEqual(0, toolbox.categories.count)
  }

  func testParseXML_EmptyCategory() {
    let xmlString = "<xml><category name='abc' colour='180'></category></xml>"
    guard let toolbox = BKYAssertDoesNotThrow({
      try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
    }) else
    {
      XCTFail("Could not create toolbox")
      return
    }

    XCTAssertEqual(1, toolbox.categories.count)
    XCTAssertEqual("abc", toolbox.categories[0].name)
    XCTAssertEqual(0.5, toolbox.categories[0].color.bky_hsba().hue,
      accuracy: TestConstants.ACCURACY_CGF)
  }

  func testParseXML_EmptyCategoryWithRGBColor() {
    let xmlString = "<xml><category name='abc' colour='#ff0000'></category></xml>"
    guard let toolbox = BKYAssertDoesNotThrow({
        try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
      }) else
    {
      XCTFail("Could not create toolbox")
      return
    }

    XCTAssertEqual(1, toolbox.categories.count)
    XCTAssertEqual("abc", toolbox.categories[0].name)
    let rgba = toolbox.categories[0].color.bky_rgba()
    XCTAssertEqual(1.0, rgba.red, accuracy: TestConstants.ACCURACY_CGF)
    XCTAssertEqual(0.0, rgba.green, accuracy: TestConstants.ACCURACY_CGF)
    XCTAssertEqual(0.0, rgba.blue, accuracy: TestConstants.ACCURACY_CGF)
    XCTAssertEqual(1.0, rgba.alpha, accuracy: TestConstants.ACCURACY_CGF)
  }

  func testParseXML_EmptyCategoriesUsingMessages() {
    // Load messages
    MessageManager.shared.loadMessages([
      "CATEGORY_NAME": "Empty category",
      "COLOUR": "#00ff00"
    ])

    let xmlString =
      "<xml>" +
        "<category name='%{CATEGORY_NAME}' colour='%{COLOUR}'></category>" +
        "<category name='%{NO_CATEGORY_KEY}' colour='%{NO_COLOUR_KEY}'></category>" +
      "</xml>"
    guard let toolbox = BKYAssertDoesNotThrow({
      try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
    }) else
    {
      XCTFail("Could not create toolbox")
      return
    }

    XCTAssertEqual(2, toolbox.categories.count)
    XCTAssertEqual("Empty category", toolbox.categories[0].name)
    let rgba = toolbox.categories[0].color.bky_rgba()
    XCTAssertEqual(0.0, rgba.red, accuracy: TestConstants.ACCURACY_CGF)
    XCTAssertEqual(1.0, rgba.green, accuracy: TestConstants.ACCURACY_CGF)
    XCTAssertEqual(0.0, rgba.blue, accuracy: TestConstants.ACCURACY_CGF)
    XCTAssertEqual(1.0, rgba.alpha, accuracy: TestConstants.ACCURACY_CGF)

    // Since no messages exist for the keys in the second category, the name should be the
    // original key and the colour should be black.
    XCTAssertEqual("%{NO_CATEGORY_KEY}", toolbox.categories[1].name)
    let rgba2 = toolbox.categories[1].color.bky_rgba()
    XCTAssertEqual(0.0, rgba2.red, accuracy: TestConstants.ACCURACY_CGF)
    XCTAssertEqual(0.0, rgba2.green, accuracy: TestConstants.ACCURACY_CGF)
    XCTAssertEqual(0.0, rgba2.blue, accuracy: TestConstants.ACCURACY_CGF)
    XCTAssertEqual(0.0, rgba2.alpha, accuracy: TestConstants.ACCURACY_CGF)
  }
  
  func testParseXML_TwoCategory() {
    let xmlString =
      "<xml>" +
        "<category name='cat1'></category>" +
        "<category name='cat2'></category>" +
      "</xml>"
    guard let toolbox = BKYAssertDoesNotThrow({
      try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
    }) else
    {
      XCTFail("Could not create toolbox")
      return
    }

    XCTAssertEqual(2, toolbox.categories.count)
    XCTAssertEqual("cat1", toolbox.categories[0].name)
    XCTAssertEqual("cat2", toolbox.categories[1].name)
  }

  func testParseXML_SimpleCategorizedBlock() {
    let xmlString =
    "<xml>" +
      "<category name='cat1'><block type='multiple_input_output'></block></category>" +
    "</xml>"
    guard let toolbox = BKYAssertDoesNotThrow({
      try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
    }) else
    {
      XCTFail("Could not create toolbox")
      return
    }

    XCTAssertEqual(1, toolbox.categories.count)
    XCTAssertEqual(1, toolbox.categories[0].items.count)
    XCTAssertEqual("multiple_input_output", toolbox.categories[0].items[0].rootBlock?.name)
  }

  func testParseXML_SimpleUncategorizedBlocks() {
    let xmlString =
      "<xml>" +
        "<block type='block_output'></block>" +
        "<block type='block_output'></block>" +
      "</xml>"
    guard let toolbox = BKYAssertDoesNotThrow({
      try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
    }) else
    {
      XCTFail("Could not create toolbox")
      return
    }

    XCTAssertEqual(1, toolbox.categories.count)
    XCTAssertEqual(2, toolbox.categories[0].items.count)
    XCTAssertEqual("block_output", toolbox.categories[0].items[0].rootBlock?.name)
    XCTAssertEqual("block_output", toolbox.categories[0].items[1].rootBlock?.name)
  }

  func testParseXML_TwoCategorizedBlocksWithGaps() {
    let xmlString =
    "<xml>" +
      "<category name='cat1'>" +
        "<block type='block_output'></block>" +
        "<sep gap='10' />" +
        "<block type='block_statement'></block>" +
        "<sep></sep>" +
      "</category>" +
    "</xml>"
    guard let toolbox = BKYAssertDoesNotThrow({
      try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
    }) else
    {
      XCTFail("Could not create toolbox")
      return
    }

    XCTAssertEqual(1, toolbox.categories.count)

    let category = toolbox.categories[0]
    XCTAssertEqual(4, category.items.count)
    XCTAssertEqual("block_output", category.items[0].rootBlock?.name)
    XCTAssertEqual(10, category.items[1].gap)
    XCTAssertEqual("block_statement", category.items[2].rootBlock?.name)
    XCTAssertNotNil(category.items[3].gap)
  }

  func testParseXML_TwoUncategorizedBlocksWithGaps() {
    let xmlString =
      "<xml>" +
        "<block type='block_output'></block>" +
        "<sep gap='10' />" +
        "<block type='block_statement'></block>" +
        "<sep></sep>" +
    "</xml>"
    guard let toolbox = BKYAssertDoesNotThrow({
      try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
    }) else
    {
      XCTFail("Could not create toolbox")
      return
    }

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
    "<xml>" +
      "<category name='cat1'>" +
        "<block type='controls_repeat_ext'>" +
          "<value name='TIMES'>" +
            "<block type='math_number'><field name='NUM'>10</field></block>" +
          "</value>" +
        "</block>" +
      "</category>" +
    "</xml>"
    guard let toolbox = BKYAssertDoesNotThrow({
      try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
    }) else
    {
      XCTFail("Could not create toolbox")
      return
    }

    XCTAssertEqual(1, toolbox.categories.count)
    XCTAssertEqual(2, toolbox.categories[0].allBlocks.count)
    XCTAssertEqual(1, toolbox.categories[0].items.count)

    let loopBlock = toolbox.categories[0].items[0].rootBlock
    XCTAssertEqual("controls_repeat_ext", loopBlock?.name)
    XCTAssertEqual("math_number", loopBlock?.firstInput(withName: "TIMES")?.connectedBlock?.name)
  }

  func testParseXML_BadXML() {
    do {
      let xmlString = "<toolboxa></toolboxa>"
      _ = try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
      XCTFail("Toolbox was parsed successfully from bad XML: '\(xmlString)'")
    } catch let error as BlocklyError {
      XCTAssertEqual(BlocklyError.Code.xmlParsing.rawValue, error.code)
    } catch let error {
      XCTFail("Caught unexpected error: \(error)")
    }
  }

  func testParseXML_BadXML_CategoriesAndUncategorizedBlocks() {
    do {
      let xmlString =
        "<xml>" +
          "<category><block type='block_output'></block></category>" +
          "<block type='block_output'></block>" +
        "</xml>"
      _ = try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
      XCTFail("Toolbox was parsed successfully from bad XML: '\(xmlString)'")
    } catch let error as BlocklyError {
      XCTAssertEqual(BlocklyError.Code.xmlParsing.rawValue, error.code)
    } catch let error {
      XCTFail("Caught unexpected error: \(error)")
    }
  }

  func testParseXML_UnknownBlock() {
    do {
      let xmlString = "<xml><category><block type='unknownblock'></block></category></xml>"
      _ = try Toolbox.makeToolbox(xmlString: xmlString, factory: factory)
      XCTFail("Toolbox was parsed successfully from bad XML: '\(xmlString)'")
    } catch let error as BlocklyError {
      XCTAssertEqual(BlocklyError.Code.xmlUnknownBlock.rawValue, error.code)
    } catch let error {
      XCTFail("Caught unexpected error: \(error)")
    }
  }
}
