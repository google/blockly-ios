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
 Class for a `FieldLabel`-based `Layout`.
 */
@objc(BKYFieldLabelLayout)
@objcMembers open class FieldLabelLayout: FieldLayout {

  // MARK: - Properties

  /// The `FieldLabel` that backs this layout
  private let fieldLabel: FieldLabel

  /// The value that should be used when rendering this layout
  open var text: String {
    return fieldLabel.text
  }

  // MARK: - Initializers

  /**
   Initializes the label field layout.

   - parameter fieldLabel: The `FieldLabel` model for this layout.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - parameter measurer: The `FieldLayoutMeasurer.Type` to measure this layout.
   */
  public init(fieldLabel: FieldLabel, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type) {
    self.fieldLabel = fieldLabel
    super.init(field: fieldLabel, engine: engine, measurer: measurer)
  }
}
