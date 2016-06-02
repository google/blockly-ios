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

  // TODO:(#104) Remove unused properties

  /// A unique identifier used to identify this block for its lifetime
  public let uuid: String
  public let name: String
  public let category: Int
  public let inputsInline: Bool
  public internal(set) var position: WorkspacePoint = WorkspacePointZero
  /// Flag if this is a shadow block (`true`) or not (`false)
  public let shadow: Bool
  public let outputConnection: Connection?
  public var outputBlock: Block? {
    return outputConnection?.targetBlock
  }
  public let nextConnection: Connection?
  public var nextBlock: Block? {
    return nextConnection?.targetBlock
  }
  public var nextShadowBlock: Block? {
    return nextConnection?.shadowBlock
  }
  public let previousConnection: Connection?
  public var previousBlock: Block? {
    return previousConnection?.targetBlock
  }
  /// If an inferior connection exists, returns either `self.outputConnection` or
  /// `self.previousConnection` (only one may be non-`nil`).
  public var inferiorConnection: Connection? {
    return outputConnection ?? previousConnection
  }

  /// List of connections directly attached to this block
  public private(set) var directConnections = [Connection]()
  public let inputs: [Input]
  public private(set) var color: UIColor
  public var tooltip: String = ""
  public var comment: String = ""
  public var helpURL: String = ""
  public var hasContextMenu: Bool = true
  public var deletable: Bool = true
  public var movable: Bool = true

  // TODO:(#26) Update model so that this property is respected.
  /// Flag indicating if this block can be edited. Updating this property automatically updates
  /// the `editable` on all child fields.
  public var editable: Bool = true {
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
  public var disabled: Bool = false

  /// Flag if this block is at the highest level in the workspace
  public var topLevel: Bool {
    return previousConnection?.targetConnection == nil &&
      previousConnection?.shadowConnection == nil &&
      outputConnection?.targetConnection == nil &&
      outputConnection?.shadowConnection == nil
  }

  public var collapsed: Bool = false
  public var rendered: Bool = false

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
    uuid: String?, name: String, category: Int, color: UIColor, inputs: [Input] = [],
    inputsInline: Bool, shadow: Bool, outputConnection: Connection?,
    previousConnection: Connection?, nextConnection: Connection?)
  {
    self.uuid = uuid ?? NSUUID().UUIDString
    self.name = name
    self.category = category
    self.color = color
    self.inputs = inputs
    self.inputsInline = inputsInline
    self.shadow = shadow
    self.outputConnection = outputConnection
    self.previousConnection = previousConnection
    self.nextConnection = nextConnection

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
          connections.appendContentsOf(connection.targetBlock!.allConnectionsForTree())
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
        blocks.appendContentsOf(connectedBlock.allBlocksForTree())
      }
      if let connectedShadowBlock = input.connectedShadowBlock {
        blocks.appendContentsOf(connectedShadowBlock.allBlocksForTree())
      }
    }

    // Follow next connection
    if let nextBlock = self.nextBlock {
      blocks.appendContentsOf(nextBlock.allBlocksForTree())
    }

    // Follow next shadow connection
    if let nextShadowBlock = self.nextShadowBlock {
      blocks.appendContentsOf(nextShadowBlock.allBlocksForTree())
    }

    return blocks
  }

  /**
   Finds the first input with a given name.

   - Parameter name: The input name
   - Returns: The first input with that name or nil.
   */
  public func firstInputWithName(name: String) -> Input? {
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
  public func firstFieldWithName(name: String) -> Field? {
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
    let newBlock = try Block.Builder(block: self).build(shadow: shadow)
    var copiedBlocks = [Block]()
    copiedBlocks.append(newBlock)

    // Copy block(s) from input connections
    for i in 0 ..< self.inputs.count {
      let inputConnection = self.inputs[i].connection
      let copiedInputConnection = newBlock.inputs[i].connection

      // Check that the input connections are consistent between the original and copied blocks
      if inputConnection == nil && copiedInputConnection != nil {
        throw BlocklyError(.IllegalState,
          "An input connection was created, but no such connection exists on the original block.")
      } else if inputConnection != nil && copiedInputConnection == nil {
        throw BlocklyError(.IllegalState,
          "An input connection was not copied from the original block.")
      }

      // Perform a copy of the connected block (if it exists)
      if let connectedBlock = self.inputs[i].connectedBlock {
        let copyResult = try connectedBlock.deepCopy()
        if self.inputs[i].connection!.type == .NextStatement {
          try copiedInputConnection!.connectTo(copyResult.rootBlock.previousConnection)
        } else if self.inputs[i].connection!.type == .InputValue {
          try copiedInputConnection!.connectTo(copyResult.rootBlock.outputConnection)
        }
        copiedBlocks.appendContentsOf(copyResult.allBlocks)
      }

      // Perform a copy of the connected shadow block (if it exists)
      if let connectedShadowBlock = self.inputs[i].connectedShadowBlock {
        let copyResult = try connectedShadowBlock.deepCopy()
        if self.inputs[i].connection!.type == .NextStatement {
          try copiedInputConnection!.connectShadowTo(copyResult.rootBlock.previousConnection)
        } else if self.inputs[i].connection!.type == .InputValue {
          try copiedInputConnection!.connectShadowTo(copyResult.rootBlock.outputConnection)
        }
        copiedBlocks.appendContentsOf(copyResult.allBlocks)
      }
    }

    // Check that the next connections are consistent between the original and copied blocks
    let nextConnection = self.nextConnection
    let copiedNextConnection = newBlock.nextConnection
    if nextConnection == nil && copiedNextConnection != nil {
      throw BlocklyError(.IllegalState,
        "A next connection was created, but no such connection exists on the original block.")
    } else if nextConnection != nil && copiedNextConnection == nil {
      throw BlocklyError(.IllegalState,
        "The next connection was not copied from the original block.")
    }

    // Copy block(s) from next connection
    if let nextBlock = self.nextBlock {
      let copyResult = try nextBlock.deepCopy()
      try copiedNextConnection!.connectTo(copyResult.rootBlock.previousConnection)
      copiedBlocks.appendContentsOf(copyResult.allBlocks)
    }

    // Copy shadow block(s) from next connection
    if let nextShadowBlock = self.nextShadowBlock {
      let copyResult = try nextShadowBlock.deepCopy()
      try copiedNextConnection!.connectShadowTo(copyResult.rootBlock.previousConnection)
      copiedBlocks.appendContentsOf(copyResult.allBlocks)
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
      if input.type == .Value {
        if valueInput != nil {
          // Found more than one value input
          return nil
        }
        valueInput = input
      }
    }
    return valueInput
  }
}
