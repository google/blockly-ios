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
@objc(BKYBlockDelegate)
public protocol BlockDelegate: class {
  /**
   Event that is fired when one of a block's properties has changed.

   - Parameter block: The `Block` that changed.
   */
  func didUpdate(block: Block)
}

/**
Class that represents a single block.
*/
@objc(BKYBlock)
public final class Block : NSObject {
  // MARK: - Aliases

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
  /// Flag indicating if input connectors should be drawn inside a block (`true`) or
  /// on the edge of the block (`false`)
  public let inputsInline: Bool
  /// The absolute position of the block, in the Workspace coordinate system
  public internal(set) var position: WorkspacePoint = WorkspacePointZero
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
  /// - Note: A block may only have one non-nil `self.outputConnection` or `self.previousConnection`
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
  public let inputs: [Input]
  /// The color of the block
  public let color: UIColor
  /// Tooltip text of the block
  public var tooltip: String {
    didSet { didSetEditableProperty(&tooltip, oldValue) }
  }
  /// The comment text of the block
  public var comment: String {
    didSet { didSetEditableProperty(&comment, oldValue) }
  }
  /// A help URL to learn more info about this block
  public var helpURL: String {
    didSet { didSetEditableProperty(&helpURL, oldValue) }
  }
  /// Flag indicating if this block may be deleted
  public var deletable: Bool {
    didSet { didSetProperty(deletable, oldValue) }
  }
  /// Flag indicating if this block may be moved by the user
  public var movable: Bool {
    didSet { didSetProperty(movable, oldValue) }
  }
  /// Flag indicating if this block has had its user interaction disabled
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

      for input in self.inputs {
        for field in input.fields {
          field.editable = editable
        }
      }
    }
  }

  /// Flag indicating if this block is at the highest level in the workspace
  public var topLevel: Bool {
    return previousConnection?.targetConnection == nil &&
      previousConnection?.shadowConnection == nil &&
      outputConnection?.targetConnection == nil &&
      outputConnection?.shadowConnection == nil
  }

  /// A delegate for listening to events on this block
  public weak var delegate: BlockDelegate?

  /// Convenience property for accessing `self.delegate` as a BlockLayout
  public var layout: BlockLayout? {
    return self.delegate as? BlockLayout
  }

  // MARK: - Initializers

  /**
  To create a Block, use Block.Builder instead.
  */
  internal init(
    uuid: String?, name: String, color: UIColor, inputs: [Input] = [], inputsInline: Bool,
    shadow: Bool, tooltip: String , comment: String, helpURL: String, deletable: Bool,
    movable: Bool, disabled: Bool, editable: Bool, outputConnection: Connection?,
    previousConnection: Connection?, nextConnection: Connection?)
  {
    self.uuid = uuid ?? UUID().uuidString
    self.name = name
    self.color = color
    self.inputs = inputs
    self.inputsInline = inputsInline
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

    super.init()

    // Finish updating model hierarchy for inputs and connections
    for input in inputs {
      input.sourceBlock = self

      if let connection = input.connection {
        directConnections.append(connection)
      }

      for field in input.fields {
        field.editable = editable
      }
    }
    self.outputConnection?.sourceBlock = self
    self.previousConnection?.sourceBlock = self
    self.nextConnection?.sourceBlock = self

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

  // MARK: - Public

  /**
  Returns a list of all connections directly or indirectly connected to this block.
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
  
  - Returns: The last input connection in the chain, or nil if none could be found.
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

   - Returns: A list of all blocks connected to this block, including this block.
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

   - Parameter name: The input name
   - Returns: The first input with that name or nil.
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

   - Parameter name: The field name
   - Returns: The first field with that name or nil.
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

   - Returns: A `BlockTree` tuple of the copied block tree.
   - Throws:
   `BlocklyError`: Thrown if copied blocks could not be connected to each other.
   */
  public func deepCopy() throws -> BlockTree {
    let newBlock = try Block.Builder(block: self).makeBlock(shadow: shadow)
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

  // MARK: - Internal - For testing only

  /**
  - Returns: The only value input on the block, or null if there are zero or more than one.
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

  // MARK: - Private

  /**
   A convenience method that should be called inside the `didSet { ... }` block of editable instance
   properties.

   If `self.editable == true` and `editableProperty != oldValue`, this method will automatically
   call `delegate?.didUpdateBlock(self)`.

   If `self.editable == true` and `editableProperty == oldValue`, nothing happens.

   If `self.editable == false`, this method automatically reverts `editableProperty` back to
   `oldValue`.

   Usage:
   ```
   var someEditableInteger: Int {
   didSet { didSetEditableProperty(&someEditableInteger, oldValue) }
   }
   ```

   - Parameter editableProperty: The instance property that had been set
   - Parameter oldValue: The old value of the instance property
   - Returns: `true` if `editableProperty` is now different than `oldValue`, `false` otherwise.
   */
  @discardableResult
  public func didSetEditableProperty<T: Equatable>(_ editableProperty: inout T, _ oldValue: T)
    -> Bool
  {
    if !self.editable {
      editableProperty = oldValue
    }
    if editableProperty == oldValue {
      return false
    }
    delegate?.didUpdate(block: self)
    return true
  }

  /**
   A convenience method that should be called inside the `didSet { ... }` block of instance
   properties.

   If `property != oldValue`, this method will automatically call `delegate?.didUpdateBlock(self)`.
   If `editableProperty == oldValue`, nothing happens.

   Usage:
   ```
   var someString: String {
   didSet { didSetProperty(someString, oldValue) }
   }
   ```

   - Parameter property: The instance property that had been set
   - Parameter oldValue: The old value of the instance property
   - Returns: `true` if `property` is now different than `oldValue`, `false` otherwise.
   */
  @discardableResult
  public func didSetProperty<T: Equatable>(_ property: T, _ oldValue: T) -> Bool {
    if property == oldValue {
      return false
    }
    delegate?.didUpdate(block: self)
    return true
  }
}
