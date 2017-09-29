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
 Class for a `FieldColor`-based `Layout`.
 */
@objc(BKYFieldColorLayout)
@objcMembers open class FieldColorLayout: FieldLayout {

  // MARK: - Properties

  /// The `FieldColor` that backs this layout
  private let fieldColor: FieldColor

  /// The checkbox value that should be used when rendering this layout
  open var color: UIColor {
    return fieldColor.color
  }

  // MARK: - Initializers

  /**
   Initializes the color field layout.

   - parameter fieldColor: The `FieldColor` model for this layout.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - parameter measurer: The `FieldLayoutMeasurer.Type` to measure this layout.
   */
  public init(fieldColor: FieldColor, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type) {
    self.fieldColor = fieldColor
    super.init(field: fieldColor, engine: engine, measurer: measurer)
  }

  // MARK: - Public

  /**
   Updates `self.fieldColor` from the given value. If the value was changed, the layout tree
   is updated to reflect the change.

   - parameter color: The value used to update `self.fieldColor`.
   */
  open func updateColor(_ color: UIColor) {
    guard fieldColor.color != color else { return }

    captureChangeEvent {
      fieldColor.color = color
    }

    // Perform a layout up the tree
    updateLayoutUpTree()
  }
}
