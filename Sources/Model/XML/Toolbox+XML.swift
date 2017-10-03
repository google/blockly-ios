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

   - parameter xmlString: The string that contains this toolbox's data.
   - parameter factory: The `BlockFactory` to use to build blocks.
   - returns: A `Toolbox`
   - throws:
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

   - parameter xml: The element that contains this toolbox's data.
   - parameter factory: The `BlockFactory` to use to build blocks.
   - returns: A `Toolbox`
   - throws:
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

    if toolboxNode["category"].count > 0 && toolboxNode["block"].count > 0 {
      throw BlocklyError(.xmlParsing,
        "Toolbox XML cannot contain both '<category>' and '<block>' as top-level nodes. " +
        "Only one is allowed.\nXML:\n\(xml)")
    }

    let toolbox = Toolbox()

    for categoryNode in (toolboxNode["category"].all ?? []) {
      let name = MessageManager.shared.decodedString(categoryNode.attributes["name"] ?? "")
      var color: UIColor?

      // To maintain compatibility with Web Blockly, this value is accessed as "colour" and not
      // "color"
      if let colorString = categoryNode.attributes["colour"] {
        let decodedColor = MessageManager.shared.decodedString(colorString)
        if let colorHue = NumberFormatter().number(from: decodedColor) {
          color = ColorHelper.makeColor(hue: CGFloat(truncating: colorHue))
        } else if let aColor = ColorHelper.makeColor(rgb: decodedColor) {
          color = aColor
        } else {
          bky_print("Invalid toolbox category color: \"\(colorString)\"")
        }
      }

      var icon: UIImage?
      if let iconString = categoryNode.attributes["icon"] {
        icon = ImageLoader.loadImage(named: iconString, forClass: Toolbox.self)
      }

      let category = toolbox.addCategory(name: name, color: color ?? UIColor.clear, icon: icon)
      if let custom = categoryNode.attributes["custom"] {
        if custom.uppercased() == "VARIABLE" {
          category.categoryType = .variable
        } else if custom.uppercased() == "PROCEDURE" {
          category.categoryType = .procedure

          // Immediately add the base blocks
          let noReturnBlock = try factory.makeBlock(name: "procedures_defnoreturn")
          (noReturnBlock.firstField(withName: "NAME") as? FieldInput)?.text =
            message(forKey: "BKY_PROCEDURES_DEFNORETURN_PROCEDURE")
          try category.addBlockTree(noReturnBlock)

          let returnBlock = try factory.makeBlock(name: "procedures_defreturn")
          (returnBlock.firstField(withName: "NAME") as? FieldInput)?.text =
            message(forKey: "BKY_PROCEDURES_DEFRETURN_PROCEDURE")

          if let mutator = returnBlock.mutator as? MutatorProcedureDefinition {
            mutator.allowStatements = true
            try mutator.mutateBlock()
          }
          try category.addBlockTree(returnBlock)

          try category.addBlockTree(factory.makeBlock(name: "procedures_ifreturn"))
        } else {
          bky_print("Toolbox category 'custom' attribute ['\(custom)'] is not supported.")
        }
      }

      for subNode in categoryNode.children {
        try parseChildNode(subNode, forCategory: category, factory: factory)
      }
    }

    // Parse uncategorized blocks
    if let uncategorizedBlocks = toolboxNode["block"].all,
      uncategorizedBlocks.count > 0
    {
      // TODO(#101): Localize "Blocks"
      let categoryName = "Blocks"
      let color = ColorPalette.green.tint600
      let category = toolbox.addCategory(name: categoryName, color: color, icon: nil)

      for blockNode in toolboxNode.children {
        try parseChildNode(blockNode, forCategory: category, factory: factory)
      }
    }

    return toolbox
  }

  // MARK: - Private

  private class func parseChildNode(_ childNode: AEXMLElement,
    forCategory category: Toolbox.Category, factory: BlockFactory) throws
  {
    switch childNode.name {
    case "block":
      let blockTree = try Block.blockTree(fromXML: childNode, factory: factory)
      try category.addBlockTree(blockTree.rootBlock)
    case "category":
      throw BlocklyError(.xmlParsing, "Subcategories are not supported.")
    case "shadow":
      throw BlocklyError(.xmlParsing, "Shadow blocks may not be top level toolbox blocks.")
    case "sep":
      if let gapString = childNode.attributes["gap"],
        let gap = NumberFormatter().number(from: gapString)
      {
        category.addGap(CGFloat(truncating: gap))
      } else {
        category.addGap()
      }
    default:
      bky_print("Unknown element: \(childNode.name)")
    }
  }
}
