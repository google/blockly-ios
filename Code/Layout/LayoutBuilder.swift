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
Class for building an entire |Layout| tree from a model object.
*/
@objc(BKYLayoutBuilder)
public class LayoutBuilder: NSObject {

  public static func buildLayoutTreeFromWorkspace(workspace: Workspace) -> WorkspaceLayout {
    let workspaceLayout = WorkspaceLayout(workspace: workspace)

    for block in workspace.blocks {
      let blockLayout = buildLayoutTreeFromBlock(block, parentLayout: workspaceLayout)
      blockLayout.parentLayout = workspaceLayout
      workspaceLayout.blockLayouts.append(blockLayout)
    }

    return workspaceLayout
  }

  public static func buildLayoutTreeFromBlock(block: Block, parentLayout: Layout?) -> BlockLayout {
    let blockLayout = BlockLayout(block: block, parentLayout: parentLayout)

    for childBlock in block.childBlocks {
      let childBlockLayout = buildLayoutTreeFromBlock(childBlock, parentLayout: blockLayout)
      blockLayout.childBlockLayouts.append(childBlockLayout)
    }

    for input in block.inputs {
      let inputLayout = buildLayoutTreeFromInput(input, parentLayout: blockLayout)
      blockLayout.inputLayouts.append(inputLayout)
    }

    return blockLayout
  }

  public static func buildLayoutTreeFromInput(input: Input, parentLayout: Layout?) -> InputLayout {
    let inputLayout = InputLayout(input: input, parentLayout: parentLayout)

    for field in input.fields {
      if let fieldLayout = buildLayoutTreeFromField(field, parentLayout: inputLayout) {
        inputLayout.fieldLayouts.append(fieldLayout)
      }
    }

    return inputLayout
  }

  public static func buildLayoutTreeFromField(field: Field, parentLayout: Layout?) -> FieldLayout? {
    // TODO:(vicng) Implement error handling if the field's layout could not be found
    if let fieldLabel = field as? FieldLabel {
      return FieldLabelLayout(fieldLabel: fieldLabel, parentLayout: parentLayout)
    }

    return nil
  }
}
