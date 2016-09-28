/*
* Copyright 2015 Google Inc. All Rights Reserved.
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
An input for specifying a variable.
*/
@objc(BKYFieldVariable)
public final class FieldVariable: Field {
  // MARK: - Properties

  /// The variable in this field
  public fileprivate(set) var variable: String {
    didSet { didSetEditableProperty(&variable, oldValue) }
  }

  /// Optional name manager that this field is scoped to.
  public weak var nameManager: NameManager? {
    didSet {
      // Remove this field as a listener from its previous nameManager and then request
      // to remove the name it was using
      oldValue?.listeners.remove(self) // Remove
      oldValue?.requestRemovalForName(variable)

      // Add name to new nameManager
      nameManager?.listeners.add(self)
      nameManager?.addName(variable)
    }
  }

  // MARK: - Initializers

  /**
   Initializes the variable field.

   - Parameter name: The name of this field.
   - Parameter variable: The initial variable name to set for this field.
   */
  public init(name: String, variable: String) {
    self.variable = variable

    super.init(name: name)
  }

  // MARK: - Super

  public override func copyField() -> Field {
    return FieldVariable(name: name, variable: variable)
  }

  public override func setValueFromSerializedText(_ text: String) throws {
    if text != "" {
      self.variable = text
    } else {
      throw BlocklyError(.xmlParsing, "Cannot set a variable to empty text")
    }
  }

  public override func serializedText() throws -> String? {
    return self.variable
  }

  // MARK: - Public

  /**
   Sets `self.variable` to a new variable and calls `self.nameManager?.addName(variable)`.

   - Parameter variable: The new variable name
   */
  public func addNewVariable(_ variable: String) {
    self.variable = variable
    nameManager?.addName(variable)
  }

  /**
   Sets `self.variable` to a new variable and calls `self.nameManager?.renameName(variable)`.

   - Parameter variable: The new variable name
   */
  public func renameVariable(_ variable: String) {
    let oldName = self.variable
    self.variable = variable
    nameManager?.renameName(oldName, to: variable)
  }

  /**
   Sets `self.variable` to a new variable and calls `self.nameManager?.requestRemovalForName(:)`
   with the previous value of `self.variable`.
   */
  public func changeToVariable(_ variable: String) {
    let oldValue = self.variable
    if oldValue != variable {
      self.variable = variable
      nameManager?.requestRemovalForName(oldValue)
    }
  }
}

// MARK: - NameManagerListener Implementation

extension FieldVariable: NameManagerListener {
  public func nameManager(_ nameManager: NameManager, shouldRemoveName name: String) -> Bool {
    // Only approve this removal if this instance isn't using that variable
    return !nameManager.namesAreEqual(variable, name)
  }

  public func nameManager(
    _ nameManager: NameManager, didRenameName oldName: String, toName newName: String)
  {
    if nameManager.namesAreEqual(oldName, variable) {
      // This variable was renamed, update it
      variable = newName
    }
  }
}
