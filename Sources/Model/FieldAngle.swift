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

  /// The current angle stored in this field.
  public var angle: Int {
    didSet {
      // Normalize the value that was set
      angle = FieldAngle.normalizeAngle(angle)
      didSetEditableProperty(&angle, oldValue)
    }
  }

  // MARK: - Initializers

  /**
   Initializes the angle field.

   - parameter name: The name of this field.
   - parameter angle: The initial angle for this field.
   */
  public init(name: String, angle: Int) {
    self.angle = FieldAngle.normalizeAngle(angle)

    super.init(name: name)
  }

  // MARK: - Super

  public override func copyField() -> Field {
    return FieldAngle(name: name, angle: angle)
  }

  public override func setValueFromSerializedText(_ text: String) throws {
    if let angle = Int(text) {
      self.angle = angle
    } else {
      throw BlocklyError(.xmlParsing,
        "Could not parse '\(text)' into an angle. The value must be a valid integer.")
    }
  }

  public override func serializedText() throws -> String? {
    return String(self.angle)
  }

  // MARK: - Internal - For testing only

  internal class func normalizeAngle(_ angle: Int) -> Int {
    var normalizedAngle = angle
    if normalizedAngle != 360 {
      normalizedAngle = normalizedAngle % 360
      if normalizedAngle < 0 {
        normalizedAngle += 360
      }
    }
    return normalizedAngle
  }
}
