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

    // MARK: - Public

    /**
    Creates a new block given the current state of the builder.

    - Returns: A new block
    */
    public func build() -> Block {
      let block = Block(identifier: identifier, workspace: workspace, category: category,
        colourHue: colourHue, inputs: inputs, inputsInline: inputsInline)

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

      if outputConnectionEnabled {
        block.outputConnection = Connection(type: .OutputValue, sourceBlock: block)
        block.outputConnection!.typeChecks = outputConnectionTypeChecks
      }

      if nextConnectionEnabled {
        block.nextConnection = Connection(type: .NextStatement, sourceBlock: block)
        block.nextConnection!.typeChecks = nextConnectionTypeChecks
      }

      if previousConnectionEnabled {
        block.previousConnection = Connection(type: .PreviousStatement, sourceBlock: block)
        block.previousConnection!.typeChecks = previousConnectionTypeChecks
      }

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
