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
An input field for a colour value.
*/
@objc(BKYFieldColour)
public final class FieldColour: Field {
  // MARK: - Properties

  public var colour: UIColor {
    didSet {
      if !self.editable {
        self.colour = oldValue
      }
      if self.colour != oldValue {
        delegate?.didUpdateField(self)
      }
    }
  }

  // MARK: - Initializers

  public init(name: String, colour: UIColor) {
    self.colour = colour

    super.init(name: name)
  }

  // MARK: - Super

  public override func copyField() -> Field {
    return FieldColour(name: name, colour: colour)
  }

  public override func setValueFromSerializedText(text: String) throws {
    if let colour = UIColor.bky_colorFromRGB(text) {
      self.colour = colour
    } else {
      throw BlocklyError(.XMLParsing,
        "Could not parse '\(text)' into a colour. The value must be of the form '#RRGGBB'.")
    }
  }

  public override func serializedText() throws -> String? {
    // Returns a string of the form "#rrggbb"
    let rgba = self.colour.bky_rgba()
    return String(format: "#%02x%02x%02x", arguments: [
      UInt(round(rgba.red * 255)),
      UInt(round(rgba.green * 255)),
      UInt(round(rgba.blue * 255))])
  }
}
