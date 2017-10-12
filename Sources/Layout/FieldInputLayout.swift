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
 Class for a `FieldInput`-based `Layout`.
 */
@objc(BKYFieldInputLayout)
@objcMembers open class FieldInputLayout: FieldLayout {

  // MARK: - Properties

  /// The `FieldInput` that backs this layout
  private let fieldInput: FieldInput

  /// The current text value that should be used when rendering this layout.
  /// This value is automatically set to `self.fieldInput.text` on initialization and
  /// whenever `self.fieldInput.text` is updated.
  /// However, it can be set to any value outside of these calls (e.g. for temporary input
  /// purposes).
  open var currentTextValue: String {
    didSet {
      if currentTextValue != oldValue {
        updateLayoutUpTree()
      }
    }
  }

  // MARK: - Initializers

  /**
   Initializes the input field layout.

   - parameter fieldInput: The `FieldInput` model for this layout.
   - parameter engine: The `LayoutEngine` to associate with this layout.
   - parameter measurer: The `FieldLayoutMeasurer.Type` to measure this layout.
   */
  public init(fieldInput: FieldInput, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type) {
    self.fieldInput = fieldInput
    self.currentTextValue = fieldInput.text
    super.init(field: fieldInput, engine: engine, measurer: measurer)
  }

  // MARK: - Super

  open override func didUpdateField(_ field: Field) {
    // Update current text value to match the field now
    currentTextValue = fieldInput.text

    super.didUpdateField(field)
  }

  // MARK: - Public

  /**
   Updates `self.fieldInput` from the given value. If the value was changed, the layout tree
   is updated to reflect the change.

   - parameter text: The value used to update `self.fieldInput`.
   */
  open func updateText(_ text: String) {
    captureChangeEvent {
      fieldInput.text = text
      currentTextValue = fieldInput.text
    }

    // Perform a layout up the tree
    updateLayoutUpTree()
  }
}
