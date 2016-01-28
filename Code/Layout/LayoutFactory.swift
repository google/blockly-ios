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
  // MARK: - Public

  /**
  Builds and returns a `BlockLayout` for a given block and workspace layout.

  - Parameter block: The given block
  - Parameter workspaceLayout: The workspace layout to associate with the new layout.
  - Returns: A new `BlockLayout` instance or nil, if either `workspace.layout` is nil or no
  suitable
  layout could be found for the block.
  */
  public func layoutForBlock(block: Block, workspaceLayout: WorkspaceLayout) -> BlockLayout {
    return BlockLayout(block: block, workspaceLayout: workspaceLayout)
  }

  /**
  Builds and returns a `BlockGroupLayout` for a given workspace layout.

  - Parameter workspaceLayout: The workspace layout to associate with the new layout.
  - Returns: A new `BlockGroupLayout` instance.
  */
  public func layoutForBlockGroupLayout(workspaceLayout workspaceLayout: WorkspaceLayout)
    -> BlockGroupLayout
  {
    return BlockGroupLayout(workspaceLayout: workspaceLayout)
  }

  /**
  Builds and returns an `InputLayout` for a given input and workspace layout.

  - Parameter input: The given input
  - Parameter workspaceLayout: The workspace layout to associate with the new layout.
  - Returns: A new `InputLayout` instance.
  */
  public func layoutForInput(input: Input, workspaceLayout: WorkspaceLayout) -> InputLayout {
    return InputLayout(input: input, workspaceLayout: workspaceLayout)
  }

  /**
  Builds and returns a `FieldLayout` for a given field and workspace.

  - Parameter field: The given field
  - Parameter workspace: The workspace where the field will be added.
  - Returns: A new `FieldLayout` instance.
  - Throws:
  `BlocklyError`: Thrown if workspace.layout is nil or if no suitable `FieldLayout` could be found
  for the field.
  */
  public func layoutForField(field: Field, workspaceLayout: WorkspaceLayout) throws -> FieldLayout {
    if let fieldDropdown = field as? FieldDropdown {
      return FieldDropdownLayout(fieldDropdown: fieldDropdown, workspaceLayout: workspaceLayout)
    } else if let fieldInput = field as? FieldInput {
      return FieldInputLayout(fieldInput: fieldInput, workspaceLayout: workspaceLayout)
    } else if let fieldLabel = field as? FieldLabel {
      return FieldLabelLayout(fieldLabel: fieldLabel, workspaceLayout: workspaceLayout)
    }

    throw BlocklyError(.LayoutNotFound, "Could not find layout for \(field.dynamicType)")
  }
}
