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
An input field for a color value.
*/
@objc(BKYFieldColor)
@objcMembers public final class FieldColor: Field {
  // MARK: - Properties

  /// The `UIColor` of this field.
  public var color: UIColor {
    didSet { didSetProperty(color, oldValue) }
  }

  // MARK: - Initializers

  /**
   Initializes the color field.

   - parameter name: The name of this field.
   - parameter color: The initial `UIColor` to set for this field.
   */
  public init(name: String, color: UIColor) {
    self.color = color

    super.init(name: name)
  }

  // MARK: - Super

  public override func copyField() -> Field {
    return FieldColor(name: name, color: color)
  }

  public override func setValueFromSerializedText(_ text: String) throws {
    if let color = ColorHelper.makeColor(rgb: text) {
      self.color = color
    } else {
      throw BlocklyError(.xmlParsing,
        "Could not parse '\(text)' into a color. The value must be of the form '#RRGGBB'.")
    }
  }

  public override func serializedText() throws -> String? {
    // Returns a string of the form "#rrggbb"
    let rgba = self.color.bky_rgba()
    return String(format: "#%02x%02x%02x", arguments: [
      UInt(round(rgba.red * 255)),
      UInt(round(rgba.green * 255)),
      UInt(round(rgba.blue * 255))])
  }
}
