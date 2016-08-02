/*
 * Copyright 2016 Google Inc. All Rights Reserved.
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
 Class for a `FieldAngle`-based `Layout`.
 */
@objc(BKYFieldAngleLayout)
public class FieldAngleLayout: FieldLayout {

  // MARK: - Properties

  /// The target `FieldAngle` to lay out
  public let fieldAngle: FieldAngle

  /// The text value that should be used to render the value of `FieldAngle`.
  public var textValue: String = ""

  // MARK: - Initializers

  public init(angle: FieldAngle, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type) {
    self.fieldAngle = angle
    super.init(field: fieldAngle, engine: engine, measurer: measurer)

    fieldAngle.delegate = self
    updateTextValueFromModel()
  }

  // MARK: - Super

  // TODO:(#114) Remove `override` once `FieldLayout` is deleted.
  public override func didUpdateField(field: Field) {
    // Update `self.currentTextValue`
    updateTextValueFromModel()

    // Perform a layout up the tree
    updateLayoutUpTree()
  }

  // MARK: - Public

  /**
   Updates `self.fieldAngle` from the given text value.

   - Parameter text: The text that should be used to update `self.fieldAngle`. If `text` is not
   a valid integer, `self.fieldAngle` is not updated.
   */
  public func updateAngleFromText(text: String) {
    if let newAngle = Int(text ?? "") { // Only update it if it's a valid value
      fieldAngle.angle = newAngle
    }
  }

  // MARK: - Private

  private func updateTextValueFromModel() {
    textValue = String(fieldAngle.angle ?? 0) + "°"
  }
}
