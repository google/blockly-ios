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
public class FieldVariableLayout: FieldLayout {

  public typealias Option = (displayName: String, value: String)

  // MARK: - Properties

  /// The `FieldVariable` that backs this layout
  public let fieldVariable: FieldVariable

  /// The list of all variable options that should be presented when rendering this layout
  public var variables: [Option] {
    let sortedVariableNames = fieldVariable.nameManager?.names.sort() ?? [fieldVariable.variable]
    return sortedVariableNames.map { (displayName: $0, value: $0) }
  }

  /// The currently selected variable
  public var variable: String {
    return fieldVariable.variable
  }

  // MARK: - Initializers

  public init(
    fieldVariable: FieldVariable, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type)
  {
    self.fieldVariable = fieldVariable
    super.init(field: fieldVariable, engine: engine, measurer: measurer)

    fieldVariable.delegate = self
  }

  // MARK: - Super

  // TODO:(#114) Remove `override` once `FieldLayout` is deleted.
  public override func didUpdateField(field: Field) {
    // Perform a layout up the tree
    updateLayoutUpTree()
  }

  // MARK: - Public

  /**
   Changes `self.fieldVariable.variable` to use the given value. If the value was changed, the
   layout tree is updated to reflect the change.

   - Parameter variable: The value used to update `self.fieldVariable.variable`.
   */
  public func changeToVariable(variable: String) {
    // Setting to a new variable automatically fires a listener to update the layout
    fieldVariable.changeToVariable(variable)
  }
}
