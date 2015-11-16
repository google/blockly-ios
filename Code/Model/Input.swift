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
  public weak var sourceBlock: Block! {
    didSet {
      self.connection?.sourceBlock = sourceBlock
    }
  }
  public private(set) var connection: Connection?
  /// The block that is connected to this input, if it exists.
  public var connectedBlock: Block? {
    return connection?.targetConnection?.sourceBlock
  }

  public var visible: Bool = true
  public var alignment: BKYInputAlignment = BKYInputAlignment.Left
  public private(set) var fields: [Field] = []

  // TODO(vicng): Consider replacing the layout reference with a delegate or listener
  /// The layout used for rendering this input
  public var layout: InputLayout?

  // MARK: - Initializers

  /**
  To create an Input, use Input.Builder instead.
  */
  internal init(type: InputType, name: String) {
    self.name = name
    self.type = type

    super.init()

    if (type == .Value) {
      self.connection = Connection(type: .InputValue, sourceInput: self)
    } else if (type == .Statement) {
      self.connection = Connection(type: .NextStatement, sourceInput: self)
    }
  }

  // MARK: - Public

  /**
  Appends a field to `self.fields[]`.

  - Parameter field: The field to append.
  */
  public func appendField(field: Field) throws {
    try appendFields([field])
  }

  /**
  Appends a given list of fields to the end of `self.fields[]`.

  - Parameter fields: The fields to append.
  */
  public func appendFields(fields: [Field]) throws {
    for field in fields {
      self.fields.append(field)

      if self.layout != nil {
        // This is an edge case, but if a field is appended after the input has been associated
        // with a layout, then the new field must also have a layout associated with it.
        if let fieldLayout = field.layout {
          self.layout!.appendFieldLayout(fieldLayout)
        } else {
          throw BlocklyError(BlocklyError.Code.LayoutIllegalState,
            "Can't add a field that is missing a layout to an input with an associated layout. " +
            "Did you call layoutBuilder.buildLayoutTreeForField() on this field?")
        }
      }
    }

    self.layout?.updateLayoutUpTree()
  }
}
