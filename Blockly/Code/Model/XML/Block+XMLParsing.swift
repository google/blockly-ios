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
import SWXMLHash

extension BlocklyError {
  private convenience init(_ code: Code, _ description: String, _ xml: XMLIndexer) {
    self.init(code, "\(description)\nXML:\n\(xml)")
  }
}

// MARK: - XML Parsing

extension Block {
  // MARK: - Public

  /**
  Creates a new block and subblocks from an XML string.

  - Parameter xmlString: The string that contains this block's data.
  - Parameter factory: The BlockFactory to use to build blocks.
  - Returns: A `BlockTree` tuple of all blocks that were created.
  - Throws:
  `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
  malformed data, or contradictory data).
  */
  public class func blockTreeFromXMLString(xmlString: String, factory: BlockFactory) throws
    -> BlockTree
  {
    let xml = SWXMLHash.parse(xmlString)

    // SWXMLHash always creates a root element around xml string, so pick its first child to pass
    // into blockTreeFromXML(:,factory:).
    guard let blockXML = xml.children.first else {
      throw BlocklyError(.XMLParsing, "Invalid or missing xml: \(xmlString)")
    }

    return try blockTreeFromXML(blockXML, factory: factory)
  }

  /**
   Creates a new block and subblocks from an XML object.

   - Parameter xml: The element that contains this block's data.
   - Parameter factory: The BlockFactory to use to build blocks.
   - Returns: A `BlockTree` tuple of all blocks that were created.
   - Throws:
   `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
   malformed data, or contradictory data).
   */
  public class func blockTreeFromXML(xml: XMLIndexer, factory: BlockFactory) throws -> BlockTree {
    guard let element = xml.element else {
      throw BlocklyError(.XMLUnknownBlock, "No attributes were set for the block.", xml)
    }
    guard let type = element.attributes["type"] else {
      throw BlocklyError(.XMLUnknownBlock, "The block type may not be nil.", xml)
    }
    if type == "" {
      throw BlocklyError(.XMLUnknownBlock, "The block type may not be empty.", xml)
    }

    let id = element.attributes["id"]

    guard let block = try factory.buildBlock(type, uuid: id) else {
      throw BlocklyError(.XMLUnknownBlock, "The block type \(type) does not exist.", xml)
    }

    var allBlocks = [block]
    let formatter = NSNumberFormatter()
    if let xString = element.attributes["x"],
      let yString = element.attributes["y"],
      let x = formatter.numberFromString(xString),
      let y = formatter.numberFromString(yString)
    {
      block.position = WorkspacePointMake(CGFloat(x), CGFloat(y))
    }

    for child in xml.children {
      guard let element = child.element else {
        continue
      }
      switch element.name {
      case "value", "statement":
        let subBlockTree = try setInputOnBlock(block, fromXML: child, factory: factory)
        allBlocks.appendContentsOf(subBlockTree.allBlocks)
      case "next":
        let subBlockTree = try setNextBlockOnBlock(block, fromXML: child, factory: factory)
        allBlocks.appendContentsOf(subBlockTree.allBlocks)
      case "field":
        setFieldOnBlock(block, fromXML: child)
      default:
        bky_print("Unknown node name: \(element.name)")
      }
    }

    return BlockTree(rootBlock: block, allBlocks: allBlocks)
  }

  // MARK: - Internal

  /**
  Creates a new block from the xml and connects it to one of the block's inputs.

  - Parameter block: The block to connect to.
  - Parameter xml: The XML that describes the input and block to attach.
  - Parameter factory: The BlockFactory to use to create the new block.
  - Returns: A `BlockTree` tuple of all blocks that were created.
  - Throws:
  `BlocklyError`: Occurs if the block doesn't have that input or the xml is invalid.
  */
  private class func setInputOnBlock(block: Block, fromXML xml: XMLIndexer, factory: BlockFactory)
    throws -> BlockTree
  {
    // Figure out which connection we're connecting to
    guard let element = xml.element,
      let inputName = element.attributes["name"] else
    {
      throw BlocklyError(.XMLParsing, "Missing \"name\" attribute for input.", xml)
    }
    guard let input = block.firstInputWithName(inputName) else {
      throw BlocklyError(.XMLParsing, "Could not find input on block: \(inputName)", xml)
    }
    guard let inputConnection = input.connection else {
      throw BlocklyError(.XMLParsing, "Input has no connection.")
    }

    var subBlockTree: BlockTree!

    for child in xml.children {
      guard let name = child.element?.name else {
        continue
      }

      switch name {
        // TODO: (#340) Handle case "shadow"
      case "block":
        // Create the child block tree from xml and connect it to this input connection
        subBlockTree = try Block.blockTreeFromXML(child, factory: factory)
        try subBlockTree.rootBlock.connectToSuperiorConnection(inputConnection)
      default:
        bky_print("Unknown element: \(name)")
      }
    }

    if subBlockTree == nil {
      throw BlocklyError(.XMLParsing, "Missing block for input.", xml)
    }

    return subBlockTree
  }

  /**
   Creates a new block from the xml and connects it to this block's next connection.

   - Parameter block: The block to connect to.
   - Parameter xml: The XML that describes the block to attach.
   - Parameter factory: The BlockFactory to use to create the new block.
   - Returns: A `BlockTree` tuple of all blocks that were created.
   - Throws:
   `BlocklyError`: Occurs if the block doesn't have a next connection or the xml is invalid.
   */
  private class func setNextBlockOnBlock(block: Block, fromXML xml: XMLIndexer,
    factory: BlockFactory) throws -> BlockTree
  {
    guard let nextConnection = block.nextConnection else {
      throw BlocklyError(.XMLParsing, "Block has no next connection.")
    }

    var subBlockTree: BlockTree!

    for child in xml.children {
      guard let element = child.element else {
        continue
      }
      switch element.name {
      case "block":
        // Create the child block tree from xml and connect it to this next connection
        subBlockTree = try blockTreeFromXML(xml, factory: factory)
        try subBlockTree.rootBlock.connectToSuperiorConnection(nextConnection)
      default:
        bky_print("Unkown element: \(element.name)")
      }
    }

    if subBlockTree == nil {
      throw BlocklyError(.XMLParsing, "Missing next block.", xml)
    }

    return subBlockTree
  }

  /**
   Sets a field on a block as specified by the xml.

   - Parameter block: The block to update.
   - Parameter xml: The xml that describes the field to update.
   */
  private class func setFieldOnBlock(block: Block, fromXML xml: XMLIndexer) {
    // A missing or unknown field name isn't an error, it's just ignored.
    if let element = xml.element,
      let fieldName = element.attributes["name"],
      let value = element.text,
      let field = block.firstFieldWithName(fieldName)
    {
      field.text = value
    }
  }
}
