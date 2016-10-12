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
open class FieldInputLayout: FieldLayout {

  // MARK: - Properties

  /// The `FieldInput` that backs this layout
  open let fieldInput: FieldInput

  /// The value that should be used when rendering this layout
  open var text: String {
    return fieldInput.text
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
    super.init(field: fieldInput, engine: engine, measurer: measurer)

    fieldInput.delegate = self
  }

  // MARK: - Super

  /// TODO:(#114) Remove `override` once `FieldLayout` is deleted.

  open override func didUpdateField(_ field: Field) {
    // Perform a layout up the tree
    updateLayoutUpTree()
  }

  // MARK: - Public

  /**
   Updates `self.fieldInput` from the given value. If the value was changed, the layout tree
   is updated to reflect the change.

   - parameter text: The value used to update `self.fieldInput`.
   */
  open func updateText(_ text: String) {
    // Setting to new text automatically fires a listener to update the layout
    fieldInput.text = text
  }
}
