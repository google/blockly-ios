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
 Class for a `FieldDropdown`-based `Layout`.
 */
@objc(BKYFieldDropdownLayout)
@objcMembers open class FieldDropdownLayout: FieldLayout {

  // MARK: - Properties

  /// The `FieldDropdown` that backs this layout
  private let fieldDropdown: FieldDropdown

  /// The list of options that should be presented when rendering this layout
  open var options: [FieldDropdown.Option] {
    return fieldDropdown.options
  }

  /// The currently selected index of `self.options`
  open var selectedIndex: Int {
    return fieldDropdown.selectedIndex
  }

  /// The option tuple of the currently selected index
  open var selectedOption: FieldDropdown.Option? {
    return fieldDropdown.selectedOption
  }

  // MARK: - Initializers

  /**
   Initializes the dropdown field layout.

   - parameter fieldDropdown: The `FieldDropdown` model for this layout.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - parameter measurer: The `FieldLayoutMeasurer.Type` to measure this layout.
   */
  public init(
    fieldDropdown: FieldDropdown, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type)
  {
    self.fieldDropdown = fieldDropdown
    super.init(field: fieldDropdown, engine: engine, measurer: measurer)
  }

  // MARK: - Public

  /**
   Updates `self.fieldDropdown.selectedIndex` from the given value. If the value was changed, the
   layout tree is updated to reflect the change.

   - parameter selectedIndex: The value used to update `self.fieldDropdown.selectedIndex`.
   */
  open func updateSelectedIndex(_ selectedIndex: Int) {
    guard fieldDropdown.selectedIndex != selectedIndex else { return }

    captureChangeEvent {
      fieldDropdown.selectedIndex = selectedIndex
    }

    // Perform a layout up the tree
    updateLayoutUpTree()
  }
}
