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

/**
 Builder for creating `Block` instances.
 */
@objc(BKYBlockBuilder)
@objcMembers public final class BlockBuilder: NSObject {
  // MARK: - Static Properties
  private static let CONFLICTING_CONNECTIONS_ERROR =
   "Block cannot have both an output and a either a previous or next statement."

  // MARK: - Properties

  // These values are publicly immutable in `Block`

  /// The name of the block. Defaults to `""`.
  public var name: String = ""
  /// The color of the block. Defaults to `UIColor.clear`.
  public var color: UIColor = UIColor.clear
  /// Specifies the output connection is enabled. Defaults to `false`.
  public private(set) var outputConnectionEnabled: Bool = false
  /// Specifies the output type checks. Defaults to `nil`.
  public private(set) var outputConnectionTypeChecks: [String]?
  /// Specifies the next connection is enabled. Defaults to `false`.
  public private(set) var nextConnectionEnabled: Bool = false
  /// Specifies the next connection type checks. Defaults to `nil`.
  public private(set) var nextConnectionTypeChecks: [String]?
  /// Specifies the previous connection is enabled. Defaults to `false`.
  public private(set) var previousConnectionEnabled: Bool = false
  /// Specifies the previous connection type checks. Defaults to `nil`.
  public private(set) var previousConnectionTypeChecks: [String]?
  /// The builders for inputs on the block. Defaults to `[]`.
  public var inputBuilders: [InputBuilder] = []
  /// Specifies the inputs are inline. Defaults to `false`.
  public var inputsInline: Bool = false
  /// The absolute position of the block, in the Workspace coordinate system.
  /// Defaults to `WorkspacePoint.zero`.
  public var position: WorkspacePoint = WorkspacePoint.zero
  /// Specifies a mutator to associate with the block. A copy of this mutator is attached to a
  /// block when it is built. Defaults to `nil`.
  public var mutator: Mutator? = nil
  /// Specifies extensions that should be run on the block during initialization. Defaults to `[]`.
  public var extensions = [BlockExtension]()
  /// Specifies the style of the block.
  public var style = Block.Style()

  // These values are publicly mutable in `Block`

  /// The tooltip of the block. Defaults to `""`.
  public var tooltip: String = ""
  /// The comment of the block. Defaults to `""`.
  public var comment: String = ""
  /// The help URL of the block. Defaults to `""`.
  public var helpURL: String = ""
  /// Specifies the block is deletable. Defaults to `true`.
  public var deletable: Bool = true
  /// Specifies the block is movable. Defaults to `true`.
  public var movable: Bool = true
  /// Specifies the block is editable. Defaults to `true`.
  public var editable: Bool = true
  /// Specifies the block is disabled. Defaults to `false`.
  public var disabled: Bool = false

  // MARK: - Initializers

  /**
   Initializes the block builder. Requires a name for the block to be built.

   - parameter name: The name of the block to be built.
   */
  public init(name: String) {
    super.init()
    self.name = name
    self.color = ColorHelper.makeColor(hue: 0)
  }

  /**
   Initialize a builder from an existing block. All values that are not specific to
   a single instance of a block will be copied in to the builder. Any associated layouts are not
   copied into the builder.

   - parameter block: The block to be copied.
  */
  public init(block: Block) {
    name = block.name
    color = block.color
    inputsInline = block.inputsInline
    position = block.position
    mutator = block.mutator?.copyMutator()

    tooltip = block.tooltip
    comment = block.comment
    helpURL = block.helpURL
    deletable = block.deletable
    movable = block.movable
    editable = block.editable
    disabled = block.disabled

    outputConnectionEnabled = block.outputConnection != nil ? true : false
    outputConnectionTypeChecks = block.outputConnection?.typeChecks
    nextConnectionEnabled = block.nextConnection != nil ? true : false
    nextConnectionTypeChecks = block.nextConnection?.typeChecks
    previousConnectionEnabled = block.previousConnection != nil ? true : false
    previousConnectionTypeChecks = block.previousConnection?.typeChecks

    style = block.style.copy() as? Block.Style ?? Block.Style()

    inputBuilders.append(contentsOf: block.inputs.map({ InputBuilder(input: $0) }))
  }

  // MARK: - Public

  /**
   Creates a new block given the current state of the builder, assigned with a new UUID.

   - parameter shadow: Specifies if the resulting block should be a shadow block.
   - throws:
   `BlocklyError`: Occurs if the block is missing any required pieces.
   - returns: A new block.
   */
  @objc(makeBlockAsShadow:error:)
  public func makeBlock(shadow: Bool) throws -> Block {
    return try makeBlock(shadow: shadow, uuid: nil)
  }

  /**
   Creates a new block given the current state of the builder.

   - parameter shadow: [Optional] Specifies if the resulting block should be a shadow block.
   The default value is `false`.
   - parameter uuid: [Optional] The uuid to assign the block. If nil, a new uuid is automatically
   assigned to the block.
   - throws:
   `BlocklyError`: Occurs if the block is missing any required pieces.
   - returns: A new block.
   */
  @objc(makeBlockAsShadow:uuid:error:)
  public func makeBlock(shadow: Bool = false, uuid: String? = nil) throws -> Block {
    if name == "" {
      throw BlocklyError(.invalidBlockDefinition, "Block name may not be empty")
    }
    var outputConnection: Connection?
    var nextConnection: Connection?
    var previousConnection: Connection?
    if outputConnectionEnabled {
      outputConnection = Connection(type: .outputValue)
      outputConnection!.typeChecks = outputConnectionTypeChecks
    }
    if nextConnectionEnabled {
      nextConnection = Connection(type: .nextStatement)
      nextConnection!.typeChecks = nextConnectionTypeChecks
    }
    if previousConnectionEnabled {
      previousConnection = Connection(type: .previousStatement)
      previousConnection!.typeChecks = previousConnectionTypeChecks
    }
    let inputs = inputBuilders.map({ $0.makeInput() })
    let styleCopy = style.copy() as? Block.Style ?? Block.Style()
    let mutatorCopy = mutator?.copyMutator()

    let block = try Block(
      uuid: uuid,
      name: name,
      color: color,
      inputs: inputs,
      inputsInline: inputsInline,
      position: position,
      shadow: shadow,
      tooltip: tooltip,
      comment: comment,
      helpURL: helpURL,
      deletable: deletable,
      movable: movable,
      disabled: disabled,
      editable: editable,
      outputConnection: outputConnection,
      previousConnection: previousConnection,
      nextConnection: nextConnection,
      style: styleCopy,
      mutator: mutatorCopy,
      extensions: extensions)

    return block
  }

  /**
   Specifies an output connection on the builder, and optionally the type checks to go with it.

   - parameter enabled: Specifies the resulting block should have an output connection.
   - parameter typeChecks: [Optional] Specifies the type checks for the given output connection.
     Defaults to `nil`.
   - throws:
   `BlocklyError`: Occurs if the builder already has a next or previous connection.
   */
  public func setOutputConnection(enabled: Bool, typeChecks: [String]? = nil) throws {
    if enabled && (nextConnectionEnabled || previousConnectionEnabled) {
      throw BlocklyError(.invalidBlockDefinition, BlockBuilder.CONFLICTING_CONNECTIONS_ERROR)
    }
    self.outputConnectionEnabled = enabled
    self.outputConnectionTypeChecks = typeChecks
  }

  /**
   Specifies an next connection on the builder, and optionally the type checks to go with it.

   - parameter enabled: Specifies the resulting block should have a next connection.
   - parameter typeChecks: [Optional] Specifies the type checks for the given next connection.
     Defaults to `nil`.
   - throws:
   `BlocklyError`: Occurs if the builder already has an output connection.
   */
  public func setNextConnection(enabled: Bool, typeChecks: [String]? = nil) throws {
    if enabled && outputConnectionEnabled {
      throw BlocklyError(.invalidBlockDefinition, BlockBuilder.CONFLICTING_CONNECTIONS_ERROR)
    }
    self.nextConnectionEnabled = enabled
    self.nextConnectionTypeChecks = typeChecks
  }

  /**
   Specifies a previous connection on the builder, and optionally the type checks to go with it.

   - parameter enabled: Specifies the resulting block should have a previous connection.
   - parameter typeChecks: [Optional] Specifies the type checks for the given previous connection.
     Defaults to `nil`.
   - throws:
   `BlocklyError`: Occurs if the builder already has an output connection.
   */
  public func setPreviousConnection(enabled: Bool, typeChecks: [String]? = nil) throws {
    if enabled && outputConnectionEnabled {
      throw BlocklyError(.invalidBlockDefinition, BlockBuilder.CONFLICTING_CONNECTIONS_ERROR)
    }
    self.previousConnectionEnabled = enabled
    self.previousConnectionTypeChecks = typeChecks
  }
}
