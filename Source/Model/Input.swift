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
 Protocol for events that occur on a `Input` instance.
 */
@objc(BKYInputDelegate)
public protocol InputDelegate: class {
}

/**
 Class representing an input (value, statement, or dummy). To create an `Input` object, use
 `Input.Builder`
*/
@objc(BKYInput)
public final class Input : NSObject {
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

  // MARK: - Aliases

  /// Builder for creating `Input` instances
  public typealias Builder = InputBuilder

  // MARK: - Properties

  /// The type (value, statement, dummy) of the input.
  public let type: InputType
  /// The name of the input.
  public let name: String
  /// A list of `Field` objects for the input.
  public let fields: [Field]
  /// The `Block` that owns this input.
  public weak var sourceBlock: Block! {
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

  /// A delegate for listening to events on this input
  public weak var delegate: InputDelegate?

  /// Convenience property for accessing `self.delegate` as an `InputLayout`
  public var layout: InputLayout? {
    return self.delegate as? InputLayout
  }

  // MARK: - Initializers

  /**
  To create an Input, use Input.Builder instead.
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
}
