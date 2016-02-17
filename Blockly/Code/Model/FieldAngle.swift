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
public final class FieldAngle: Field {
  // MARK: - Properties

  public var angle: Int {
    didSet {
      if self.editable {
        // Normalize the value that was set
        self.angle = FieldAngle.normalizeAngle(self.angle)
      } else {
        // Revert the change
        self.angle = oldValue
      }

      if self.angle != oldValue {
        delegate?.didUpdateField(self)
      }
    }
  }

  // MARK: - Initializers

  public init(name: String, angle: Int) {
    self.angle = FieldAngle.normalizeAngle(angle)

    super.init(name: name)
  }

  // MARK: - Super

  public override func copyField() -> Field {
    return FieldAngle(name: name, angle: angle)
  }

  public override func setValueFromSerializedText(text: String) throws {
    if let angle = Int(text) {
      self.angle = angle
    } else {
      throw BlocklyError(.XMLParsing,
        "Could not parse '\(text)' into an angle. The value must be a valid integer.")
    }
  }

  public override func serializedText() throws -> String? {
    return String(self.angle)
  }

  // MARK: - Internal - For testing only

  internal class func normalizeAngle(var angle: Int) -> Int {
    if (angle != 360) {
      angle = angle % 360
      if (angle < 0) {
        angle += 360
      }
    }
    return angle
  }
}
