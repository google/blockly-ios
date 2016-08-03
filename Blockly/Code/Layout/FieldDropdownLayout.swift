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
public class FieldDropdownLayout: FieldLayout {

  public typealias Option = FieldDropdown.Option

  // MARK: - Properties

  /// The `FieldDropdown` that backs this layout
  public let fieldDropdown: FieldDropdown

  /// The list of options that should be presented when rendering this layout
  public var options: [Option] {
    return fieldDropdown.options
  }

  /// The currently selected index of `self.options`
  public var selectedIndex: Int {
    return fieldDropdown.selectedIndex
  }

  /// The option tuple of the currently selected index
  public var selectedOption: Option? {
    return fieldDropdown.selectedOption
  }

  // MARK: - Initializers

  public init(
    fieldDropdown: FieldDropdown, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type)
  {
    self.fieldDropdown = fieldDropdown
    super.init(field: fieldDropdown, engine: engine, measurer: measurer)

    fieldDropdown.delegate = self
  }

  // MARK: - Super

  // TODO:(#114) Remove `override` once `FieldLayout` is deleted.
  public override func didUpdateField(field: Field) {
    // Perform a layout up the tree
    updateLayoutUpTree()
  }

  // MARK: - Public

  /**
   Updates `self.fieldDropdown.selectedIndex` from the given value. If the value was changed, the
   layout tree is updated to reflect the change.

   - Parameter selectedIndex: The value used to update `self.fieldDropdown.selectedIndex`.
   */
  public func updateSelectedIndex(selectedIndex: Int) {
    // Setting to a new index automatically fires a listener to update the layout
    fieldDropdown.selectedIndex = selectedIndex
  }
}
