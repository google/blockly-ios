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
 Class representing an input (value, statement, or dummy). To create an `Input` object, use
 `InputBuilder`
*/
@objc(BKYInput)
@objcMembers public final class Input : NSObject {
  // MARK: - Constants

  /** Represents types of inputs. */
  @objc(BKYInputType)
  public enum InputType: Int {
    case
      /// Specifies the input is a value input.
      value = 0,
      /// Specifies the input is a statement input.
      statement,
      /// Specifies the input is a dummy input.
      dummy

    /// The string describing the type of this input.
    public var stringValue : String {
      return InputType.stringMapping[self]!
    }

    fileprivate static let stringMapping = [
      value: "input_value",
      statement: "input_statement",
      dummy: "input_dummy",
    ]

    internal init?(string: String) {
      guard let value = InputType.stringMapping.bky_anyKeyForValue(string) else {
        return nil
      }
      self = value
    }
  }

  /** Represents valid alignments of a connection's fields. */
  @objc(BKYInputAlignment)
  public enum Alignment: Int {
    case
      /// Specifies the input is left-aligned
      left = -1,
      /// Specifies the input is center-aligned
      center = 0,
      /// Specifies the input is right-aligned
      right = 1

    /// The string describing the alignment of this input.
    public var stringValue : String {
      return Alignment.stringMapping[self]!
    }

    fileprivate static let stringMapping = [
      left: "LEFT",
      center: "CENTRE",
      right: "RIGHT",
    ]

    internal init?(string: String) {
      guard let value = Alignment.stringMapping.bky_anyKeyForValue(string) else {
        return nil
      }
      self = value
    }
  }

  // MARK: - Properties

  /// The type (value, statement, dummy) of the input.
  public let type: InputType
  /// The name of the input.
  public let name: String
  /// A list of `Field` objects for the input.
  public private(set) var fields: [Field]
  /// The `Block` that owns this input.
  public internal(set) weak var sourceBlock: Block? {
    didSet {
      self.connection?.sourceBlock = sourceBlock
    }
  }
  /// The connection for this input, if required.
  public fileprivate(set) var connection: Connection?
  /// The block that is connected to this input, if it exists.
  public var connectedBlock: Block? {
    return connection?.targetBlock
  }
  /// The shadow block that is connected to this input, if it exists
  public var connectedShadowBlock: Block? {
    return connection?.shadowBlock
  }
  /// `true` if the input is visible, `false` otherwise. Defaults to `true`.
  public var visible: Bool = true
  /// The alignment of the input
  public var alignment: Alignment = Alignment.left
  /// `true` if this input should be drawn inline (ie. inside a block).
  /// Defaults to `false`.
  internal var inline: Bool = false

  /// The layout associated with this input.
  public weak var layout: InputLayout?

  // MARK: - Initializers

  /**
   To create an input, use `InputBuilder` instead.
   */
  internal init(type: InputType, name: String, fields: [Field]) {
    self.name = name
    self.type = type
    self.fields = fields

    super.init()

    if (type == .value) {
      self.connection = Connection(type: .inputValue, sourceInput: self)
    } else if (type == .statement) {
      self.connection = Connection(type: .nextStatement, sourceInput: self)
    }

    for field in fields {
      field.sourceInput = self
    }
  }

  // MARK: - Fields

  /**
   Append a field to the end of `self.fields`.

   - parameter field: The `Field` to append.
   */
  public func appendField(_ field: Field) {
    fields.append(field)
    field.sourceInput = self
  }

  /**
   Insert a field at the specified position.

   - parameter field: The `Field` to insert.
   - parameter index: The position to insert the field into `self.fields`.
   */
  public func insertField(_ field: Field, at index: Int) {
    fields.insert(field, at: index)
    field.sourceInput = self
  }

  /**
   Remove a field from the input. If the field doesn't exist, nothing happens.

   - parameter field: The `Field` to remove.
   */
  public func removeField(_ field: Field) {
    if let index = fields.index(of: field) {
      // Remove field
      field.sourceInput = nil
      fields.remove(at: index)
    }
  }
}
