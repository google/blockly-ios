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
An input field for a 0 to 360 angle.
*/
@objc(BKYFieldAngle)
@objcMembers public final class FieldAngle: Field {
  // MARK: - Properties

  /// The current angle stored in this field.
  public var angle: Double {
    didSet {
      didSetProperty(angle, oldValue)
    }
  }

  /// Number formatter used for serializing the value.
  fileprivate let _serializedNumberFormatter: NumberFormatter = {
    // Set the locale of the serialized number formatter to "English".
    let numberFormatter = NumberFormatter()
    numberFormatter.locale = Locale(identifier: "en")
    numberFormatter.minimumIntegerDigits = 1
    return numberFormatter
  }()

  // MARK: - Initializers

  /**
   Initializes the angle field.

   - parameter name: The name of this field.
   - parameter angle: The initial angle for this field.
   */
  public init(name: String, angle: Double) {
    self.angle = angle
    super.init(name: name)
  }

  // MARK: - Super

  public override func copyField() -> Field {
    return FieldAngle(name: name, angle: angle)
  }

  public override func setValueFromSerializedText(_ text: String) throws {
    self.angle = try valueFromText(text, numberFormatter: _serializedNumberFormatter)
  }

  public override func serializedText() throws -> String? {
    return _serializedNumberFormatter.string(from: NSNumber(value: angle))
  }

  // MARK: - Private

  /**
   Parses given text into a `Double` value, using a given `NSNumberFormatter`.

   - parameter text: The text to parse
   - parameter numberFormatter: The number formatter to parse the text
   - returns: The parsed value
   - throws:
   `BlocklyError`: Thrown if the text value could not be parsed into a valid `Double`.
   */
  fileprivate func valueFromText(_ text: String, numberFormatter: NumberFormatter) throws
    -> Double
  {
    let trimmedText =
      text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

    if trimmedText.isEmpty {
      throw BlocklyError(.illegalArgument,
        "An empty value cannot be parsed into a number. The value must be a valid number.")
    }

    guard let value = numberFormatter.number(from: text)?.doubleValue else {
      throw BlocklyError(.illegalArgument,
        "Could not parse value [`\(text)`] into a number. The value must be a valid number.")
    }

    if !value.isFinite {
      throw BlocklyError(.illegalArgument, "Value [`\(text)`] cannot be NaN or infinite.")
    }

    return value
  }
}
