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
   Creates a new tree of blocks from an XML object.

   - parameter xml: The XML string representing the block tree.
   - parameter factory: The `BlockFactory` to use to build blocks.
   - returns: A `BlockTree` tuple of all blocks that were created.
   - throws:
   `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
   malformed data, or contradictory data).
   */
  public class func blockTree(
    fromXMLString xmlString: String, factory: BlockFactory) throws -> BlockTree
  {
    let xmlDoc = try AEXMLDocument(xml: xmlString)
    return try blockTree(fromXML: xmlDoc.root, factory: factory)
  }

  /**
   Creates a new tree of blocks from an XML object.

   - parameter xml: The element that contains this block's data.
   - parameter factory: The `BlockFactory` to use to build blocks.
   - returns: A `BlockTree` tuple of all blocks that were created.
   - throws:
   `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
   malformed data, or contradictory data).
   */
  public class func blockTree(fromXML xml: AEXMLElement, factory: BlockFactory) throws -> BlockTree
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

    guard let block = try? factory.makeBlock(name: type, shadow: shadow, uuid: uuid) else {
      throw BlocklyError(.xmlUnknownBlock, "The block type \(type) does not exist.", xml)
    }

    var allBlocks = [block]
    let formatter = NumberFormatter()
    if let xString = xml.attributes[XMLConstants.ATTRIBUTE_POSITION_X],
      let yString = xml.attributes[XMLConstants.ATTRIBUTE_POSITION_Y],
      let x = formatter.number(from: xString),
      let y = formatter.number(from: yString)
    {
      block.position = WorkspacePoint(x: CGFloat(truncating: x), y: CGFloat(truncating: y))
    }

    if let disabled = xml.attributes[XMLConstants.TAG_DISABLED] {
      block.disabled = disabled.caseInsensitiveCompare("true") == .orderedSame
    }
    if let deletable = xml.attributes[XMLConstants.TAG_DELETABLE] {
      block.deletable = deletable.caseInsensitiveCompare("true") == .orderedSame
    }
    if let movable = xml.attributes[XMLConstants.TAG_MOVABLE] {
      block.movable = movable.caseInsensitiveCompare("true") == .orderedSame
    }
    if let editable = xml.attributes[XMLConstants.TAG_EDITABLE] {
      block.editable = editable.caseInsensitiveCompare("true") == .orderedSame
    }
    if let inputsInline = xml.attributes[XMLConstants.TAG_INPUTS_INLINE] {
      block.inputsInline = inputsInline.caseInsensitiveCompare("true") == .orderedSame
    }

    if let mutator = block.mutator {
      // Update the mutator and immediately apply it
      mutator.update(fromXML: xml)
      try mutator.mutateBlock()
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
        try setField(onBlock: block, fromXML: child)
      case XMLConstants.TAG_COMMENT:
        if let commentText = child.value {
          block.comment = commentText
        }
      default:
        if block.mutator == nil {
          // Log unknown nodes (if there's a mutator, those unknown nodes may have been handled
          // already so we will not log them).
          bky_print("Unknown node name: \(child.name)")
        }
      }
    }

    return BlockTree(rootBlock: block, allBlocks: allBlocks)
  }

  // MARK: - Internal

  /**
   Creates a set of blocks from xml and connects them to one of the block's inputs.

   - parameter block: The block to connect to.
   - parameter xml: The XML that describes the input and blocks to attach.
   - parameter factory: The `BlockFactory` to use to build blocks.
   - returns: An array of all `Block` instances that were created.
   - throws:
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
    guard let input = block.firstInput(withName: inputName) else {
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
        let subBlockTree = try Block.blockTree(fromXML: child, factory: factory)
        try inputConnection.connectTo(subBlockTree.rootBlock.inferiorConnection)
        blocks.append(contentsOf: subBlockTree.allBlocks)
      case XMLConstants.TAG_SHADOW:
        // Create the child block tree from xml and connect it to this input connection's shadow
        let subBlockTree = try Block.blockTree(fromXML: child, factory: factory)
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

   - parameter block: The block to connect to.
   - parameter xml: The XML that describes the blocks to attach.
   - parameter factory: The `BlockFactory` to use to build blocks.
   - returns: An array of all `Block` instances that were created.
   - throws:
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
        let subBlockTree = try blockTree(fromXML: child, factory: factory)
        try nextConnection.connectTo(subBlockTree.rootBlock.inferiorConnection)
        blocks.append(contentsOf: subBlockTree.allBlocks)
      case XMLConstants.TAG_SHADOW:
        // Create the child block tree from xml and connect it to this next connection's shadow
        let subBlockTree = try blockTree(fromXML: child, factory: factory)
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

   - parameter block: The block to update.
   - parameter xml: The xml that describes the field to update.
   - note: A missing or unknown field name/value isn't an error, it's just ignored.
   - throws:
   `BlocklyError`: Thrown if there was a problem setting the field value from serialized text.
   */
  private class func setField(onBlock block: Block, fromXML xml: AEXMLElement) throws {
    guard let fieldName = xml.attributes[XMLConstants.ATTRIBUTE_NAME] else {
      bky_print("Skipping setting field for block type '\(block.name)'. " +
        "Missing required field attribute '\(XMLConstants.ATTRIBUTE_NAME)':\n\(xml.xmlCompact)")
      return
    }

    guard let field = block.firstField(withName: fieldName) else {
      bky_print("Skipping setting field for block type '\(block.name)'. " +
        "Could not find field name '\(fieldName)':\n\(xml.xmlCompact)")
      return
    }

    let value = xml.value ?? ""
    try field.setValueFromSerializedText(value)
  }
}

// MARK: - XML Serialization

extension Block {
  // MARK: - Public

  /**
   Returns an XML string representing the current state of this block and all of its descendants.

   - returns: The XML string.
   - throws:
   `BlocklyError`: Thrown if there was an error serializing this block or any of its descendants.
   */
  @objc(toXMLWithError:)
  public func toXML() throws -> String {
    return try toXMLElement().xml
  }

  // MARK: - Internal

  /**
   Creates and returns an XML element representing the current state of this block and all of its
   descendants.

   - returns: An XML element.
   - throws:
   `BlocklyError`: Thrown if there was an error serializing this block or any of its descendants.
   */
  internal func toXMLElement() throws -> AEXMLElement {
    let tagName = shadow ? XMLConstants.TAG_SHADOW : XMLConstants.TAG_BLOCK
    let blockXML = AEXMLElement(name: tagName, value: nil, attributes: [:])
    blockXML.attributes[XMLConstants.ATTRIBUTE_TYPE] = name // `name` represents the block type
    blockXML.attributes[XMLConstants.ATTRIBUTE_ID] = uuid

    if topLevel {
      blockXML.attributes[XMLConstants.ATTRIBUTE_POSITION_X] = String(Int(floor(position.x)))
      blockXML.attributes[XMLConstants.ATTRIBUTE_POSITION_Y] = String(Int(floor(position.y)))
    }
    if initialInputsInlineValue != inputsInline {
      blockXML.attributes[XMLConstants.TAG_INPUTS_INLINE] = String(inputsInline)
    }
    if disabled {
      blockXML.attributes[XMLConstants.TAG_DISABLED] = "true"
    }
    if !deletable && !shadow {
       blockXML.attributes[XMLConstants.TAG_DELETABLE] = "false"
    }
    if !movable && !shadow {
      blockXML.attributes[XMLConstants.TAG_MOVABLE] = "false"
    }
    if !editable {
      blockXML.attributes[XMLConstants.TAG_EDITABLE] = "false"
    }

    if let mutator = mutator {
      blockXML.addChild(mutator.toXMLElement())
    }

    for input in inputs {
      for inputXMLElement in try input.toXMLElement() {
        blockXML.addChild(inputXMLElement)
      }
    }

    if nextBlock != nil || nextShadowBlock != nil {
      let nextChild = blockXML.addChild(name: XMLConstants.TAG_NEXT_STATEMENT)
      if let nextBlock = self.nextBlock {
        nextChild.addChild(try nextBlock.toXMLElement())
      }
      if let nextShadowBlock = self.nextShadowBlock {
        nextChild.addChild(try nextShadowBlock.toXMLElement())
      }
    }

    return blockXML
  }
}
