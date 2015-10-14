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
Input field.  Used for editable titles, variables, etc. This is an abstract class that defines the
UI on the block.  Actual instances would be `FieldLabel`, `FieldDropdown`, etc.
*/
@objc(BKYField)
public class Field: NSObject {
  // MARK: - Properties

  public let name: String

  /// The layout used for rendering this field
  public private(set) var layout: FieldLayout?

  // MARK: - Initializers

  internal init(name: String, workspace: Workspace) {
    self.name = name
    super.init()

    do {
      self.layout = try workspace.layoutFactory?.layoutForField(self, workspace: workspace)
    } catch let error as NSError {
      bky_assertionFailure("Could not initialize the layout: \(error)")
    }
  }

  // MARK: - Abstract

  /**
  Returns a copy of this field, for use in a given workspace.

  - Parameter workspace: The given workspace
  - Returns: A copy of this field, for use in the given workspace.
  - Note: This method needs to be implemented by a subclass of `Field`. Results are undefined if
  a `Field` subclass does not implement this method.
  */
  public func copyToWorkspace(workspace: Workspace) -> Field {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
    return self.copy() as! Field // This shouldn't happen.
  }
}
