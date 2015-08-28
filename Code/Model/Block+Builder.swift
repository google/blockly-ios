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

extension Block {
  /**
  Builder for creating instances of `Block`.
  */
  @objc(BKYBlockBuilder)
  public class Builder: NSObject {
    // MARK: - Properties

    // These values are publicly immutable in `Block`
    public var identifier: String = ""
    public var name: String = ""
    public var category: Int = 0
    public var colourHue: Int = 0
    public var outputConnection: Connection?
    public var nextConnection: Connection?
    public var previousConnection: Connection?
    public var inputs: [Input] = []
    public var inputsInline: Bool = false
    public unowned var workspace: Workspace

    // These values are publicly mutable in `Block`
    public var childBlocks: [Block] = []
    public weak var parentBlock: Block?
    public var tooltip: String = ""
    public var comment: String = ""
    public var helpURL: String = ""
    public var hasContextMenu: Bool = true
    public var canDelete: Bool = true
    public var canMove: Bool = true
    public var canEdit: Bool = true
    public var collapsed: Bool = false
    public var disabled: Bool = false
    public var rendered: Bool = false
    public var position: CGPoint = CGPointZero

    // MARK: - Initializers

    public init(identifier: String, name: String, workspace: Workspace) {
      self.identifier = identifier
      self.name = name
      self.workspace = workspace
    }

    // MARK: - Public

    /**
    Creates a new block given the current state of the builder.

    - Returns: A new block
    */
    public func build() -> Block {
      let block = Block(identifier: identifier, name: name, workspace: workspace, category: category,
        colourHue: colourHue, inputs: inputs, inputsInline: inputsInline,
        outputConnection: outputConnection, nextConnection: nextConnection,
        previousConnection: previousConnection)

      block.childBlocks = childBlocks
      block.parentBlock = parentBlock
      block.tooltip = tooltip
      block.comment = comment
      block.helpURL = helpURL
      block.hasContextMenu = hasContextMenu
      block.canDelete = canDelete
      block.canMove = canMove
      block.canEdit = canEdit
      block.collapsed = collapsed
      block.disabled = disabled
      block.rendered = rendered
      block.position = position
      
      return block
    }
  }
}
