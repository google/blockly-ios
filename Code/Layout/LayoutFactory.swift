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
Factory responsible for returning new instances of Layout objects.
*/
@objc(BKYLayoutFactory)
public class LayoutFactory: NSObject {
  // MARK: - Properties

  /// Error description for when the workspace layout is not defined
  public static let ERROR_WORKSPACE_LAYOUT_NOT_DEFINED = "workspace.layout has not been set"

  // MARK: - Public

  /**
  Builds and returns a `WorkspaceLayout` for a given workspace.

  - Parameter workspace: The given workspace
  - Returns: A new `WorkspaceLayout` instance or nil, if no suitable layout could be found for the
  workspace.
  */
  public func layoutForWorkspace(workspace: Workspace) -> WorkspaceLayout {
    return WorkspaceLayout(workspace: workspace)
  }

  /**
  Builds and returns an `InputLayout` for a given input and workspace.

  - Parameter input: The given input
  - Parameter workspace: The workspace where the input will be added.
  - Throws:
  `BlockError`: Thrown if workspace.layout is nil
  - Returns: A new `InputLayout` instance or nil, if either `workspace.layout` is nil or no suitable
  layout could be found for the input.
  */
  public func layoutForInput(input: Input, workspace: Workspace) throws -> InputLayout {
    guard let workspaceLayout = workspace.layout else {
      // Can't return an input layout if the workspace does not have a layout
      throw BlockError(.LayoutNotFound, LayoutFactory.ERROR_WORKSPACE_LAYOUT_NOT_DEFINED)
    }
    return InputLayout(input: input, workspaceLayout: workspaceLayout)
  }

  /**
  Builds and returns a `FieldLayout` for a given field and workspace.

  - Parameter field: The given field
  - Parameter workspace: The workspace where the field will be added.
  - Throws:
  `BlockError`: Thrown if workspace.layout is nil or if no suitable `FieldLayout` could be found for
  the field.
  - Returns: A new `FieldLayout` instance or nil, if either `workspace.layout` is nil or no suitable
  layout could be found for the field.
  */
  public func layoutForField(field: Field, workspace: Workspace) throws -> FieldLayout {
    guard let workspaceLayout = workspace.layout else {
      // Can't return a field layout if the workspace does not have a layout
      throw BlockError(.LayoutNotFound, LayoutFactory.ERROR_WORKSPACE_LAYOUT_NOT_DEFINED)
    }
    if let fieldLabel = field as? FieldLabel {
      return FieldLabelLayout(fieldLabel: fieldLabel, workspaceLayout: workspaceLayout)
    }

    throw BlockError(.LayoutNotFound, "Could not find layout for \(field.dynamicType)")
  }
}
