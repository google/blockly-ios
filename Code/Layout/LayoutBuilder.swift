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
Class for building an entire `Layout` tree from a model object.
*/
@objc(BKYLayoutBuilder)
public class LayoutBuilder: NSObject {

  /** Builds and returns an entire `WorkspaceLayout` tree from a given workspace. */
  public static func buildLayoutTreeFromWorkspace(workspace: Workspace) -> WorkspaceLayout {
    let workspaceLayout = WorkspaceLayout(workspace: workspace)

    for block in workspace.blocks {
      let layout = buildBlockGroupLayoutTreeFromBlock(block, parentLayout: workspaceLayout)
      workspaceLayout.appendBlockGroupLayout(layout)
    }

    return workspaceLayout
  }

  /** Builds and returns an entire `BlockGroupLayout` tree from a given block. */
  public static func buildBlockGroupLayoutTreeFromBlock(block: Block, parentLayout: Layout?)
    -> BlockGroupLayout {
      let blockGroupLayout = BlockGroupLayout(parentLayout: parentLayout)

      // The passed in block is considered as the first block in this group
      let blockLayout = buildBlockLayoutTreeFromBlock(block, parentLayout: blockGroupLayout)
      blockGroupLayout.appendBlockLayout(blockLayout)

      // Iterate and append each "next block"
      var currentBlock = block
      while let nextBlock = currentBlock.nextBlock {
        let nextBlockLayout = buildBlockLayoutTreeFromBlock(
          nextBlock, parentLayout: blockGroupLayout)
        blockGroupLayout.appendBlockLayout(nextBlockLayout)
        currentBlock = nextBlock
      }

      return blockGroupLayout
  }

  /** Builds and returns an entire `BlockLayout` tree from a given block. */
  public static func buildBlockLayoutTreeFromBlock(block: Block, parentLayout: BlockGroupLayout?)
    -> BlockLayout {
      let blockLayout = BlockLayout(block: block, parentLayout: parentLayout)

      // Build the input tree underneath this block
      for input in block.inputs {
        let inputLayout = buildLayoutTreeFromInput(input, parentLayout: blockLayout)
        blockLayout.appendInputLayout(inputLayout)
      }

      return blockLayout
  }

  /** Builds and returns an entire `InputLayout` tree from a given input. */
  public static func buildLayoutTreeFromInput(
    input: Input, parentLayout: BlockLayout?) -> InputLayout {
      let inputLayout = InputLayout(input: input, parentLayout: parentLayout)

      // Build the block group underneath this input
      if let connectedBlock = input.connectedBlock {
        inputLayout.blockGroupLayout =
          buildBlockGroupLayoutTreeFromBlock(connectedBlock, parentLayout: inputLayout)
      }

      // Build the field tree underneath this input
      for field in input.fields {
        if let fieldLayout = buildLayoutTreeFromField(field, parentLayout: inputLayout) {
          inputLayout.appendFieldLayout(fieldLayout)
        }
      }

      return inputLayout
  }

  /** Builds and returns an entire `FieldLayout` tree from a given field. */
  public static func buildLayoutTreeFromField(field: Field, parentLayout: Layout?) -> FieldLayout? {
    // TODO:(vicng) Implement error handling if the field's layout could not be found
    if let fieldLabel = field as? FieldLabel {
      return FieldLabelLayout(fieldLabel: fieldLabel, parentLayout: parentLayout)
    }

    return nil
  }
}
