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
@objc(BKYConnectionDelegate)
public protocol ConnectionDelegate {
  /**
  Event that is called when the target connection has been changed for a given connection.

  - Parameter connection: The connection whose `targetConnection` has been changed.
  */
  func didChangeTargetForConnection(connection: Connection)
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

  /// The connection type
  public let type: BKYConnectionType
  /// The block that holds this connection
  public weak var sourceBlock: Block!
  /// If this connection belongs to a value or statement input, this is its source
  public private(set) weak var sourceInput: Input?
  /// The position of this connection in the workspace.
  public var position: CGPoint = CGPointZero
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
  public var dragMode: Bool = false
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

  public weak var delegate: ConnectionDelegate?

  // MARK: - Initializers

  public init(type: BKYConnectionType, sourceInput: Input? = nil) {
    self.type = type
    self.sourceInput = sourceInput
  }

  /**
  Connect this to another connection.

  - Parameter connection: The other connection
  - Throws:
  `BlockError`: Thrown if the connection could not be made, with error code .InvalidConnection
  */
  public func connectTo(connection: Connection?) throws {
    if connection == targetConnection {
      // Already connected
      return
    }

    switch canConnectWithReasonTo(connection) {
    case .ReasonSelfConnection:
      throw BlockError(.InvalidConnection, "Cannot connect a block to itself.")
    case .ReasonWrongType:
      throw BlockError(.InvalidConnection, "Cannot connect these types.")
    case .ReasonMustDisconnect:
      throw BlockError(.InvalidConnection,
        "Must disconnect from current block before connecting to a new one.")
    case .ReasonTargetNull:
      throw BlockError(.InvalidConnection, "Cannot connect to a null connection")
    case .ReasonChecksFailed:
      throw BlockError(.InvalidConnection, "Cannot connect, checks do not match.")
    case .CanConnect:
      // Connection can be made, continue.
      break
    }

    if let newTargetConnection = connection {
      // Set targetConnections for both sides before sending out delegate event
      self.targetConnection = newTargetConnection
      newTargetConnection.targetConnection = self

      // Send delegate events
      self.delegate?.didChangeTargetForConnection(self)
      newTargetConnection.delegate?.didChangeTargetForConnection(newTargetConnection)
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
    self.delegate?.didChangeTargetForConnection(self)
    oldTargetConnection.delegate?.didChangeTargetForConnection(oldTargetConnection)
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
  Returns the connection that is closest to this connection.

  - Parameter one: The first `Connection` to check.
  - Parameter two: The second `Connection` to check.
  - Returns: The closer of the two connections.
  */
  public func closerConnectionBetween(one: Connection, and two: Connection) -> Connection {
    if distanceFromConnection(one) < distanceFromConnection(two) {
      return one
    }
    return two
  }

  // MARK: - Private

  /**
  Returns if this connection is compatible with another connection with respect to the value type
  system.  E.g. square_root("Hello") is not compatible.

  - Parameter target: Connection to compare against.
  - Returns: True if the connections share a type.
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
