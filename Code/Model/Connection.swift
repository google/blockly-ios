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
  // MARK: - Enum - ConnectionType

  /** Represents all possible types of connections. */
  @objc
  public enum BKYConnectionType: Int {
    case InputValue = 1, OutputValue, NextStatement, PreviousStatement
  }
  typealias ConnectionType = BKYConnectionType

  // MARK: - Properties

  public let type: BKYConnectionType
  public weak var sourceBlock: Block!

  /// If this connection belongs to a value or statement input, this is its source
  public private(set) weak var sourceInput: Input?
  public var position: CGPoint = CGPointZero
  public private(set) weak var targetConnection: Connection?
  public var targetBlock: Block? {
    return targetConnection?.sourceBlock
  }

  public var typeChecks: [String]? {
    didSet {
      if (typeChecks != nil && targetConnection != nil &&
        !isCompatibleWithConnection(targetConnection!)) {
          // The new value type is not compatible with the existing connection.

          // TODO:(vicng) Disconnect this connection from its target

          // TODO:(vicng) Generate change event
      }
    }
  }

  public var isSuperior: Bool {
    return (self.type == .InputValue || self.type == .NextStatement)
  }

  public var delegate: ConnectionDelegate?

  // MARK: - Initializers

  public init(type: BKYConnectionType, sourceInput: Input? = nil) {
    self.type = type
    self.sourceInput = sourceInput
  }

  public func connectTo(otherConnection: Connection?) throws -> Bool {
    // TODO:(vicng) This is a very basic implementation. Implement this properly!
    guard let newTargetConnection = otherConnection else {
      // TODO:(vicng) Throw errors when the user tries to make connections that aren't valid
      return false
    }

    // Set targetConnections for both sides before sending out delegate event
    self.targetConnection = newTargetConnection
    newTargetConnection.targetConnection = self

    self.delegate?.didChangeTargetForConnection(self)
    newTargetConnection.delegate?.didChangeTargetForConnection(newTargetConnection)

    return true
  }

  public func disconnect() {
    guard let oldTargetConnection = targetConnection else {
      return
    }

    // Set targetConnections for both sides before sending out delegate event
    self.targetConnection = nil
    oldTargetConnection.targetConnection = nil

    self.delegate?.didChangeTargetForConnection(self)
    oldTargetConnection.delegate?.didChangeTargetForConnection(oldTargetConnection)
  }

  // MARK: - Private

  /**
  Returns if this connection is compatible with another connection with respect to the value type
  system.  E.g. square_root("Hello") is not compatible.

  - Parameter otherConnection: Connection to compare against.
  - Returns: True if the connections share a type.
  */
  private func isCompatibleWithConnection(otherConnection: Connection) -> Bool {
    // TODO:(vicng) Implement this
    return true
  }
}
