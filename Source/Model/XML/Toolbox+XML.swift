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

extension Toolbox {
  // MARK: - Public

  /**
   Creates a new `Toolbox` from an XML string.

   - Parameter xmlString: The string that contains this toolbox's data.
   - Parameter factory: The `BlockFactory` to use to build blocks.
   - Returns: A `Toolbox`
   - Throws:
   `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
   malformed data, or contradictory data).
   */
  public class func makeToolbox(xmlString: String, factory: BlockFactory) throws
    -> Toolbox
  {
    let xmlDoc = try AEXMLDocument(xml: xmlString)
    return try makeToolbox(xml: xmlDoc, factory: factory)
  }

  /**
   Creates a new `Toolbox` from an XML object.

   - Parameter xml: The element that contains this toolbox's data.
   - Parameter factory: The `BlockFactory` to use to build blocks.
   - Returns: A `Toolbox`
   - Throws:
   `BlocklyError`: Occurs if there is a problem parsing the xml (eg. insufficient data,
   malformed data, or contradictory data).
   */
  public class func makeToolbox(xml: AEXMLElement, factory: BlockFactory) throws -> Toolbox {
    // Allow both "xml" (preferred) or "toolbox" as the root node
    var toolboxNode = xml["xml"]
    if toolboxNode.error != nil {
      toolboxNode = xml["toolbox"]
    }
    if let error = toolboxNode.error {
      throw BlocklyError(.xmlParsing,
        "An AEXMLError occurred parsing the root node. Expected \"<xml>\": \(error)")
    }

    let toolbox = Toolbox()

    for categoryNode in (toolboxNode["category"].all ?? []) {
      let name = categoryNode.attributes["name"] ?? ""
      var color: UIColor?

      // To maintain compatibility with Web Blockly, this value is accessed as "colour" and not
      // "color"
      if let colorString = categoryNode.attributes["colour"] {
        if let colorHue = NumberFormatter().number(from: colorString) {
          let hue = (min(max(CGFloat(colorHue), 0), 360)) / 360
          color = ColorHelper.makeColor(hue: hue)
        } else if let aColor = ColorHelper.makeColor(rgb: colorString) {
          color = aColor
        } else {
          bky_print("Invalid toolbox category color: \"\(colorString)\"")
        }
      }

      var icon: UIImage?
      if let iconString = categoryNode.attributes["icon"] {
        icon = ImageLoader.loadImage(named: iconString, forClass: Toolbox.self)
      }

      if let custom = categoryNode.attributes["custom"] {
        bky_print("Toolbox category 'custom' attribute ['\(custom)'] is not supported.")
      }

      let category = toolbox.addCategory(name: name, color: color ?? UIColor.clear, icon: icon)

      for subNode in categoryNode.children {
        switch subNode.name {
        case "block":
          let blockTree = try Block.blockTree(fromXml: subNode, factory: factory)
          try category.addBlockTree(blockTree.rootBlock)
        case "category":
          throw BlocklyError(.xmlParsing, "Subcategories are not supported.")
        case "shadow":
          throw BlocklyError(.xmlParsing, "Shadow blocks may not be top level toolbox blocks.")
        case "sep":
          if let gapString = subNode.attributes["gap"],
            let gap = NumberFormatter().number(from: gapString)
          {
            category.addGap(CGFloat(gap))
          } else {
            category.addGap()
          }
        default:
          bky_print("Unknown element: \(xml.name)")
        }
      }
    }

    // Allow non-categorized blocks. These will appear in their own category at the very end.
    if let uncategorizedBlocks = toolboxNode["block"].all,
      uncategorizedBlocks.count > 0
    {
      // TODO:(#101) Localize "Blocks"
      let categoryName = "Blocks"
      let color = ColorHelper.makeColor(hue: (160.0 / 360.0))
      let category = toolbox.addCategory(name: categoryName, color: color, icon: nil)

      for blockNode in uncategorizedBlocks {
        let blockTree = try Block.blockTree(fromXml: blockNode, factory: factory)
        try category.addBlockTree(blockTree.rootBlock)
      }
    }

    return toolbox
  }
}

