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
@objcMembers open class FieldVariableLayout: FieldLayout {

  // MARK: - Tuples

  /// Represents a selectable variable, with a display name and underlying value.
  public typealias Option = (displayName: String, value: String)

  // MARK: - Properties

  /// The `FieldVariable` that backs this layout
  private let fieldVariable: FieldVariable

  /// The list of all variable options that should be presented when rendering this layout
  open var variables: [Option] {
    let sortedVariableNames = nameManager?.names.sorted() ?? [fieldVariable.variable]
    return sortedVariableNames.map { (displayName: $0, value: $0) }
  }

  /// The currently selected variable
  open var variable: String {
    return fieldVariable.variable
  }

  /// Optional name manager that this field is scoped to.
  public weak var nameManager: NameManager? {
    didSet {
      // Remove this field as a listener from its previous nameManager
      oldValue?.listeners.remove(self)

      // Add name to new nameManager
      if let newManager = nameManager {
        newManager.listeners.add(self)
        if !newManager.containsName(variable) {
          do {
            try newManager.addName(variable)
          } catch {
            bky_assertionFailure("Couldn't add variable: \(error)")
          }
        } else {
          // Updates the new name manager so all variables use the same case.
          newManager.renameName(variable, to: variable)
        }
      }
    }
  }

  // TODO(#334): Investigate decoupling FieldVariableLayout from WorkspaceLayoutCoordinator.

  // Used to determine information about the variables on the workspace. Only set if the variable
  // layout is on a workspace.
  internal weak var layoutCoordinator: WorkspaceLayoutCoordinator?

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
  }

  // MARK: - Super

  open override func didUpdateField(_ field: Field) {
    if let nameManager = self.nameManager,
      !nameManager.containsName(variable)
    {
      // Automatically add variable to NameManager
      do {
        try nameManager.addName(variable)
      } catch let error {
        bky_assertionFailure("Couldn't add variable: \(error)")
      }
    }

    super.didUpdateField(field)
  }

  // MARK: - Public

  /**
   Changes `self.fieldVariable.variable` to use the given value. If the value was changed, the
   layout tree is updated to reflect the change.

   - parameter variable: The value used to update `self.fieldVariable.variable`.
   */
  open func changeToExistingVariable(_ variable: String) {
    // Setting to a new variable automatically fires a listener to update the layout

    let oldValue = self.variable
    if oldValue != variable {
      if let nameManager = self.nameManager,
        !nameManager.containsName(variable) {
        bky_assertionFailure("Cannot change to a variable that does not exist in the Name Manager.")
        return
      }

      captureChangeEvent {
        do {
          try fieldVariable.setVariable(variable)
        } catch let error {
          bky_assertionFailure("Could not change to variable: \(error)")
        }
      }

      // Perform a layout up the tree
      updateLayoutUpTree()
    }
  }

  /**
   Renames the variable on this layout to a new value, and tells the `NameManager` of the change.

   - parameter newName: The new value for the variable on this layout.
   */
  open func renameVariable(to newName: String) {
    let oldName = self.variable
    captureChangeEvent {
      do {
        try fieldVariable.setVariable(newName)
      } catch let error {
        bky_assertionFailure("Could not rename variable: \(error)")
      }
    }
    nameManager?.renameName(oldName, to: newName)

    // Perform a layout up the tree
    updateLayoutUpTree()
  }

  /**
   Removes the variable that's currently stored on this layout.
   */
  open func removeVariable() {
    nameManager?.removeName(self.variable)
  }

  /**
   Checks whether a string is a valid name.

   - parameter name: The `String` to check.
   */
  public func isValidName(_ name: String) -> Bool {
    return FieldVariable.isValidName(name)
  }

  /**
   Returns the total number of variables matching the variable set on this layout.

   - returns: The count of variable fields.
   */
  public func numberOfVariableReferences() -> Int {
    guard let layoutCoordinator = layoutCoordinator else {
      // If there is no layoutCoordinator set on the layout, this is the only matching variable.
      return 1
    }

    let workspace = layoutCoordinator.workspaceLayout.workspace
    return workspace.allVariableBlocks(forName: variable).count
  }
}

// MARK: - NameManagerListener Implementation

extension FieldVariableLayout: NameManagerListener {
  public func nameManager(_ nameManager: NameManager, shouldRemoveName name: String) -> Bool {
    return true
  }

  public func nameManager(
    _ nameManager: NameManager, didRenameName oldName: String, toName newName: String)
  {
    if nameManager.namesAreEqual(oldName, variable) {
      // This variable was renamed, update it
      changeToExistingVariable(newName)
    }
  }
}
