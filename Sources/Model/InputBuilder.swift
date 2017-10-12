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
Builder for creating `Input` instances.
*/
@objc(BKYInputBuilder)
@objcMembers public final class InputBuilder: NSObject {
  // MARK: - Properties

  /// The type (value, statement, dummy) of the `Input`.
  public var type: Input.InputType
  /// The type checks for the connection of this `Input`. Defaults to `[String]?`.
  public var connectionTypeChecks: [String]?
  /// The name of the `Input`.
  public var name: String
  /// Specifies whether this `Input` is visible. Defaults to `true`.
  public var visible: Bool = true
  /// Specifies the alignment for the `Input`. Defaults to `Input.Alignment.Left`.
  public var alignment: Input.Alignment = Input.Alignment.left
  /// A list of `Field` objects for the `Input`. Defaults to `[]`.
  public fileprivate(set) var fields: [Field] = []

  // MARK: - Initializers

  /**
   Initializes an input builder with a type and string.

   - parameter type: The type of the `Input`.
   - parameter name: The name of the `Input`.
   */
  public init(type: Input.InputType, name: String) {
    self.type = type
    self.name = name
  }

  /**
   Initialize a builder from an existing input. All values that are not specific to
   a single instance of a input will be copied in to the builder. Any associated layouts are not
   copied into the builder.

   - parameter input: The `Input` to copy.
  */
  public init(input: Input) {
    self.type = input.type
    self.name = input.name
    self.alignment = input.alignment
    self.visible = input.visible
    self.connectionTypeChecks = input.connection?.typeChecks
    super.init()

    appendFields(input.fields)
  }

  // MARK: - Public

  /**
  Creates a new `Input` given the current state of the builder.

  - returns: A new input
  */
  public func makeInput() -> Input {
    let input = Input(type: self.type, name: self.name, fields: fields.map{ $0.copyField() })
    input.visible = visible
    input.alignment = alignment

    if let connection = input.connection {
      connection.typeChecks = self.connectionTypeChecks
    }

    return input
  }

  /**
  Appends a copy of a field to `fields`.

  - parameter field: The `Field` to copy and append.
  */
  public func appendField(_ field: Field) {
    appendFields([field])
  }

  /**
  Appends a copies of fields to `fields`.

  - parameter fields: The list of `Field`'s to copy and append.
  */
  public func appendFields(_ fields: [Field]) {
    self.fields.append(contentsOf: fields.map({ $0.copyField()}))
  }
}
