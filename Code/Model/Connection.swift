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
Component used to create a connection between two |Block| instances.
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
  public unowned let sourceBlock: Block
  public var position: CGPoint = CGPointZero
  public weak var targetConnection: Connection?

  public var typeChecks: [String]? {
    didSet {
      if (typeChecks != nil && targetConnection != nil &&
        !isCompatibleWithConnection(targetConnection!)) {
          // The new value type is not compatible with the existing connection.
          if (isSuperior) {
            targetConnection?.sourceBlock.parentBlock = nil
          } else {
            sourceBlock.parentBlock = nil
          }

          // TODO:(vicng) Generate change event
      }
    }
  }

  public var isSuperior: Bool {
    return (self.type == .InputValue || self.type == .NextStatement)
  }

  // MARK: - Initializers

  public init(type: BKYConnectionType, sourceBlock: Block) {
    self.type = type
    self.sourceBlock = sourceBlock
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
