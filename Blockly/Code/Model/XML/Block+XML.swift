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
import AEXML

// MARK: - XML Parsing

extension Block {
  // MARK: - Public

  /**
   Creates a new block and subblocks from an XML object.

   - Parameter xml: The element that contains this block's data.
   - Parameter factory: The BlockFactory to use to build blocks.
   - Returns: A `BlockTree` tuple of all blocks that were created.
   - Throws:
   `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
   malformed data, or contradictory data).
   */
  public class func blockTreeFrom(xml: AEXMLElement, factory: BlockFactory) throws -> BlockTree
  {
    let lowercaseTag = xml.name.lowercased()
    guard lowercaseTag == XMLConstants.TAG_BLOCK || lowercaseTag == XMLConstants.TAG_SHADOW else {
      let errorMessage = "The block tag (\"\(xml.name)\") must be either " +
        "'\(XMLConstants.TAG_BLOCK)' or '\(XMLConstants.TAG_SHADOW)'"
      throw BlocklyError(.xmlUnknownBlock, errorMessage, xml)
    }
    guard let type = xml.attributes[XMLConstants.ATTRIBUTE_TYPE] else {
      throw BlocklyError(.xmlUnknownBlock, "The block type may not be nil.", xml)
    }
    if type == "" {
      throw BlocklyError(.xmlUnknownBlock, "The block type may not be empty.", xml)
    }

    let uuid = xml.attributes[XMLConstants.ATTRIBUTE_ID]
    let shadow = (lowercaseTag == XMLConstants.TAG_SHADOW)

    guard let block = try factory.buildBlock(name: type, uuid: uuid, shadow: shadow) else {
      throw BlocklyError(.xmlUnknownBlock, "The block type \(type) does not exist.", xml)
    }

    var allBlocks = [block]
    let formatter = NumberFormatter()
    if let xString = xml.attributes[XMLConstants.ATTRIBUTE_POSITION_X],
      let yString = xml.attributes[XMLConstants.ATTRIBUTE_POSITION_Y],
      let x = formatter.number(from: xString),
      let y = formatter.number(from: yString)
    {
      block.position = WorkspacePointMake(CGFloat(x), CGFloat(y))
    }

    for child in xml.children {
      switch child.name.lowercased() {
      case XMLConstants.TAG_INPUT_VALUE, XMLConstants.TAG_INPUT_STATEMENT:
        let blocks = try setInputOnBlock(block, fromXML: child, factory: factory)
        allBlocks.append(contentsOf: blocks)
      case XMLConstants.TAG_NEXT_STATEMENT:
        let blocks = try setNextBlockOnBlock(block, fromXML: child, factory: factory)
        allBlocks.append(contentsOf: blocks)
      case XMLConstants.TAG_FIELD:
        try setFieldOn(block: block, fromXML: child)
      case XMLConstants.TAG_COMMENT:
        if let commentText = child.value {
          block.comment = commentText
        }
      default:
        bky_print("Unknown node name: \(child.name)")
      }
    }

    return BlockTree(rootBlock: block, allBlocks: allBlocks)
  }

  // MARK: - Internal

  /**
  Creates a set of blocks from xml and connects them to one of the block's inputs.

  - Parameter block: The block to connect to.
  - Parameter xml: The XML that describes the input and blocks to attach.
  - Parameter factory: The BlockFactory used to create the new blocks.
  - Returns: An array of all `Block` instances that were created.
  - Throws:
  `BlocklyError`: Occurs if the block doesn't have that input or the xml is invalid.
  */
  private class func setInputOnBlock(
    _ block: Block, fromXML xml: AEXMLElement, factory: BlockFactory) throws -> [Block]
  {
    // Figure out which connection we're connecting to
    guard let inputName = xml.attributes[XMLConstants.ATTRIBUTE_NAME] else {
      let errorMessage = "Missing \"\(XMLConstants.ATTRIBUTE_NAME)\" attribute for input."
      throw BlocklyError(.xmlParsing, errorMessage, xml)
    }
    guard let input = block.firstInputWith(name: inputName) else {
      throw BlocklyError(.xmlParsing, "Could not find input on block: \(inputName)", xml)
    }
    guard let inputConnection = input.connection else {
      throw BlocklyError(.xmlParsing, "Input has no connection.")
    }

    var blocks = [Block]()

    for child in xml.children {
      switch child.name.lowercased() {
      case XMLConstants.TAG_BLOCK:
        // Create the child block tree from xml and connect it to this input connection's target
        let subBlockTree = try Block.blockTreeFrom(xml: child, factory: factory)
        try inputConnection.connectTo(subBlockTree.rootBlock.inferiorConnection)
        blocks.append(contentsOf: subBlockTree.allBlocks)
      case XMLConstants.TAG_SHADOW:
        // Create the child block tree from xml and connect it to this input connection's shadow
        let subBlockTree = try Block.blockTreeFrom(xml: child, factory: factory)
        try inputConnection.connectShadowTo(subBlockTree.rootBlock.inferiorConnection)
        blocks.append(contentsOf: subBlockTree.allBlocks)
      default:
        bky_print("Unknown element: \(child.name)")
      }
    }

    if blocks.count == 0 {
      throw BlocklyError(.xmlParsing, "Missing block for input.", xml)
    }

    return blocks
  }

  /**
   Creates a set of blocks from xml and connects them to this block's next connection.

   - Parameter block: The block to connect to.
   - Parameter xml: The XML that describes the blocks to attach.
   - Parameter factory: The BlockFactory to use to create the new blocks.
   - Returns: An array of all `Block` instances that were created.
   - Throws:
   `BlocklyError`: Occurs if the block doesn't have a next connection or the xml is invalid.
   */
  private class func setNextBlockOnBlock(
    _ block: Block, fromXML xml: AEXMLElement, factory: BlockFactory) throws -> [Block]
  {
    guard let nextConnection = block.nextConnection else {
      throw BlocklyError(.xmlParsing, "Block has no next connection.")
    }

    var blocks = [Block]()

    for child in xml.children {
      switch child.name.lowercased() {
      case XMLConstants.TAG_BLOCK:
        // Create the child block tree from xml and connect it to this next connection's target
        let subBlockTree = try blockTreeFrom(xml: child, factory: factory)
        try nextConnection.connectTo(subBlockTree.rootBlock.inferiorConnection)
        blocks.append(contentsOf: subBlockTree.allBlocks)
      case XMLConstants.TAG_SHADOW:
        // Create the child block tree from xml and connect it to this next connection's shadow
        let subBlockTree = try blockTreeFrom(xml: child, factory: factory)
        try nextConnection.connectShadowTo(subBlockTree.rootBlock.inferiorConnection)
        blocks.append(contentsOf: subBlockTree.allBlocks)
      default:
        bky_print("Unknown element: \(xml.name)")
      }
    }

    if blocks.count == 0 {
      throw BlocklyError(.xmlParsing, "Missing next block.", xml)
    }

    return blocks
  }

  /**
   Sets a field on a block as specified by the xml.

   - Parameter block: The block to update.
   - Parameter xml: The xml that describes the field to update.
   */
  private class func setFieldOn(block: Block, fromXML xml: AEXMLElement) throws {
    // A missing or unknown field name isn't an error, it's just ignored.
    if let value = xml.value,
      let fieldName = xml.attributes[XMLConstants.ATTRIBUTE_NAME],
      let field = block.firstFieldWith(name: fieldName)
    {
      try field.setValueFromSerializedText(value)
    }
  }
}

// MARK: - XML Serialization

extension Block {
  // MARK: - Public

  /**
   Creates an XML element representing this block and all of its descendants.

   - Returns: An XML element.
   - Throws:
   `BlocklyError`: Thrown if there was an error serializing this block or any of its descendants.
   */
  public func toXML() throws -> AEXMLElement {
    let tagName = shadow ? XMLConstants.TAG_SHADOW : XMLConstants.TAG_BLOCK
    let blockXML = AEXMLElement(name: tagName, value: nil, attributes: [:])
    blockXML.attributes[XMLConstants.ATTRIBUTE_TYPE] = name // `name` represents the block type
    blockXML.attributes[XMLConstants.ATTRIBUTE_ID] = uuid

    if topLevel {
      blockXML.attributes[XMLConstants.ATTRIBUTE_POSITION_X] = String(Int(floor(position.x)))
      blockXML.attributes[XMLConstants.ATTRIBUTE_POSITION_Y] = String(Int(floor(position.y)))
    }

    for input in inputs {
      for inputXMLElement in try input.toXML() {
        blockXML.add(child: inputXMLElement)
      }
    }

    if nextBlock != nil || nextShadowBlock != nil {
      let nextChild = blockXML.addChild(name: XMLConstants.TAG_NEXT_STATEMENT)
      if let nextBlock = self.nextBlock {
        nextChild.add(child: try nextBlock.toXML())
      }
      if let nextShadowBlock = self.nextShadowBlock {
        nextChild.add(child: try nextShadowBlock.toXML())
      }
    }

    return blockXML
  }
}
