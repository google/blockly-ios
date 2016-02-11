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

// MARK: - XML Parsing

extension Workspace {
  // MARK: - Public

  /**
  Loads blocks from an XML string into the workspace.

  - Parameter xmlString: The string that contains all the block data.
  - Parameter factory: The BlockFactory to use to build blocks.
  - Throws:
  `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
  malformed data, or contradictory data).
  */
  public func loadBlocksFromXMLString(xmlString: String, factory: BlockFactory) throws {
    let xml = SWXMLHash.parse(xmlString)
    try loadBlocksFromXML(xml, factory: factory)
  }

  /**
   Loads blocks from an XML object into the workspace.

   - Parameter xml: The object that contains all the block data.
   - Parameter factory: The BlockFactory to use to build blocks.
   - Throws:
   `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
   malformed data, or contradictory data).
   */
  public func loadBlocksFromXML(xml: XMLIndexer, factory: BlockFactory) throws {
    if let allBlocksXML = xml.children.first?["block"] {
      for blockXML in allBlocksXML {
        let blockTree = try Block.blockTreeFromXML(blockXML, factory: factory)
        addBlockTree(blockTree.rootBlock)
      }
    }
  }
}
