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
    // MARK: - Static Properties
    private static let CONFLICTING_CONNECTIONS_ERROR =
      "Block cannot have both an output and a either a previous or next statement."

    // MARK: - Properties

    // These values are publicly immutable in `Block`
    public var identifier: String = ""
    public var category: Int = 0
    public var colourHue: Int = 0
    public private(set) var outputConnectionEnabled: Bool = false
    public private(set) var outputConnectionTypeChecks: [String]?
    public private(set) var nextConnectionEnabled: Bool = false
    public private(set) var nextConnectionTypeChecks: [String]?
    public private(set) var previousConnectionEnabled: Bool = false
    public private(set) var previousConnectionTypeChecks: [String]?
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

    public init(identifier: String, workspace: Workspace) {
      self.identifier = identifier
      self.workspace = workspace
    }

    /**
    Initialize a builder from an existing block. All values that are not specific to
    a single instance of a block will be copied in to the builder.
    */
    public init(block: Block, workspace: Workspace) {
      self.workspace = workspace

      identifier = block.identifier
      category = block.category
      colourHue = block.colourHue
      inputsInline = block.inputsInline

      tooltip = block.tooltip
      comment = block.comment
      helpURL = block.helpURL
      hasContextMenu = block.hasContextMenu
      collapsed = block.collapsed
      position = block.position

      outputConnectionEnabled = block.outputConnection != nil ? true : false
      outputConnectionTypeChecks = block.outputConnection?.typeChecks
      nextConnectionEnabled = block.nextConnection != nil ? true : false
      nextConnectionTypeChecks = block.nextConnection?.typeChecks
      previousConnectionEnabled = block.previousConnection != nil ? true : false
      previousConnectionTypeChecks = block.previousConnection?.typeChecks

      for input in block.inputs {
        let newInput = Input(type: input.type, name: input.name);
        for field in input.fields {
          newInput.appendField(field.copy() as! Field)
        }
        inputs.append(newInput)
      }
    }

    // MARK: - Public

    /**
    Creates a new block given the current state of the builder.

    - Returns: A new block
    */
    public func build() -> Block {
      var outputConnection: Connection?
      var nextConnection: Connection?
      var previousConnection: Connection?
      if outputConnectionEnabled {
        outputConnection = Connection(type: .OutputValue)
        outputConnection!.typeChecks = outputConnectionTypeChecks
      }
      if nextConnectionEnabled {
        nextConnection = Connection(type: .NextStatement)
        nextConnection!.typeChecks = nextConnectionTypeChecks
      }
      if previousConnectionEnabled {
        previousConnection = Connection(type: .PreviousStatement)
        previousConnection!.typeChecks = previousConnectionTypeChecks
      }

      let block = Block(identifier: identifier, workspace: workspace, category: category,
        colourHue: colourHue, inputs: inputs, inputsInline: inputsInline,
        outputConnection: outputConnection, previousConnection: previousConnection,
        nextConnection: nextConnection)

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

    public func setOutputConnectionEnabled(enabled: Bool, typeChecks: [String]? = nil) throws {
      if enabled && (nextConnectionEnabled || previousConnectionEnabled) {
        throw BlockError(.InvalidBlockDefinition, Builder.CONFLICTING_CONNECTIONS_ERROR)
      }
      self.outputConnectionEnabled = enabled
      self.outputConnectionTypeChecks = typeChecks
    }

    public func setNextConnectionEnabled(enabled: Bool, typeChecks: [String]? = nil) throws {
      if enabled && outputConnectionEnabled {
        throw BlockError(.InvalidBlockDefinition, Builder.CONFLICTING_CONNECTIONS_ERROR)
      }
      self.nextConnectionEnabled = enabled
      self.nextConnectionTypeChecks = typeChecks
    }

    public func setPreviousConnectionEnabled(enabled: Bool, typeChecks: [String]? = nil) throws {
      if enabled && outputConnectionEnabled {
        throw BlockError(.InvalidBlockDefinition, Builder.CONFLICTING_CONNECTIONS_ERROR)
      }
      self.previousConnectionEnabled = enabled
      self.previousConnectionTypeChecks = typeChecks
    }
  }
}
