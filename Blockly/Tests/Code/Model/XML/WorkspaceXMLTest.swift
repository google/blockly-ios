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

class WorkspaceXMLTest: XCTestCase {
  var workspace: Workspace!
  var factory: BlockFactory!

  // MARK: - Setup

  override func setUp() {
    workspace = Workspace()
    factory =
      try! BlockFactory(jsonPath: "xml_parsing_test", bundle: NSBundle(forClass: self.dynamicType))

    super.setUp()
  }

  // MARK: - XML Parsing Tests

  func testParseXML_SimpleBlock() {
    let xml = assembleWorkspace(BlockTestStrings.SIMPLE_BLOCK)
    try! workspace.loadBlocksFromXMLString(xml, factory: factory)
    XCTAssertEqual(1, workspace.allBlocks.count)
  }

  func testParseXML_NestedBlocks() {
    let nestedBlockXML = BlockTestStrings.assembleBlock(BlockTestStrings.VALUE_GOOD)
    let xml = assembleWorkspace(nestedBlockXML)
    try! workspace.loadBlocksFromXMLString(xml, factory: factory)
    XCTAssertEqual(2, workspace.allBlocks.count)
  }

  func testParseXML_MultipleBlocksWithUniqueUUID() {
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

  func testParseXML_MultipleBlocksWithSameUUID() {
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

  func testParseXML_EmptyXMLNormalEndTag() {
    let xml = assembleWorkspace("")
    try! workspace.loadBlocksFromXMLString(xml, factory: factory)
    XCTAssertEqual(0, workspace.allBlocks.count)
  }

  func testParseXML_EmptyXMLAbbreviatedEndTag() {
    let xml = "\r\n<xml xmlns=\"http://www.w3.org/1999/xhtml\" />"
    try! workspace.loadBlocksFromXMLString(xml, factory: factory)
    XCTAssertEqual(0, workspace.allBlocks.count)
  }

  func testParseXML_BadXML() {
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

  // MARK: - XML Serialization Tests

  func testSerializeXML_EmptyWorkspace() {
    let workspace = Workspace()
    let xml = try! workspace.toXML()

    // Expected: <xml xmlns="http://www.w3.org/1999/xhtml" />
    XCTAssertEqual("xml", xml.root.name)
    XCTAssertEqual(1, xml.root.attributes.count)
    XCTAssertEqual("http://www.w3.org/1999/xhtml", xml.root.attributes["xmlns"])
    XCTAssertEqual(0, xml.root.children.count)
  }

  func testSerializeXML_OneBlock() {
    let workspace = Workspace()
    let block = try! Block.Builder(name: "test").build(uuid: "12345")
    try! workspace.addBlockTree(block)
    let xml = try! workspace.toXML()

    // Expected:
    // <xml xmlns="http://www.w3.org/1999/xhtml">
    //   <block name="test" id="12345" x="0" y="0"/>
    // </xml>
    XCTAssertEqual("xml", xml.root.name)
    XCTAssertEqual(1, xml.root.attributes.count)
    XCTAssertEqual("http://www.w3.org/1999/xhtml", xml.root.attributes["xmlns"])
    XCTAssertEqual(1, xml.root.children.count)

    if xml.root.children.count >= 1 {
      let blockXML = xml.root.children[0]
      XCTAssertEqual("block", blockXML.name)
      XCTAssertEqual(4, blockXML.attributes.count)
      XCTAssertEqual("test", blockXML.attributes["type"])
      XCTAssertEqual("12345", blockXML.attributes["id"])
      XCTAssertEqual("0", blockXML.attributes["x"])
      XCTAssertEqual("0", blockXML.attributes["y"])
    }
  }

  func testSerializeXML_MultipleBlocks() {
    let workspace = Workspace()
    let block1 = try! Block.Builder(name: "test1").build(uuid: "100")
    let block2 = try! Block.Builder(name: "test2").build(uuid: "200")
    try! workspace.addBlockTree(block1)
    try! workspace.addBlockTree(block2)
    let xml = try! workspace.toXML()

    // Expected:
    // <xml xmlns="http://www.w3.org/1999/xhtml">
    //   <block name="test1" id="100" x="0" y="0"/>
    //   <block name="test2" id="200" x="0" y="0"/>
    // </xml>
    XCTAssertEqual("xml", xml.root.name)
    XCTAssertEqual(1, xml.root.attributes.count)
    XCTAssertEqual("http://www.w3.org/1999/xhtml", xml.root.attributes["xmlns"])
    XCTAssertEqual(2, xml.root.children.count)
    XCTAssertEqual(2, xml.root["block"].all?.count)
  }

  // MARK: - Helper methods

  private func assembleWorkspace(interiorXML: String) -> String {
    return "<xml xmlns=\"http://www.w3.org/1999/xhtml\">\(interiorXML)</xml>"
  }
}
