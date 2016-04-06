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

extension Input {
  /**
  Builder for creating instances of `Input`.
  */
  @objc(BKYInputBuilder)
  public class Builder: NSObject {
    // MARK: - Static Properties

    // MARK: - Properties

    public var type: BKYInputType
    public var connectionTypeChecks: [String]?
    public var name: String
    public var visible: Bool = true
    public var alignment: BKYInputAlignment = BKYInputAlignment.Left
    public private(set) var fields: [Field] = []

    // MARK: - Initializers

    public init(type: InputType, name: String) {
      self.type = type
      self.name = name
    }

    /**
    Initialize a builder from an existing input. All values that are not specific to
    a single instance of a input will be copied in to the builder. Any associated layouts are not
    copied into the builder.
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
    Creates a new input given the current state of the builder.

    - Returns: A new input
    */
    public func build() -> Input {
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

    - Parameter field: The `Field` to copy and append.
    */
    public func appendField(field: Field) {
      appendFields([field])
    }

    /**
    Appends a copies of fields to `fields`.

    - Parameter fields: The list of `Field`'s to copy and append.
    */
    public func appendFields(fields: [Field]) {
      self.fields.appendContentsOf(fields.map({ $0.copyField()}))
    }
  }
}
