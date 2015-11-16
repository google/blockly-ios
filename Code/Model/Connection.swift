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
Protocol for events that occur on a `Connection`.
*/
@objc(BKYConnectionListener)
public protocol ConnectionListener {
  /**
  Event that is called when the target connection has changed for a given connection.

  - Parameter connection: The connection whose `targetConnection` value has changed.
  */
  optional func didChangeTargetForConnection(connection: Connection)

  /**
  Event that is called when the highlighted value has changed for a given connection.

  - Parameter connection: The connection whose `highlighted` value has changed.
  */
  optional func didChangeHighlightForConnection(connection: Connection)
}

/**
Protocol for position events that occur on a `Connection`.
*/
@objc(BKYConnectionPositionListener)
public protocol ConnectionPositionListener {
  /**
  Event that is called immediately before the connection's `position` will change.

  - Parameter connection: The connection whose `position` value will change.
  */
  func willChangePositionForConnection(connection: Connection)

  /**
  Event that is called immediately after the connection's `position` has changed.

  - Parameter connection: The connection whose `position` value has changed.
  */
  func didChangePositionForConnection(connection: Connection)
}

/**
Component used to create a connection between two `Block` instances.
*/
@objc(BKYConnection)
public class Connection : NSObject {
  // MARK: - Static Properties

  // NOTE: If OPPOSITE_TYPES is updated, also update ConnectionManager's matchingLists and
  // oppositeLists arrays.
  public static let OPPOSITE_TYPES: [BKYConnectionType] =
  [.NextStatement, .PreviousStatement, .OutputValue, .InputValue]

  // MARK: - Enum - ConnectionType

  /// Represents all possible types of connections.
  @objc
  public enum BKYConnectionType: Int {
    case PreviousStatement = 0, NextStatement, InputValue, OutputValue
  }
  public typealias ConnectionType = BKYConnectionType

  // MARK: - Enum - CheckResultType

  /// Represents result codes when trying to connect two connections
  @objc
  public enum BKYCheckResultType: Int {
    case CanConnect = 0, ReasonSelfConnection, ReasonWrongType, ReasonMustDisconnect,
    ReasonTargetNull, ReasonChecksFailed
  }
  public typealias CheckResultType = BKYCheckResultType

  // MARK: - Properties

  /// A globally unique identifier
  public let uuid: String
  /// The connection type
  public let type: BKYConnectionType
  /// The block that holds this connection
  public weak var sourceBlock: Block!
  /// If this connection belongs to a value or statement input, this is its source
  public private(set) weak var sourceInput: Input?
  /**
  The position of this connection in the workspace.
  NOTE: While this value *should* be stored in a Layout subclass, it's more efficient to simply
  store the absolute position here since it's the only relevant property needed.
  */
  public private(set) var position: WorkspacePoint = WorkspacePointZero
  /// The connection that this one is connected to
  public private(set) weak var targetConnection: Connection?
  /// The source block of the `targetConnection`
  public var targetBlock: Block? {
    return targetConnection?.sourceBlock
  }
  /// True if the target connection is non-null, false otherwise.
  public var connected: Bool {
    return targetConnection != nil
  }
  /**
  The set of checks for this connection. Two Connections may be connected if one of them
  supports any connection (when this is null) or if they share at least one common check
  value. For example, {"Number", "Integer", "MyValueType"} and {"AnotherType", "Integer"} would
  be valid since they share "Integer" as a check.
  */
  public var typeChecks: [String]? {
    didSet {
      if targetConnection != nil && !typeChecksMatchWithConnection(targetConnection!) {
        // The new value type is not compatible with the existing connection. Disconnect it.
        disconnect()
      }
    }
  }
  /// Whether the connection has high priority in the context of bumping connections away.
  public var highPriority: Bool {
    return (self.type == .InputValue || self.type == .NextStatement)
  }

  /// Connection listeners
  public let listeners = WeakSet<ConnectionListener>()

  /// Connection position listeners
  public let positionListeners = WeakSet<ConnectionPositionListener>()

  /// Keeps track of all block uuid's that are telling this connection to be 
  /// highlighted
  private var _highlights = Set<String>()

  /// Flag if this connection should be highlighted in the UI
  public var highlighted: Bool {
    return !_highlights.isEmpty
  }

  // MARK: - Initializers

  public init(type: BKYConnectionType, sourceInput: Input? = nil) {
    self.uuid = NSUUID().UUIDString
    self.type = type
    self.sourceInput = sourceInput
  }

  /**
  Connect this to another connection.

  - Parameter connection: The other connection
  - Throws:
  `BlocklyError`: Thrown if the connection could not be made, with error code .ConnectionInvalid
  */
  public func connectTo(connection: Connection?) throws {
    if connection == targetConnection {
      // Already connected
      return
    }

    switch canConnectWithReasonTo(connection) {
    case .ReasonSelfConnection:
      throw BlocklyError(.ConnectionInvalid, "Cannot connect a block to itself.")
    case .ReasonWrongType:
      throw BlocklyError(.ConnectionInvalid, "Cannot connect these types.")
    case .ReasonMustDisconnect:
      throw BlocklyError(.ConnectionInvalid,
        "Must disconnect from current block before connecting to a new one.")
    case .ReasonTargetNull:
      throw BlocklyError(.ConnectionInvalid, "Cannot connect to a null connection")
    case .ReasonChecksFailed:
      throw BlocklyError(.ConnectionInvalid, "Cannot connect, checks do not match.")
    case .CanConnect:
      // Connection can be made, continue.
      break
    }

    if let newTargetConnection = connection {
      // Set targetConnections for both sides before sending out delegate event
      self.targetConnection = newTargetConnection
      newTargetConnection.targetConnection = self

      // Send delegate events
      listeners.forEach { $0.didChangeTargetForConnection?(self) }
      newTargetConnection.listeners.forEach {
        $0.didChangeTargetForConnection?(newTargetConnection)
      }
    }
  }

  /**
  Removes the connection between this and the Connection this is connected to. If this is not
  connected disconnect() does nothing.
  */
  public func disconnect() {
    guard let oldTargetConnection = targetConnection else {
      return
    }

    // Set targetConnections for both sides before sending out delegate event
    self.targetConnection = nil
    oldTargetConnection.targetConnection = nil

    // Send delegate events
    listeners.forEach { $0.didChangeTargetForConnection?(self) }
    oldTargetConnection.listeners.forEach { $0.didChangeTargetForConnection?(oldTargetConnection) }
  }

  /**
  Check if this can be connected to the target connection.

  - Parameter target: The connection to check.
  - Returns: True if the target can be connected, false otherwise.
  */
  public func canConnectTo(target: Connection) -> Bool {
    return canConnectWithReasonTo(target) == .CanConnect
  }

  /**
  Check if this can be connected to the target connection, with a specific reason.

  - Parameter target: The `Connection` to check compatibility with.
  - Returns: CheckResultType.CanConnect if the connection is legal, an error code otherwise.
  */
  public func canConnectWithReasonTo(target: Connection?) -> CheckResultType {
    guard let aTarget = target else {
      return .ReasonTargetNull
    }
    if aTarget.sourceBlock == self.sourceBlock {
      return .ReasonSelfConnection
    }
    if aTarget.type != Connection.OPPOSITE_TYPES[self.type.rawValue] {
      return .ReasonWrongType
    }
    if self.targetConnection != nil {
      return .ReasonMustDisconnect
    }
    if !typeChecksMatchWithConnection(aTarget) {
      return .ReasonChecksFailed
    }
    return .CanConnect
  }

  /**
  Returns the distance between this connection and another connection.

  - Parameter other: The other `Connection` to measure the distance to.
  - Returns: The distance between connections.
  */
  public func distanceFromConnection(other: Connection) -> CGFloat {
    let xDiff = position.x - other.position.x
    let yDiff = position.y - other.position.y
    return sqrt(xDiff * xDiff + yDiff * yDiff)
  }

  /**
  Adds a highlight to this connection for a block. If there were no previous highlights for this
  connection, the `highlighted` value is changed to `true` and its listeners are notified.
  
  - Parameter block: The given block
  */
  public func addHighlightForBlock(block: Block) {
    if !_highlights.contains(block.uuid) {
      _highlights.insert(block.uuid)

      if _highlights.count == 1 {
        listeners.forEach { $0.didChangeHighlightForConnection?(self) }
      }
    }
  }

  /**
  Removes the highlight from this connection for a block. If there are no highlights after this
  one is removed, the `highlighted` value is changed to `false` and its listeners are notified.
  
  - Parameter block: The given block
  */
  public func removeHighlightForBlock(block: Block) {
    if _highlights.contains(block.uuid) {
      _highlights.remove(block.uuid)

      if _highlights.count == 0 {
        listeners.forEach { $0.didChangeHighlightForConnection?(self) }
      }
    }
  }

  /**
  Move the connection to a specific position.

  - Parameter position: The position to move to.
  - Parameter offset: An additional offset, usually the position of the parent view in the workspace
  view.
  */
  public func moveToPosition(position: WorkspacePoint, withOffset offset: WorkspacePoint? = nil) {
    let newX = position.x + (offset?.x ?? 0)
    let newY = position.y + (offset?.y ?? 0)

    if self.position.x == newX && self.position.y == newY {
      return
    }

    positionListeners.forEach { $0.willChangePositionForConnection(self) }
    self.position.x = newX
    self.position.y = newY
    positionListeners.forEach { $0.didChangePositionForConnection(self) }
  }

  // MARK: - Private

  /**
  Returns if this connection is compatible with another connection with respect to the value type
  system.

  - Parameter target: Connection to compare against.
  - Returns: True if either connection's `typeChecks` value is nil, or if both connections share
  a common `typeChecks` value. False, otherwise.
  */
  private func typeChecksMatchWithConnection(target: Connection) -> Bool {
    if self.typeChecks == nil || target.typeChecks == nil {
      return true
    }
    // The list of checks is expected to be very small (1 or 2 items usually), so the
    // n^2 approach should be fine.
    for selfTypeCheck in self.typeChecks! {
      for targetTypeCheck in target.typeChecks! {
        if selfTypeCheck == targetTypeCheck {
          return true
        }
      }
    }
    return false
  }
}
