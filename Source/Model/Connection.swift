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
  func didChangeHighlight(forConnection connection: Connection)
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
  func willChangePosition(forConnection connection: Connection)

  /**
  Event that is called immediately after the connection's `position` has changed.

  - Parameter connection: The connection whose `position` value has changed.
  */
  func didChangePosition(forConnection connection: Connection)
}

/**
Component used to create a connection between two `Block` instances.
*/
@objc(BKYConnection)
public final class Connection : NSObject {
  // MARK: - Static Properties

  // NOTE: If OPPOSITE_TYPES is updated, also update ConnectionManager's matchingLists and
  // oppositeLists arrays.
  /// Specifies which `BKYConnectionType` a `BKYConnectionType` is compatible with.
  public static let OPPOSITE_TYPES: [BKYConnectionType] =
  [.nextStatement, .previousStatement, .outputValue, .inputValue]

  // MARK: - Enum - ConnectionType

  /// Represents all possible types of connections.
  @objc
  public enum BKYConnectionType: Int {
    /// Specifies the connection is a previous connection.
    case previousStatement = 0,
      /// Specifies the connection is a next connection.
      nextStatement,
      /// Specifies the connection is an input connection.
      inputValue,
      /// Specifies the connection is an output connection.
      outputValue
  }
  public typealias ConnectionType = BKYConnectionType

  // MARK: - Enum - CheckResultType

  /// Represents a combination of result codes when trying to connect two connections
  public struct CheckResult: OptionSet {
    internal static let CanConnect = CheckResult(value: .canConnect)
    internal static let ReasonSelfConnection = CheckResult(value: .reasonSelfConnection)
    internal static let ReasonWrongType = CheckResult(value: .reasonWrongType)
    internal static let ReasonMustDisconnect = CheckResult(value: .reasonMustDisconnect)
    internal static let ReasonTargetNull = CheckResult(value: .reasonTargetNull)
    internal static let ReasonShadowNull = CheckResult(value: .reasonShadowNull)
    internal static let ReasonTypeChecksFailed = CheckResult(value: .reasonTypeChecksFailed)
    internal static let ReasonCannotSetShadowForTarget =
      CheckResult(value: .reasonCannotSetShadowForTarget)
    internal static let ReasonInferiorBlockShadowMismatch =
      CheckResult(value: .reasonInferiorBlockShadowMismatch)

    /// Specific reasons why two connections are able or unable connect
    @objc
    public enum BKYConnectionCheckResultValue: Int {
      case canConnect = 1, reasonSelfConnection, reasonWrongType, reasonMustDisconnect,
      reasonTargetNull, reasonShadowNull, reasonTypeChecksFailed, reasonCannotSetShadowForTarget,
      reasonInferiorBlockShadowMismatch

      func errorMessage() -> String? {
        switch (self) {
        case .reasonSelfConnection:
          return "Cannot connect a block to itself."
        case .reasonWrongType:
          return "Cannot connect these types."
        case .reasonMustDisconnect:
          return "Must disconnect from current block before connecting to a new one."
        case .reasonTargetNull, .reasonShadowNull:
          return "Cannot connect to a null connection"
        case .reasonTypeChecksFailed:
          return "Cannot connect, `typeChecks` do not match."
        case .reasonCannotSetShadowForTarget:
          return "Cannot set `self.targetConnection` when the source or target block is a shadow."
        case .reasonInferiorBlockShadowMismatch:
          return "Cannot connect a non-shadow block to a shadow block when the non-shadow block " +
           "connection is of type `.OutputValue` or `.PreviousStatement`."
        case .canConnect:
          // Connection can be made, no error message
          return nil
        }
      }
    }

    /// Specific reasons why two connections are able or unable connect
    public typealias Value = BKYConnectionCheckResultValue

    ///  The underlying raw value for the `CheckResult`.
    public let rawValue : Int

    /**
     Initializes the value with an integer.

     - Parameter rawValue: The integer to seed the `CheckResult` with.
     */
    public init(rawValue: Int) {
      self.rawValue = rawValue
    }

    /**
     Initializes the value with a `Value`.

     - Parameter value: The `Value` to seed the `CheckResult` with.
     */
    public init(value: Value) {
      self.init(rawValue: 1 << value.rawValue)
    }

    /**
     Checks whether the `CheckResult` intersects with another `CheckResult`.

     - Parameter other: The other `CheckResult` to check.
     - Return: `true` if they intersect, `false` otherwise.
     */
    public func intersectsWith(_ other: CheckResult) -> Bool {
      return intersection(other).rawValue != 0
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
  public fileprivate(set) weak var sourceInput: Input?
  /**
  The position of this connection in the workspace.
  NOTE: While this value *should* be stored in a Layout subclass, it's more efficient to simply
  store the absolute position here since it's the only relevant property needed.
  */
  public fileprivate(set) var position: WorkspacePoint = WorkspacePoint.zero
  /// The connection that this one is connected to
  public fileprivate(set) weak var targetConnection: Connection?
  /// The shadow connection that this one is connected to
  public fileprivate(set) weak var shadowConnection: Connection?
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
      if let targetConnection = self.targetConnection,
        !typeChecksMatchWithConnection(targetConnection)
      {
        disconnect()
      }
      if let shadowConnection = self.shadowConnection,
        !typeChecksMatchWithConnection(shadowConnection)
      {
        disconnectShadow()
      }
    }
  }
  /// Whether the connection has high priority in the context of bumping connections away.
  public var highPriority: Bool {
    return (self.type == .inputValue || self.type == .nextStatement)
  }

  /// Connection highlight delegate
  public final weak var highlightDelegate: ConnectionHighlightDelegate?

  /// Connection position delegate
  public final weak var positionDelegate: ConnectionPositionDelegate?

  /// Keeps track of all block uuid's that are telling this connection to be 
  /// highlighted
  fileprivate var _highlights = Set<String>()

  /// Flag if this connection should be highlighted in the UI
  public var highlighted: Bool {
    return !_highlights.isEmpty
  }

  // MARK: - Initializers

  /**
   Creates a `Connection`.

   - Parameter type: The `BKYConnectionType` of this connection.
   - Parameter sourceInput: [Optional] The source input for the `Connection`. Defaults to `nil`.
   */
  public init(type: BKYConnectionType, sourceInput: Input? = nil) {
    self.uuid = UUID().uuidString
    self.type = type
    self.sourceInput = sourceInput
  }

  /**
  Sets `self.targetConnection` to a given connection, and vice-versa.

  - Parameter connection: The other connection
  - Throws:
  `BlocklyError`: Thrown if the connection could not be made, with error code `.ConnectionInvalid`
  */
  public func connectTo(_ connection: Connection?) throws {
    if let newConnection = connection
      , newConnection == targetConnection
    {
      // Already connected
      return
    }

    if let errorMessage = canConnectWithReasonTo(connection).errorMessage() {
      throw BlocklyError(.connectionInvalid, errorMessage)
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
  public func connectShadowTo(_ connection: Connection?) throws {
    if let newConnection = connection
      , newConnection == shadowConnection
    {
      // Already connected
      return
    }

    if let errorMessage = canConnectShadowWithReasonTo(connection).errorMessage() {
      throw BlocklyError(.connectionInvalid, errorMessage)
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
  public func canConnectTo(_ target: Connection) -> Bool {
    return canConnectWithReasonTo(target) == .CanConnect
  }

  /**
  Check if a given connection can be connected to the target connection, with a specific set of
  reasons.

  - Parameter target: The `Connection` to check compatibility with.
  - Returns: If the connection is legal, `[CheckResult.Value.CanConnect]` is returned. Otherwise,
  a set of all error codes are returned.
  */
  public func canConnectWithReasonTo(_ target: Connection?) -> CheckResult {
    var checkResult = CheckResult(rawValue: 0)

    if let aTarget = target {
      if aTarget.sourceBlock == sourceBlock {
        checkResult.formUnion(.ReasonSelfConnection)
      }
      if aTarget.type != Connection.OPPOSITE_TYPES[type.rawValue] {
        checkResult.formUnion(.ReasonWrongType)
      }
      if aTarget.sourceBlock.shadow {
        checkResult.formUnion(.ReasonCannotSetShadowForTarget)
      }
      if !typeChecksMatchWithConnection(aTarget) {
        checkResult.formUnion(.ReasonTypeChecksFailed)
      }
    } else {
      checkResult.formUnion(.ReasonTargetNull)
    }
    if targetConnection != nil {
      checkResult.formUnion(.ReasonMustDisconnect)
    }
    if sourceBlock.shadow {
      checkResult.formUnion(.ReasonCannotSetShadowForTarget)
    }

    if checkResult.rawValue == 0 {
      // All checks passed! Set it to .CanConnect
      checkResult.formUnion(.CanConnect)
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
  public func canConnectShadowWithReasonTo(_ shadow: Connection?) -> CheckResult {
    var checkResult = CheckResult(rawValue: 0)

    if let aShadow = shadow {
      if sourceBlock == aShadow.sourceBlock {
        checkResult.formUnion(.ReasonSelfConnection)
      }
      if aShadow.type != Connection.OPPOSITE_TYPES[type.rawValue] {
        checkResult.formUnion(.ReasonWrongType)
      }
      let isInferiorBlock = (type == .outputValue || type == .previousStatement)
      let inferiorBlock = isInferiorBlock ? sourceBlock : aShadow.sourceBlock
      if !(inferiorBlock?.shadow)! {
        checkResult.formUnion(.ReasonInferiorBlockShadowMismatch)
      }
      if !typeChecksMatchWithConnection(aShadow) {
        checkResult.formUnion(.ReasonTypeChecksFailed)
      }
    } else {
      checkResult.formUnion(.ReasonShadowNull)
    }
    if shadowConnection != nil {
      checkResult.formUnion(.ReasonMustDisconnect)
    }

    if checkResult.rawValue == 0 {
      // All checks passed! Set it to .CanConnect
      checkResult.formUnion(.CanConnect)
    }

    return checkResult
  }

  /**
  Returns the distance between this connection and another connection.

  - Parameter other: The other `Connection` to measure the distance to.
  - Returns: The distance between connections.
  */
  public func distanceFromConnection(_ other: Connection) -> CGFloat {
    let xDiff = position.x - other.position.x
    let yDiff = position.y - other.position.y
    return sqrt(xDiff * xDiff + yDiff * yDiff)
  }

  /**
  Adds a highlight to this connection for a block. If there were no previous highlights for this
  connection, the `highlighted` value is changed to `true` and its listeners are notified.
  
  - Parameter block: The given block
  */
  public func addHighlightForBlock(_ block: Block) {
    if !_highlights.contains(block.uuid) {
      _highlights.insert(block.uuid)

      if _highlights.count == 1 {
        highlightDelegate?.didChangeHighlight(forConnection: self)
      }
    }
  }

  /**
  Removes the highlight from this connection for a block. If there are no highlights after this
  one is removed, the `highlighted` value is changed to `false` and its listeners are notified.
  
  - Parameter block: The given block
  */
  public func removeHighlightForBlock(_ block: Block) {
    if _highlights.contains(block.uuid) {
      _highlights.remove(block.uuid)

      if _highlights.count == 0 {
        highlightDelegate?.didChangeHighlight(forConnection: self)
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
    _ position: WorkspacePoint, withOffset offset: WorkspacePoint = WorkspacePoint.zero)
  {
    let newX = position.x + offset.x
    let newY = position.y + offset.y

    if self.position.x == newX && self.position.y == newY {
      return
    }

    positionDelegate?.willChangePosition(forConnection: self)
    self.position.x = newX
    self.position.y = newY
    positionDelegate?.didChangePosition(forConnection: self)
  }

  // MARK: - Internal - For testing only

  /**
  Returns if this connection is compatible with another connection with respect to the value type
  system.

  - Parameter target: Connection to compare against.
  - Returns: True if either connection's `typeChecks` value is nil, or if both connections share
  a common `typeChecks` value. False, otherwise.
  */
  internal func typeChecksMatchWithConnection(_ target: Connection) -> Bool {
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
