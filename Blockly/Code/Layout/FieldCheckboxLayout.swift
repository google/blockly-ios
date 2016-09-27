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
 Class for a `FieldCheckbox`-based `Layout`.
 */
@objc(BKYFieldCheckboxLayout)
open class FieldCheckboxLayout: FieldLayout {

  // MARK: - Properties

  /// The `FieldCheckbox` that backs this layout
  open let fieldCheckbox: FieldCheckbox

  /// The checkbox value that should be used when rendering this layout
  open var checked: Bool {
    return fieldCheckbox.checked
  }

  // MARK: - Initializers

  /**
   Initializes the checkbox field layout.

   - Parameter fieldCheckbox: The `FieldCheckbox` model for this layout.
   - Parameter engine: The `LayoutEngine` to associate with the new layout.
   - Parameter measurer: The `FieldLayoutMeasurer.Type` to measure this layout.
   */
  public init(
    fieldCheckbox: FieldCheckbox, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type)
  {
    self.fieldCheckbox = fieldCheckbox
    super.init(field: fieldCheckbox, engine: engine, measurer: measurer)

    fieldCheckbox.delegate = self
  }

  // MARK: - Super

  /// :nodoc:
  /// TODO:(#114) Remove `override` once `FieldLayout` is deleted.
  open override func didUpdateField(_ field: Field) {
    // Perform a layout up the tree
    updateLayoutUpTree()
  }

  // MARK: - Public

  /**
   Updates `self.fieldCheckbox` from the given value. If the value was changed, the layout tree
   is updated to reflect the change.

   - Parameter checked: The value used to update `self.fieldCheckbox`.
   */
  open func updateCheckbox(_ checked: Bool) {
    // Setting to a new checkbox value automatically fires a listener to update the layout
    fieldCheckbox.checked = checked
  }
}
