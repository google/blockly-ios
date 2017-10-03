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
Protocol for events that occur on a `Block` instance.
*/
@objc(BKYBlockListener)
public protocol BlockListener: class {
  /**
   Event that is fired when one of a block's properties has changed.

   - parameter block: The `Block` that changed.
   */
  func didUpdateBlock(_ block: Block)
}

/**
 Class that represents a single block.

 - note: To create a block programmatically, use a `BlockBuilder`.
 */
@objc(BKYBlock)
@objcMembers public final class Block : NSObject {
  // MARK: - Tuples

  /**
   A tuple representing a tree of connected blocks where:
   - `rootBlock` is the root of the tree
   - `allBlocks` is a list of all connected blocks (including `rootBlock`).
   */
  public typealias BlockTree = (rootBlock: Block, allBlocks: [Block])

  // MARK: - Properties

  /// A unique identifier used to identify this block for its lifetime
  public let uuid: String
  /// The type name of this block
  public let name: String
  /// The initial value of `inputsInline`.
  internal let initialInputsInlineValue: Bool
  /// Flag indicating if input connectors should be drawn inside a block (`true`) or
  /// on the edge of the block (`false`)
  public var inputsInline: Bool {
    didSet {
      if inputsInline == oldValue {
        return
      }

      updateInputs()
      notifyDidUpdateBlock()
    }
  }
  /// The absolute position of the block, in the Workspace coordinate system
  public var position: WorkspacePoint
  /// Flag indicating if this is a shadow block (`true`) or not (`false)
  public let shadow: Bool
  /// The `.OutputValue` connection for this block
  public let outputConnection: Connection?
  /// Convenience property for accessing `self.outputConnection?.targetBlock`
  public var outputBlock: Block? {
    return outputConnection?.targetBlock
  }
  /// The `.NextStatement` connection for this block
  public let nextConnection: Connection?
  /// Convenience property for accessing `self.nextConnection?.targetBlock`
  public var nextBlock: Block? {
    return nextConnection?.targetBlock
  }
  /// Convenience property for accessing `self.nextConnection?.shadowBlock`
  public var nextShadowBlock: Block? {
    return nextConnection?.shadowBlock
  }
  /// The `.PreviousStatement` connection for this block
  /// - note: A block may only have one non-nil `self.outputConnection` or `self.previousConnection`
  public let previousConnection: Connection?
  /// Convenience property for accessing `self.previousConnection?.targetBlock`
  public var previousBlock: Block? {
    return previousConnection?.targetBlock
  }
  /// If an inferior connection exists, returns either `self.outputConnection` or
  /// `self.previousConnection` (only one may be non-`nil`).
  public var inferiorConnection: Connection? {
    return outputConnection ?? previousConnection
  }

  /// List of connections directly attached to this block
  public fileprivate(set) var directConnections = [Connection]()
  /// List of inputs attached to this block
  public private(set) var inputs: [Input] {
    didSet {
      updateInputs()
      updateDirectConnections()
      notifyDidUpdateBlock()
    }
  }
  /// The color of the block
  public let color: UIColor
  /// An optional mutator for this block
  public var mutator: Mutator?
  /// Tooltip text of the block
  public var tooltip: String {
    didSet { didSetProperty(tooltip, oldValue) }
  }
  /// The comment text of the block
  public var comment: String {
    didSet { didSetProperty(comment, oldValue) }
  }
  /// A help URL to learn more info about this block
  public var helpURL: String {
    didSet { didSetProperty(helpURL, oldValue) }
  }
  /// Flag indicating if this block may be deleted
  public var deletable: Bool {
    didSet { didSetProperty(deletable, oldValue) }
  }
  /// Flag indicating if this block may be moved by the user
  public var movable: Bool {
    didSet { didSetProperty(movable, oldValue) }
  }
  /// Flag indicating if this block is disabled, which means it will be excluded from code
  /// generation.
  public var disabled: Bool  {
    didSet { didSetProperty(disabled, oldValue) }
  }
  /// Flag indicating if this block may be dragged by the user
  public var draggable: Bool {
    return movable && !shadow
  }
  /// Flag indicating if this block can be edited. Updating this property automatically updates
  /// the `editable` property on all child fields.
  public var editable: Bool {
    didSet {
      if editable == oldValue {
        return
      }

      updateInputs()
      notifyDidUpdateBlock()
    }
  }

  /// Flag indicating if this block is at the highest level in the workspace
  public var topLevel: Bool {
    return previousConnection?.targetConnection == nil &&
      previousConnection?.shadowConnection == nil &&
      outputConnection?.targetConnection == nil &&
      outputConnection?.shadowConnection == nil
  }

  /// The style that should be applied to the block during rendering.
  public var style: Style {
    didSet {
      if style == oldValue {
        return
      }

      oldValue.block = nil
      style.block = self
      notifyDidUpdateBlock()
    }
  }

  /// Listeners for events that occur on this block.
  public var listeners = WeakSet<BlockListener>()

  /// The layout associated with this block.
  public weak var layout: BlockLayout?

  // MARK: - Initializers

  internal init(
    uuid: String?,
    name: String,
    color: UIColor,
    inputs: [Input] = [],
    inputsInline: Bool,
    position: WorkspacePoint,
    shadow: Bool,
    tooltip: String,
    comment: String,
    helpURL: String,
    deletable: Bool,
    movable: Bool,
    disabled: Bool,
    editable: Bool,
    outputConnection: Connection?,
    previousConnection: Connection?,
    nextConnection: Connection?,
    style: Style,
    mutator: Mutator?,
    extensions: [BlockExtension]) throws
  {
    self.uuid = uuid ?? UUID().uuidString
    self.name = name
    self.color = color
    self.inputs = inputs
    self.initialInputsInlineValue = inputsInline
    self.inputsInline = inputsInline
    self.position = position
    self.shadow = shadow
    self.outputConnection = outputConnection
    self.previousConnection = previousConnection
    self.nextConnection = nextConnection
    self.tooltip = tooltip
    self.comment = comment
    self.helpURL = helpURL
    self.deletable = deletable
    self.movable = movable
    self.disabled = disabled
    self.editable = editable
    self.style = style

    super.init()

    // Set the source block for properties
    self.outputConnection?.sourceBlock = self
    self.previousConnection?.sourceBlock = self
    self.nextConnection?.sourceBlock = self

    // Finish updating model hierarchy for inputs and connections
    updateInputs()
    updateDirectConnections()

    // Set the mutator
    if let aMutator = mutator {
      try setMutator(aMutator)
    }

    // Apply the extensions
    for blockExtension in extensions {
      try blockExtension.run(block: self)
    }
  }

  // MARK: - Public

  /**
   Returns a list of all connections directly or indirectly connected to this block.

   - returns: A list of all connections directly or indirectly connected to this block.
   */
  public func allConnectionsForTree() -> [Connection] {
    var connections = [Connection]()

    for connection in self.directConnections {
      connections.append(connection)

      if connection != self.previousConnection && connection != self.outputConnection &&
        connection.targetBlock != nil {
          connections.append(contentsOf: connection.targetBlock!.allConnectionsForTree())
      }
    }

    return connections
  }

  /**
  Follows the chain of next connections starting from this block and returns the last block in the
  chain.
  */
  public func lastBlockInChain() -> Block {
    var lastBlockInChain = self
    while let block = lastBlockInChain.nextBlock {
      lastBlockInChain = block
    }
    return lastBlockInChain
  }

  /**
  Follows the chain of input value connections starting from this block, returning the last input
  value connection. For each block in the chain, if there is exactly one input value, it either
  follows the input to the next block or returns the input value connection if it's the last block.
  Nil is returned if any block in the chain has no or multiple input values.
  
  - returns: The last input connection in the chain, or nil if none could be found.
  */
  public func lastInputValueConnectionInChain() -> Connection? {
    var currentBlock = self

    while true {
      guard let inputConnection = currentBlock.onlyValueInput()?.connection else {
        return nil
      }

      if let nextBlock = inputConnection.targetBlock {
        currentBlock = nextBlock
      } else {
        return inputConnection
      }
    }
  }

  /**
   Follows all input and next connections starting from this block and returns all blocks connected
   to this block, including this block.

   - returns: A list of all blocks connected to this block, including this block.
   */
  public func allBlocksForTree() -> [Block] {
    var blocks = [self]

    // Follow input connections
    for input in self.inputs {
      if let connectedBlock = input.connectedBlock {
        blocks.append(contentsOf: connectedBlock.allBlocksForTree())
      }
      if let connectedShadowBlock = input.connectedShadowBlock {
        blocks.append(contentsOf: connectedShadowBlock.allBlocksForTree())
      }
    }

    // Follow next connection
    if let nextBlock = self.nextBlock {
      blocks.append(contentsOf: nextBlock.allBlocksForTree())
    }

    // Follow next shadow connection
    if let nextShadowBlock = self.nextShadowBlock {
      blocks.append(contentsOf: nextShadowBlock.allBlocksForTree())
    }

    return blocks
  }

  /**
   Finds the first input with a given name.

   - parameter name: The input name
   - returns: The first input with that name or nil.
   */
  public func firstInput(withName name: String) -> Input? {
    if name == "" {
      return nil
    }
    for input in inputs {
      if input.name == name {
        return input
      }
    }
    return nil
  }

  /**
   Finds the first field with a given name.

   - parameter name: The field name
   - returns: The first field with that name or nil.
   */
  public func firstField(withName name: String) -> Field? {
    if name == "" {
      return nil
    }
    for input in inputs {
      for field in input.fields {
        if field.name == name {
          return field
        }
      }
    }
    return nil
  }

  /**
   Copies this block and all of the blocks connected to it through its input or next connections.

   - returns: A `BlockTree` tuple of the copied block tree.
   - throws:
   `BlocklyError`: Thrown if copied blocks could not be connected to each other.
   */
  public func deepCopy() throws -> BlockTree {
    let newBlock = try BlockBuilder(block: self).makeBlock(shadow: shadow)
    var copiedBlocks = [Block]()
    copiedBlocks.append(newBlock)

    // Copy block(s) from input connections
    for i in 0 ..< self.inputs.count {
      let inputConnection = self.inputs[i].connection
      let copiedInputConnection = newBlock.inputs[i].connection

      // Check that the input connections are consistent between the original and copied blocks
      if inputConnection == nil && copiedInputConnection != nil {
        throw BlocklyError(.illegalState,
          "An input connection was created, but no such connection exists on the original block.")
      } else if inputConnection != nil && copiedInputConnection == nil {
        throw BlocklyError(.illegalState,
          "An input connection was not copied from the original block.")
      }

      // Perform a copy of the connected block (if it exists)
      if let connectedBlock = self.inputs[i].connectedBlock {
        let copyResult = try connectedBlock.deepCopy()
        if self.inputs[i].connection!.type == .nextStatement {
          try copiedInputConnection!.connectTo(copyResult.rootBlock.previousConnection)
        } else if self.inputs[i].connection!.type == .inputValue {
          try copiedInputConnection!.connectTo(copyResult.rootBlock.outputConnection)
        }
        copiedBlocks.append(contentsOf: copyResult.allBlocks)
      }

      // Perform a copy of the connected shadow block (if it exists)
      if let connectedShadowBlock = self.inputs[i].connectedShadowBlock {
        let copyResult = try connectedShadowBlock.deepCopy()
        if self.inputs[i].connection!.type == .nextStatement {
          try copiedInputConnection!.connectShadowTo(copyResult.rootBlock.previousConnection)
        } else if self.inputs[i].connection!.type == .inputValue {
          try copiedInputConnection!.connectShadowTo(copyResult.rootBlock.outputConnection)
        }
        copiedBlocks.append(contentsOf: copyResult.allBlocks)
      }
    }

    // Check that the next connections are consistent between the original and copied blocks
    let nextConnection = self.nextConnection
    let copiedNextConnection = newBlock.nextConnection
    if nextConnection == nil && copiedNextConnection != nil {
      throw BlocklyError(.illegalState,
        "A next connection was created, but no such connection exists on the original block.")
    } else if nextConnection != nil && copiedNextConnection == nil {
      throw BlocklyError(.illegalState,
        "The next connection was not copied from the original block.")
    }

    // Copy block(s) from next connection
    if let nextBlock = self.nextBlock {
      let copyResult = try nextBlock.deepCopy()
      try copiedNextConnection!.connectTo(copyResult.rootBlock.previousConnection)
      copiedBlocks.append(contentsOf: copyResult.allBlocks)
    }

    // Copy shadow block(s) from next connection
    if let nextShadowBlock = self.nextShadowBlock {
      let copyResult = try nextShadowBlock.deepCopy()
      try copiedNextConnection!.connectShadowTo(copyResult.rootBlock.previousConnection)
      copiedBlocks.append(contentsOf: copyResult.allBlocks)
    }

    return BlockTree(rootBlock: newBlock, allBlocks: copiedBlocks)
  }

  /**
   A convenience method that should be called inside the `didSet { ... }` block of instance
   properties.

   If `property != oldValue`, this method will automatically call `notifyDidUpdateBlock()`.
   If `property == oldValue`, nothing happens.

   Usage:
   ```
   var someString: String {
     didSet { didSetProperty(someString, oldValue) }
   }
   ```

   - parameter property: The instance property that had been set.
   - parameter oldValue: The old value of the instance property.
   - returns: `true` if `property` is now different than `oldValue`. `false` otherwise.
   */
  @discardableResult
  public func didSetProperty<T: Equatable>(_ property: T, _ oldValue: T) -> Bool {
    if property == oldValue {
      return false
    }
    notifyDidUpdateBlock()
    return true
  }

  // MARK: - Listeners

  /**
   Sends a notification to `self.listeners` that this block has been updated.
   */
  public func notifyDidUpdateBlock() {
    listeners.forEach { $0.didUpdateBlock(self) }
  }

  // MARK: - Internal - For testing only

  /**
   - returns: The only value input on the block, or null if there are zero or more than one.
   */
  internal func onlyValueInput() -> Input? {
    var valueInput: Input?
    for input in self.inputs {
      if input.type == .value {
        if valueInput != nil {
          // Found more than one value input
          return nil
        }
        valueInput = input
      }
    }
    return valueInput
  }

  // MARK: - Inputs

  /**
   Append an input to the end of `self.inputs`.

   - parameter input: The `Input` to append.
   */
  public func appendInput(_ input: Input) {
    inputs.append(input)
  }

  /**
   Insert an input at the specified position.

   - parameter input: The `Input` to insert.
   - parameter index: The position to insert the input into `self.inputs`.
   */
  public func insertInput(_ input: Input, at index: Int) {
    inputs.insert(input, at: index)
  }

  /**
   Remove an input from the block. If the input doesn't exist, nothing happens.

   - parameter input: The `Input` to remove.
   - note: The input must be disconnected from any connected shadow and non-shadow blocks prior to
   calling this method or else an error is thrown.
   - throws:
   `BlocklyError`: Thrown if `input` has a shadow or non-shadow block still connected to it.
   */
  public func removeInput(_ input: Input) throws {
    if let index = inputs.index(of: input) {
      // Automatically disconnect any blocks connected to this one
      if let connection = input.connection,
        connection.connected || connection.shadowConnected
      {
        throw BlocklyError(.illegalState,
          "Input must disconnect its shadow and non-shadow blocks prior to being removed " +
          "from its source block.")
      }

      // Remove input
      input.sourceBlock = nil
      inputs.remove(at: index)
    }
  }

  /**
   Updates `self.inputs` to reflect the current internal state of this block.
   */
  private func updateInputs() {
    for input in self.inputs {
      input.sourceBlock = self
      input.inline = inputsInline

      for field in input.fields {
        field.editable = editable
      }
    }
  }

  // MARK: - Connections

  /**
   Updates `self.directConnections` to reflect the current internal state of this block.
   */
  private func updateDirectConnections() {
    directConnections.removeAll()

    for input in inputs {
      if let connection = input.connection {
        directConnections.append(connection)
      }
    }
    if let connection = previousConnection {
      directConnections.append(connection)
    }
    if let connection = outputConnection {
      directConnections.append(connection)
    }
    if let connection = nextConnection {
      directConnections.append(connection)
    }
  }

  // MARK: - Mutator

  /**
   Associates a mutator with this block and immediately calls `mutateBlock()` on it.

   - parameter mutator: The mutator to associate with the block.
   - throws:
   `BlocklyError`: Thrown if a mutator has already been associated with the block or if
   `mutator.mutateBlock()` throws an error.
   */
  public func setMutator(_ mutator: Mutator) throws {
    if self.mutator != nil {
      throw BlocklyError(.illegalState,
        "`self.mutator` has already been defined on this block. " +
        "This value cannot be set more than once.")
    }

    self.mutator = mutator
    mutator.block = self
    try mutator.mutateBlock()
  }

  // MARK: - Block.Style Class

  /**
   Specifies any styles that should be applied to the block during rendering.
   */
  @objc(BKYBlockStyle)
  @objcMembers open class Style: NSObject, NSCopying {
    // MARK: - Constants

    /// Underlying value of `HatType`.
    public typealias HatType = String
    /// Constant value for rendering a hat with a flat top.
    public static let hatNone: HatType = "none"
    /// Constant value for rendering a hat with a half-rounded top and horizontal base.
    public static let hatCap: HatType = "cap"

    // MARK: - Properties

    /// The block that this style is attached to.
    public weak var block: Block?

    /// Specifies the type of hat to render on top of the block. This value is only applied to the
    /// block if it has no previous or output connections.
    public var hat: HatType? {
      didSet {
        if hat == oldValue {
          return
        }
        block?.notifyDidUpdateBlock()
      }
    }

    // MARK: - Initializers

    public required override init() {
      super.init()
    }

    // MARK: - NSCopying Implementation

    public func copy(with zone: NSZone? = nil) -> Any {
      let copy = type(of: self).init()
      copy.hat = hat
      return copy
    }
  }
}
