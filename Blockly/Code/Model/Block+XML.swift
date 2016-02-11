/*
* Copyright 2015 Google Inc. All Rights Reserved.
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

extension Block: NSXMLParserDelegate {
  // MARK: - Public

  /**
  Creates an XML element for this block and all its decendents.
  */
  public func serializeBlockTreeToXML() -> NSXMLElement {
    let blockXML = NSXMLElement("block")
    blockXML.addAttribute(NSXMLNode.attributeWithName("type", name))
    blockXML.addAttribute(NSXMLNode.attributeWithName("id", uuid))

    if topLevel {
      blockXML.addAttribute(NSXMLNode.attributeWithName("x", position.x))
      blockXML.addAttribute(NSXMLNode.attributeWithName("y", position.y))
    }

    for input in inputs {
    }
    return blockXML
  }

  /**
  Creates a new block and subblocks from an XML stream.

  - Parameter xmlNode: The element that contains this block's data.
  - Parameter workspace: The workspace to associate with the new block.
  - Parameter factory: The BlockFactory to use to build blocks.
  - Throws:
  `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
  malformed data, or contradictory data).
  - Returns: A new block and its subblocks.
  */
  public class func blockTreeFromXML(xmlNode: XMLElement, factory: BlockFactory) throws -> Block
  {
    guard let type = xmlNode.attributes["type"] else {
      throw BlocklyError(.XMLUnknownBlock, "The block type may not be nil.")
    }
    if type == "" {
      throw BlocklyError(.XMLUnknownBlock, "The block type may not be empty.");
    }

    guard var block = factory.buildBlock(type) else {
      throw BlocklyError(.XMLUnknownBlock, "The block type $(type) does not exist.")
    }

    if let id = xmlNode.attributes["id"] {
      block.id = id
    }

    if let x = xmlNode.attributes["x"],
      let y = xmlNode.attributes["y"]
    {
      block.position = WorkspacePointMake(x, y)
    }

    for child in xmlNode.children {
      switch child.name {
      case "field":
        setFieldOnBlock(block, fieldXML: child)
      case "value", "statement":
        setInputBlockOnBlock(block, xml: child, factory: factory)
      case "next":
        setNextBlockOnBlock(block, xml: child, factory: factory)
      default:
        bky_print("Unknown node name $(child.name)")
      }
    }

    return block
  }

  // MARK: - Internal

  /**
  Sets a field on the block as specified by the xml.
  - Parameter block: The block to update.
  - Parameter fieldXml: The xml that describes the field to update.
  - Throws:
  `BlocklyError`: Occurs if the field is missing any info or doesn't exist on the block.
  */
  internal func setFieldOnBlock(block: Block, fieldXML: XMLElement) throws {
    guard let name = fieldXml.name,
      let value = fieldXml.text,
      let field = block.firstFieldWithName(name) else
    {
      throw BlocklyError(.XMLParsing, "Unknown or missing field $(name)")
    }
    field.text = value;
  }

  /**
  Creates a new block from the xml and connects it to the block's next connection.
  - Parameter block: The block to connect to.
  - Parameter xml: The XML that describes the block to attach.
  - Parameter factory: The BlockFactory to use to create the new block.
  - Throws:
  `BlocklyError`: Occurs if the block doesn't have a next connection or the xml is invalid.
  */
  internal func setNextBlockOnBlock(block: Block, xml: XMLElement, factory: BlockFactory) throws {
    guard let connection = block.nextConnection else {
      throw BlocklyError(.XMLParsing, "Block has an invalid connection.")
    }
    for child in valueXml {
      switch child.name {
      case "block":
        buildBlockFromXml(child, connection)
      default:
        bky_print("Unkown element $(child.name)")
      }
    }
  }

  /**
  Creates a new block from the xml and connects it to one of the block's inputs.
  - Parameter block: The block to connect to.
  - Parameter xml: The XML that describes the input and block to attach.
  - Parameter factory: The BlockFactory to use to create the new block.
  - Throws:
  `BlocklyError`: Occurs if the block doesn't have that input or the xml is invalid.
  */
  internal func setInputBlockOnBlock(block: Block, xml: XMLElement, factory: BlockFactory) throws {
    // Figure out which connection we're connecting to
    guard let name = valueXml.name,
      let input = block.firstInputWithName(name),
      let connection = input.connection else
    {
      throw BlocklyError(.XMLParsing, "Unknown input on block")
    }
    for child in valueXml.children {
      switch child.name {
        // TODO: (#340) Handle case "shadow"
      case "block":
        buildBlockFromXML(child, connectTo: connection)
      default:
        bky_print("Unknown element $(child.name)")
      }
    }
  }

  /**
  Creates a new block from the xml and connects it to the given connection.
  - Parameter xml: The xml to create the block from.
  - Parameter connectTo: The connection to attach the block to.
  - Throws:
  `BlocklyError`: Occurs if the connection or the xml is invalid.
  */
  internal func buildBlockFromXML(xml: XmlElement, connectTo: Connection) {
    if let childBlock = blockTreeFromXML(xml, factory: factory) {
      if connectTo.type == Connection.ConnectionType.InputValue {
        guard let childConnection = childBlock.outputConnection else {
          throw BlocklyError(.XMLParsing, "Block has an invalid connection.")
        }
        connectTo.connectTo(childConnection)
      } else if connectTo.type == Connection.ConnectionType.NextStatement {
        guard let childConnection = childBlock.previousConnection else {
          throw BlocklyError(.XMLParsing, "Block has an invalid connection.")
        }
        connectTo.connectTo(childConnection)
      }
    }
  }
}
