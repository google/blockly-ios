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
 Class for a `FieldVariable`-based `Layout`.
 */
@objc(BKYFieldVariableLayout)
open class FieldVariableLayout: FieldLayout {

  // MARK: - Tuples

  /// Represents a selectable variable, with a display name and underlying value.
  public typealias Option = (displayName: String, value: String)

  // MARK: - Properties

  /// The `FieldVariable` that backs this layout
  open let fieldVariable: FieldVariable

  /// The list of all variable options that should be presented when rendering this layout
  open var variables: [Option] {
    let sortedVariableNames = fieldVariable.nameManager?.names.sorted() ?? [fieldVariable.variable]
    var variableMap = sortedVariableNames.map { (displayName: $0, value: $0) }
    return variableMap
  }

  /// The currently selected variable
  open var variable: String {
    return fieldVariable.variable
  }

  // MARK: - Initializers

  /**
   Initializes the label field layout.

   - parameter fieldVariable: The `FieldVariable` model for this layout.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - parameter measurer: The `FieldLayoutMeasurer.Type` to measure this layout.
   */
  public init(
    fieldVariable: FieldVariable, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type)
  {
    self.fieldVariable = fieldVariable
    super.init(field: fieldVariable, engine: engine, measurer: measurer)

    fieldVariable.delegate = self
  }

  // MARK: - Super

  // TODO:(#114) Remove `override` once `FieldLayout` is deleted.
  open override func didUpdateField(_ field: Field) {
    // Perform a layout up the tree
    updateLayoutUpTree()
  }

  // MARK: - Public

  /**
   Changes `self.fieldVariable.variable` to use the given value. If the value was changed, the
   layout tree is updated to reflect the change.

   - parameter variable: The value used to update `self.fieldVariable.variable`.
   */
  open func changeToVariable(_ variable: String) {
    // Setting to a new variable automatically fires a listener to update the layout
    fieldVariable.changeToVariable(variable)
  }

  /**
   Renames the variable on this layout to a new value.

   - parameter newName: The new value for the variable on this layout.
   */
  open func renameVariable(to newName: String) {
    fieldVariable.nameManager?.renameName(variable, to: newName)
  }

  /**
   Removes the variable that's currently stored on this layout.
   */
  open func removeVariable() {
    fieldVariable.nameManager?.requestRemovalForName(variable)
  }
}
