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

@testable import Blockly
import XCTest

class WorkspaceXMLParsingTest: XCTestCase {
  var workspace: Workspace!
  var factory: BlockFactory!

  // MARK: - Setup

  override func setUp() {
    workspace = Workspace()
    factory =
      try! BlockFactory(jsonPath: "xml_parsing_test", bundle: NSBundle(forClass: self.dynamicType))

    super.setUp()
  }

  // MARK: - Tests

  func testSimpleBlock() {
    let xml = assembleWorkspace(BlockTestStrings.SIMPLE_BLOCK)
    try! workspace.loadBlocksFromXMLString(xml, factory: factory)
    XCTAssertEqual(1, workspace.allBlocks.count)
  }

  func testNestedBlocks() {
    let nestedBlockXML = BlockTestStrings.assembleBlock(BlockTestStrings.VALUE_GOOD)
    let xml = assembleWorkspace(nestedBlockXML)
    try! workspace.loadBlocksFromXMLString(xml, factory: factory)
    XCTAssertEqual(2, workspace.allBlocks.count)
  }

  func testMultipleBlocksWithUniqueUUID() {
    let blocks = [
      BlockTestStrings.SIMPLE_BLOCK,
      BlockTestStrings.NO_BLOCK_ID,
      BlockTestStrings.NO_BLOCK_POSITION,
      BlockTestStrings.assembleBlock(BlockTestStrings.FIELD_HAS_NAME)
    ]
    let xml = assembleWorkspace(blocks.joinWithSeparator(""))
    try! workspace.loadBlocksFromXMLString(xml, factory: factory)
    XCTAssertEqual(4, workspace.allBlocks.count)
  }

  func testMultipleBlocksWithSameUUID() {
    do {
      let blocks = [
      BlockTestStrings.SIMPLE_BLOCK,
      BlockTestStrings.SIMPLE_BLOCK,
      ]
      let xml = assembleWorkspace(blocks.joinWithSeparator(""))
      try workspace.loadBlocksFromXMLString(xml, factory: factory)
      XCTFail("Should not have been able to add blocks with the same uuid")
    } catch {
      // Success!
    }
  }

  func testEmptyXmlNormalEndTag() {
    let xml = assembleWorkspace("")
    try! workspace.loadBlocksFromXMLString(xml, factory: factory)
    XCTAssertEqual(0, workspace.allBlocks.count)
  }

  func testEmptyXmlAbbreviatedEndTag() {
    let xml = "\r\n<xml xmlns=\"http://www.w3.org/1999/xhtml\" />"
    try! workspace.loadBlocksFromXMLString(xml, factory: factory)
    XCTAssertEqual(0, workspace.allBlocks.count)
  }

  func testBadXml() {
    do {
      let xml = assembleWorkspace("<ty\"xmlahsdjkf<><J><JJ>Ji23j.,zxcj123.;;.?>?.//>?..<><")
      try workspace.loadBlocksFromXMLString(xml, factory: factory)
      XCTFail("Should not have been able to load bad xml")
    } catch {
      // Success!
    }

    do {
      let xml = assembleWorkspace("<type=\"xml_no_name\">")
      try workspace.loadBlocksFromXMLString(xml, factory: factory)
      XCTFail("Should not have been able to load bad xml")
    } catch {
      // Success!
    }
  }

  // MARK: - Helper methods

  private func assembleWorkspace(interiorXML: String) -> String {
    return "<xml xmlns=\"http://www.w3.org/1999/xhtml\">\(interiorXML)</xml>"
  }
}
