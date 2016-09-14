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
 Delegate for highlight events that occur on a `Connection`.
*/
@objc(BKYConnectionHighlightDelegate)
public protocol ConnectionHighlightDelegate {
  /**
  Event that is called when the highlighted value has changed for a given connection.

  - Parameter connection: The connection whose `highlighted` value has changed.
  */
  func didChangeHighlightForConnection(connection: Connection)
}

/**
Delegate for position events that occur on a `Connection`.
*/
@objc(BKYConnectionPositionDelegate)
public protocol ConnectionPositionDelegate {
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
public final class Connection : NSObject {
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

  /// Represents a combination of result codes when trying to connect two connections
  public struct CheckResult: OptionSetType {
    internal static let CanConnect = CheckResult(value: .CanConnect)
    internal static let ReasonSelfConnection = CheckResult(value: .ReasonSelfConnection)
    internal static let ReasonWrongType = CheckResult(value: .ReasonWrongType)
    internal static let ReasonMustDisconnect = CheckResult(value: .ReasonMustDisconnect)
    internal static let ReasonTargetNull = CheckResult(value: .ReasonTargetNull)
    internal static let ReasonShadowNull = CheckResult(value: .ReasonShadowNull)
    internal static let ReasonChecksFailed = CheckResult(value: .ReasonChecksFailed)
    internal static let ReasonCannotSetShadowForTarget =
      CheckResult(value: .ReasonCannotSetShadowForTarget)
    internal static let ReasonInferiorBlockShadowMismatch =
      CheckResult(value: .ReasonInferiorBlockShadowMismatch)

    /// Specific reasons why two connections are able or unable connect
    public enum Value: Int {
      case CanConnect = 1, ReasonSelfConnection, ReasonWrongType, ReasonMustDisconnect,
      ReasonTargetNull, ReasonShadowNull, ReasonChecksFailed, ReasonCannotSetShadowForTarget,
      ReasonInferiorBlockShadowMismatch

      func errorMessage() -> String? {
        switch (self) {
        case .ReasonSelfConnection:
          return "Cannot connect a block to itself."
        case .ReasonWrongType:
          return "Cannot connect these types."
        case .ReasonMustDisconnect:
          return "Must disconnect from current block before connecting to a new one."
        case .ReasonTargetNull, .ReasonShadowNull:
          return "Cannot connect to a null connection"
        case .ReasonChecksFailed:
          return "Cannot connect, checks do not match."
        case .ReasonCannotSetShadowForTarget:
          return "Cannot set `self.targetConnection` when the source or target block is a shadow."
        case .ReasonInferiorBlockShadowMismatch:
          return "Cannot connect a non-shadow block to a shadow block when the non-shadow block " +
           "connection is of type `.OutputValue` or `.PreviousStatement`."
        case .CanConnect:
          // Connection can be made, no error message
          return nil
        }
      }
    }

    public let rawValue : Int
    public init(rawValue: Int) {
      self.rawValue = rawValue
    }
    public init(value: Value) {
      self.init(rawValue: 1 << value.rawValue)
    }

    public func intersectsWith(other: CheckResult) -> Bool {
      return intersect(other).rawValue != 0
    }

    func errorMessage() -> String? {
      guard !intersectsWith(.CanConnect) else {
        return nil
      }

      var errorMessage = ""
      var i = 1
      while let validValue = Value(rawValue: i) {
        if intersectsWith(CheckResult(value: validValue)) {
          errorMessage += "\(validValue.errorMessage())\n"
        }
        i += 1
      }

      return errorMessage
    }
  }

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
  /// The shadow connection that this one is connected to
  public private(set) weak var shadowConnection: Connection?
  /// The source block of `self.targetConnection`
  public var targetBlock: Block? {
    return targetConnection?.sourceBlock
  }
  /// The source block of `self.shadowConnection`
  public var shadowBlock: Block? {
    return shadowConnection?.sourceBlock
  }
  /// `true` if `self.targetConnection` is non-nil. `false` otherwise.
  public var connected: Bool {
    return targetConnection != nil
  }
  /// `true` if `self.shadowConnection` is non-nil. `false` otherwise.
  public var shadowConnected: Bool {
    return shadowConnection != nil
  }
  /**
  The set of checks for this connection. Two Connections may be connected if one of them
  supports any connection (when this is null) or if they share at least one common check
  value. For example, {"Number", "Integer", "MyValueType"} and {"AnotherType", "Integer"} would
  be valid since they share "Integer" as a check.
  */
  public var typeChecks: [String]? {
    didSet {
      // Disconnect connections that aren't compatible with the new `typeChecks` value.
      if let targetConnection = self.targetConnection
        where !typeChecksMatchWithConnection(targetConnection)
      {
        disconnect()
      }
      if let shadowConnection = self.shadowConnection
        where !typeChecksMatchWithConnection(shadowConnection)
      {
        disconnectShadow()
      }
    }
  }
  /// Whether the connection has high priority in the context of bumping connections away.
  public var highPriority: Bool {
    return (self.type == .InputValue || self.type == .NextStatement)
  }

  /// Connection highlight delegate
  public final weak var highlightDelegate: ConnectionHighlightDelegate?

  /// Connection position delegate
  public final weak var positionDelegate: ConnectionPositionDelegate?

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
  Sets `self.targetConnection` to a given connection, and vice-versa.

  - Parameter connection: The other connection
  - Throws:
  `BlocklyError`: Thrown if the connection could not be made, with error code `.ConnectionInvalid`
  */
  public func connectTo(connection: Connection?) throws {
    if let newConnection = connection
      where newConnection == targetConnection
    {
      // Already connected
      return
    }

    if let errorMessage = canConnectWithReasonTo(connection).errorMessage() {
      throw BlocklyError(.ConnectionInvalid, errorMessage)
    }

    if let newConnection = connection {
      // Set targetConnection for both sides
      targetConnection = newConnection
      newConnection.targetConnection = self
    }
  }

  /**
   Sets `self.shadowConnection` to a given connection, and vice-versa.

   - Parameter connection: The other connection
   - Throws:
   `BlocklyError`: Thrown if the connection could not be made, with error code `.ConnectionInvalid`
   */
  public func connectShadowTo(connection: Connection?) throws {
    if let newConnection = connection
      where newConnection == shadowConnection
    {
      // Already connected
      return
    }

    if let errorMessage = canConnectShadowWithReasonTo(connection).errorMessage() {
      throw BlocklyError(.ConnectionInvalid, errorMessage)
    }

    if let newConnection = connection {
      // Set shadowConnection for both sides
      shadowConnection = newConnection
      newConnection.shadowConnection = self
    }
  }

  /**
   Removes the connection between this and `self.targetConnection`. If `self.targetConnection` is
   `nil`, this method does nothing.
   */
  public func disconnect() {
    guard let oldTargetConnection = targetConnection else {
      return
    }

    // Remove targetConnection for both sides
    targetConnection = nil
    oldTargetConnection.targetConnection = nil
  }

  /**
   Removes the connection between this and `self.shadowConnection`. If `self.shadowConnection` is
   `nil`, this method does nothing.
   */
  public func disconnectShadow() {
    guard let oldShadowConnection = shadowConnection else {
      return
    }

    // Remove shadowConnection for both sides
    shadowConnection = nil
    oldShadowConnection.shadowConnection = nil
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
  Check if a given connection can be connected to the target connection, with a specific set of
  reasons.

  - Parameter target: The `Connection` to check compatibility with.
  - Returns: If the connection is legal, `[CheckResult.Value.CanConnect]` is returned. Otherwise,
  a set of all error codes are returned.
  */
  public func canConnectWithReasonTo(target: Connection?) -> CheckResult {
    var checkResult = CheckResult(rawValue: 0)

    if let aTarget = target {
      if aTarget.sourceBlock == sourceBlock {
        checkResult.unionInPlace(.ReasonSelfConnection)
      }
      if aTarget.type != Connection.OPPOSITE_TYPES[type.rawValue] {
        checkResult.unionInPlace(.ReasonWrongType)
      }
      if aTarget.sourceBlock.shadow {
        checkResult.unionInPlace(.ReasonCannotSetShadowForTarget)
      }
      if !typeChecksMatchWithConnection(aTarget) {
        checkResult.unionInPlace(.ReasonChecksFailed)
      }
    } else {
      checkResult.unionInPlace(.ReasonTargetNull)
    }
    if targetConnection != nil {
      checkResult.unionInPlace(.ReasonMustDisconnect)
    }
    if sourceBlock.shadow {
      checkResult.unionInPlace(.ReasonCannotSetShadowForTarget)
    }

    if checkResult.rawValue == 0 {
      // All checks passed! Set it to .CanConnect
      checkResult.unionInPlace(.CanConnect)
    }

    return checkResult
  }

  /**
   Check if a given connection can be connected to the shadow connection, with a specific set of
   reasons.

   - Parameter shadow: The `Connection` to check compatibility with.
   - Returns: If the connection is legal, `[CheckResult.Value.CanConnect]` is returned. Otherwise,
   a set of all error codes are returned.
   */
  public func canConnectShadowWithReasonTo(shadow: Connection?) -> CheckResult {
    var checkResult = CheckResult(rawValue: 0)

    if let aShadow = shadow {
      if sourceBlock == aShadow.sourceBlock {
        checkResult.unionInPlace(.ReasonSelfConnection)
      }
      if aShadow.type != Connection.OPPOSITE_TYPES[type.rawValue] {
        checkResult.unionInPlace(.ReasonWrongType)
      }
      let isInferiorBlock = (type == .OutputValue || type == .PreviousStatement)
      let inferiorBlock = isInferiorBlock ? sourceBlock : aShadow.sourceBlock
      if !inferiorBlock.shadow {
        checkResult.unionInPlace(.ReasonInferiorBlockShadowMismatch)
      }
      if !typeChecksMatchWithConnection(aShadow) {
        checkResult.unionInPlace(.ReasonChecksFailed)
      }
    } else {
      checkResult.unionInPlace(.ReasonShadowNull)
    }
    if shadowConnection != nil {
      checkResult.unionInPlace(.ReasonMustDisconnect)
    }

    if checkResult.rawValue == 0 {
      // All checks passed! Set it to .CanConnect
      checkResult.unionInPlace(.CanConnect)
    }

    return checkResult
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
        highlightDelegate?.didChangeHighlightForConnection(self)
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
        highlightDelegate?.didChangeHighlightForConnection(self)
      }
    }
  }

  /**
  Move the connection to a specific position.

  - Parameter position: The position to move to.
  - Parameter offset: An additional offset, usually the position of the parent view in the workspace
  view.
  */
  public func moveToPosition(
    position: WorkspacePoint, withOffset offset: WorkspacePoint = WorkspacePointZero)
  {
    let newX = position.x + offset.x
    let newY = position.y + offset.y

    if self.position.x == newX && self.position.y == newY {
      return
    }

    positionDelegate?.willChangePositionForConnection(self)
    self.position.x = newX
    self.position.y = newY
    positionDelegate?.didChangePositionForConnection(self)
  }

  // MARK: - Internal - For testing only

  /**
  Returns if this connection is compatible with another connection with respect to the value type
  system.

  - Parameter target: Connection to compare against.
  - Returns: True if either connection's `typeChecks` value is nil, or if both connections share
  a common `typeChecks` value. False, otherwise.
  */
  internal func typeChecksMatchWithConnection(target: Connection) -> Bool {
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
