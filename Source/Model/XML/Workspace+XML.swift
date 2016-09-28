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

extension Workspace {
  // MARK: - Public

  /**
   Loads blocks from an XML string into the workspace.

   - Parameter xmlString: The string that contains all the block data.
   - Parameter factory: The `BlockFactory` to use to build blocks.
   - Throws:
     `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
     malformed data, or contradictory data).
  */
  public func loadBlocks(fromXMLString xmlString: String, factory: BlockFactory) throws {
    let xmlDoc = try AEXMLDocument(xml: xmlString)
    try loadBlocks(fromXML: xmlDoc.root, factory: factory)
  }

  /**
   Loads blocks from an XML object into the workspace.

   - Parameter xml: The object that contains all the block data.
   - Parameter factory: The `BlockFactory` to use to build blocks.
   - Throws:
     `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
     malformed data, or contradictory data).
   */
  public func loadBlocks(fromXML xml: AEXMLElement, factory: BlockFactory) throws {
    if let allBlocksXML = xml["block"].all {
      for blockXML in allBlocksXML {
        let blockTree = try Block.blockTree(fromXml: blockXML, factory: factory)
        try addBlockTree(blockTree.rootBlock)
      }
    }
  }
}

// MARK: - XML Serialization

extension Workspace {
  // MARK: - Public

  /**
   Creates an XML document representing the current state of this workspace.

   - Returns: An XML document.
   - Throws:
   `BlocklyError`: Thrown if there was an error serializing any of the blocks in the workspace.
   */
  public func toXML() throws -> AEXMLDocument {
    let xmlDoc = AEXMLDocument()
    let rootXML = xmlDoc.addChild(name: "xml", value: nil,
      attributes: ["xmlns": "http://www.w3.org/1999/xhtml"])

    for block in topLevelBlocks() {
      rootXML.addChild(try block.toXML())
    }

    return xmlDoc
  }
}
