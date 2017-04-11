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
    factory = BlockFactory()
    BKYAssertDoesNotThrow {
      try factory.load(fromJSONPaths: ["xml_parsing_test.json"], bundle: Bundle(for: type(of: self)))
    }

    super.setUp()
  }

  // MARK: - XML Parsing Tests

  func testParseXML_SimpleBlock() {
    let xml = assembleWorkspace(BlockTestStrings.SIMPLE_BLOCK)
    try! workspace.loadBlocks(fromXMLString: xml, factory: factory)
    XCTAssertEqual(1, workspace.allBlocks.count)
  }

  func testParseXML_NestedBlocks() {
    let nestedBlockXML = BlockTestStrings.assembleBlock(BlockTestStrings.VALUE_GOOD)
    let xml = assembleWorkspace(nestedBlockXML)
    try! workspace.loadBlocks(fromXMLString: xml, factory: factory)
    XCTAssertEqual(2, workspace.allBlocks.count)
  }

  func testParseXML_MultipleBlocksWithUniqueUUID() {
    let blocks = [
      BlockTestStrings.SIMPLE_BLOCK,
      BlockTestStrings.NO_BLOCK_ID,
      BlockTestStrings.NO_BLOCK_POSITION,
      BlockTestStrings.assembleBlock(BlockTestStrings.FIELD_HAS_NAME)
    ]
    let xml = assembleWorkspace(blocks.joined(separator: ""))
    try! workspace.loadBlocks(fromXMLString: xml, factory: factory)
    XCTAssertEqual(4, workspace.allBlocks.count)
  }

  func testParseXML_MultipleBlocksWithSameUUID() {
    do {
      let blocks = [
      BlockTestStrings.SIMPLE_BLOCK,
      BlockTestStrings.SIMPLE_BLOCK,
      ]
      let xml = assembleWorkspace(blocks.joined(separator: ""))
      try workspace.loadBlocks(fromXMLString: xml, factory: factory)
      XCTFail("Should not have been able to add blocks with the same uuid")
    } catch {
      // Success!
    }
  }

  func testParseXML_EmptyXMLNormalEndTag() {
    let xml = assembleWorkspace("")
    try! workspace.loadBlocks(fromXMLString: xml, factory: factory)
    XCTAssertEqual(0, workspace.allBlocks.count)
  }

  func testParseXML_EmptyXMLAbbreviatedEndTag() {
    let xml = "\r\n<xml xmlns=\"http://www.w3.org/1999/xhtml\" />"
    try! workspace.loadBlocks(fromXMLString: xml, factory: factory)
    XCTAssertEqual(0, workspace.allBlocks.count)
  }

  func testParseXML_BadXML() {
    do {
      let xml = assembleWorkspace("<ty\"xmlahsdjkf<><J><JJ>Ji23j.,zxcj123.;;.?>?.//>?..<><")
      try workspace.loadBlocks(fromXMLString: xml, factory: factory)
      XCTFail("Should not have been able to load bad xml")
    } catch {
      // Success!
    }

    do {
      let xml = assembleWorkspace("<type=\"xml_no_name\">")
      try workspace.loadBlocks(fromXMLString: xml, factory: factory)
      XCTFail("Should not have been able to load bad xml")
    } catch {
      // Success!
    }
  }

  // MARK: - XML Serialization Tests

  func testSerializeXML_EmptyWorkspace() {
    let workspace = Workspace()
    let xml = try! workspace.toXMLDocument()

    // Expected: <xml xmlns="http://www.w3.org/1999/xhtml" />
    XCTAssertEqual("xml", xml.root.name)
    XCTAssertEqual(1, xml.root.attributes.count)
    XCTAssertEqual("http://www.w3.org/1999/xhtml", xml.root.attributes["xmlns"])
    XCTAssertEqual(0, xml.root.children.count)
  }

  func testSerializeXML_OneBlock() {
    let workspace = Workspace()
    let block = try! BlockBuilder(name: "test").makeBlock(uuid: "12345")
    try! workspace.addBlockTree(block)
    let xml = try! workspace.toXMLDocument()

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
    let block1 = try! BlockBuilder(name: "test1").makeBlock(uuid: "100")
    let block2 = try! BlockBuilder(name: "test2").makeBlock(uuid: "200")
    try! workspace.addBlockTree(block1)
    try! workspace.addBlockTree(block2)
    let xml = try! workspace.toXMLDocument()

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

  func testSerializeXML_NestedBlocks() {
    guard
      let parent = BKYAssertDoesNotThrow({
        try self.factory.makeBlock(name: "simple_input_output", shadow: false, uuid: "parentBlock")
      }),
      let child = BKYAssertDoesNotThrow({
        try self.factory.makeBlock(name: "output_no_input", shadow: false, uuid: "childBlock")
      }),
      let parentInput = parent.firstInput(withName: "value") else
    {
      XCTFail("Could not build blocks")
      return
    }
    BKYAssertDoesNotThrow { try parentInput.connection?.connectTo(child.inferiorConnection) }

    let workspace = Workspace()
    BKYAssertDoesNotThrow { try workspace.addBlockTree(parent) }
    guard let xml = BKYAssertDoesNotThrow({ try workspace.toXMLDocument() }) else {
      XCTFail("Could not build XML")
      return
    }

    // Expected:
    // <xml xmlns="http://www.w3.org/1999/xhtml">
    // <block x="0" id="parentBlock" y="0" type="simple_input_output">
    //   <value name="value">
    //     <block id="childBlock" type="output_no_input" />
    //   </value>
    // </block>
    // </xml>

    XCTAssertEqual("xml", xml.root.name)
    XCTAssertEqual(1, xml.root.attributes.count)
    XCTAssertEqual("http://www.w3.org/1999/xhtml", xml.root.attributes["xmlns"])
    XCTAssertEqual(1, xml.root.children.count)

    let parentBlockXML = xml.root["block"]
    XCTAssertEqual(1, xml.root["block"].all?.count)
    XCTAssertEqual("parentBlock", parentBlockXML.attributes["id"])
    XCTAssertEqual(1, parentBlockXML.children.count)

    if parentBlockXML.children.count >= 1 {
      let childBlockXML = parentBlockXML.children[0]["block"]
      XCTAssertEqual("childBlock", childBlockXML.attributes["id"])
    }
  }

  // MARK: - Helper methods

  fileprivate func assembleWorkspace(_ interiorXML: String) -> String {
    return "<xml xmlns=\"http://www.w3.org/1999/xhtml\">\(interiorXML)</xml>"
  }
}
