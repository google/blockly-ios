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
Protocol for events that occur on an `Input`.
*/
@objc(BKYInputDelegate)
public protocol InputDelegate {
  /**
  Event that is called when one of the input's properties has changed.

  - Parameter input: The input that changed.
  */
  func inputDidChange(input: Input)
}

/**
Class representing an input (value, statement, or dummy).
*/
@objc(BKYInput)
public class Input : NSObject {
  // MARK: - Enum - InputType

  /** Represents types of inputs. */
  @objc
  public enum BKYInputType: Int {
    case Value = 0, Statement, Dummy

    private static let stringMapping = [
      Value: "input_value",
      Statement: "input_statement",
      Dummy: "input_dummy",
    ]

    public var stringValue : String {
      return BKYInputType.stringMapping[self]!
    }

    internal init?(string: String) {
      guard let value = BKYInputType.stringMapping.bky_anyKeyForValue(string) else {
        return nil
      }
      self = value
    }
  }
  public typealias InputType = BKYInputType

  // MARK: - Enum - InputAlignment

  /** Represents valid alignments of a connection's fields. */
  @objc
  public enum BKYInputAlignment: Int {
    case Left = -1, Centre = 0, Right = 1

    private static let stringMapping = [
      Left: "LEFT",
      Centre: "CENTRE",
      Right: "RIGHT",
    ]

    public var stringValue : String {
      return BKYInputAlignment.stringMapping[self]!
    }

    internal init?(string: String) {
      guard let value = BKYInputAlignment.stringMapping.bky_anyKeyForValue(string) else {
        return nil
      }
      self = value
    }
  }
  public typealias Alignment = BKYInputAlignment

  // MARK: - Properties

  public let type: BKYInputType
  public let name: String
  public private(set) var connection: Connection?
  /// The block that is connected to this input, if it exists.
  public var connectedBlock: Block? {
    return connection?.targetConnection?.sourceBlock
  }

  public var visible: Bool = true
  public var alignment: BKYInputAlignment = BKYInputAlignment.Left
  public internal(set) var fields: [Field] = []
  public weak var delegate: InputDelegate?

  // MARK: - Initializers

  public init(type: InputType, name: String, sourceBlock: Block) {
    self.name = name
    self.type = type

    if (type == .Value) {
      self.connection = Connection(type: .InputValue, sourceBlock: sourceBlock)
    } else if (type == .Statement) {
      self.connection = Connection(type: .NextStatement, sourceBlock: sourceBlock)
    }
  }

  // MARK: - Public

  /**
  Appends a field to `self.fields[]`.

  - Parameter field: The field to append.
  */
  public func appendField(field: Field) {
    fields.append(field)
  }
}
