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
 Class for a `FieldNumber`-based `Layout`.
 */
@objc(BKYFieldNumberLayout)
@objcMembers open class FieldNumberLayout: FieldLayout {

  // MARK: - Properties

  /// The target `FieldNumber` to lay out
  private let fieldNumber: FieldNumber

  /// The current text value that should be used to render the `FieldNumber`.
  /// This value is automatically set to `self.fieldNumber.textValue` on initialization and 
  /// whenever `setValueFromLocalizedText(:)` is called.
  /// However, it can be set to any value outside of these calls (e.g. for temporary input
  /// purposes).
  open var currentTextValue: String {
    didSet {
      if currentTextValue != oldValue {
        updateLayoutUpTree()
      }
    }
  }

  /// The minimum value of this number field. If `nil`, it is unconstrained by a minimum value.
  public var minimumValue: Double? {
    return fieldNumber.minimumValue
  }

  /// The maximum value of this number field. If `nil`, it is unconstrained by a maximum value.
  public var maximumValue: Double? {
    return fieldNumber.maximumValue
  }

  /// Flag indicating if the number field is constrained to being an integer value.
  public var isInteger: Bool {
    return fieldNumber.isInteger
  }

  // MARK: - Initializers

  /**
   Initializes the label number layout.

   - parameter fieldNumber: The `FieldNumber` model for this layout.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - parameter measurer: The `FieldLayoutMeasurer.Type` to measure this layout.
   */
  public init(fieldNumber: FieldNumber, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type) {
    self.fieldNumber = fieldNumber
    self.currentTextValue = fieldNumber.textValue
    super.init(field: fieldNumber, engine: engine, measurer: measurer)
  }

  // MARK: - Super

  open override func didUpdateField(_ field: Field) {
    // Update current text value to match the field now
    currentTextValue = fieldNumber.textValue

    super.didUpdateField(field)
  }

  // MARK: - Public

  /**
   Convenience method that calls `self.fieldNumber.setValueFromLocalizedText(text)` and
   automatically sets `self.currentTextValue` to `self.fieldNumber.textValue`.
   */
  open func setValueFromLocalizedText(_ text: String) {
    captureChangeEvent {
      fieldNumber.setValueFromLocalizedText(text)

      // Update `currentTextValue` to match the current localized text value of `fieldNumber`.
      currentTextValue = fieldNumber.textValue
    }

    // Perform a layout up the tree
    updateLayoutUpTree()
  }
}
