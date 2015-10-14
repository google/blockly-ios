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
  // MARK: - Public

  /**
  Builds and returns an entire `WorkspaceLayout` tree from a given workspace.
  */
  public static func buildLayoutTreeFromWorkspace(workspace: Workspace) -> WorkspaceLayout {
    let workspaceLayout = WorkspaceLayout(workspace: workspace)

    for block in workspace.topBlocks {
      let blockGroupLayout = buildBlockGroupLayoutTreeFromBlock(
        block, workspaceLayout: workspaceLayout)
      workspaceLayout.appendBlockGroupLayout(blockGroupLayout)
    }

    return workspaceLayout
  }

  /**
  Builds and returns an entire `BlockGroupLayout` tree from a given block.
  */
  public static func buildBlockGroupLayoutTreeFromBlock(
    block: Block, workspaceLayout: WorkspaceLayout) -> BlockGroupLayout {
      let blockGroupLayout = BlockGroupLayout(workspaceLayout: workspaceLayout)

      // The passed in block is considered as the first block in this group
      let blockLayout = buildBlockLayoutTreeFromBlock(block, workspaceLayout: workspaceLayout)
      blockGroupLayout.appendBlockLayout(blockLayout)

      // Iterate and append each "next block"
      var currentBlock = block
      while let nextBlock = currentBlock.nextBlock {
        let nextBlockLayout = buildBlockLayoutTreeFromBlock(
          nextBlock, workspaceLayout: workspaceLayout)
        blockGroupLayout.appendBlockLayout(nextBlockLayout)
        currentBlock = nextBlock
      }

      return blockGroupLayout
  }

  /**
  Builds and returns an entire `BlockLayout` tree from a given block.
  */
  public static func buildBlockLayoutTreeFromBlock(block: Block, workspaceLayout: WorkspaceLayout)
    -> BlockLayout {
      let blockLayout = BlockLayout(block: block, workspaceLayout: workspaceLayout)

      // Build the input tree underneath this block
      for input in block.inputs {
        let inputLayout = buildLayoutTreeFromInput(input, workspaceLayout: workspaceLayout)
        blockLayout.appendInputLayout(inputLayout)
      }

      return blockLayout
  }

  /**
  Builds and returns an entire `InputLayout` tree from a given input.
  */
  public static func buildLayoutTreeFromInput(
    input: Input, workspaceLayout: WorkspaceLayout) -> InputLayout {
      let inputLayout = InputLayout(
        input: input, workspaceLayout: workspaceLayout)

      // Build the block group underneath this input
      if let connectedBlock = input.connectedBlock {
        inputLayout.blockGroupLayout =
          buildBlockGroupLayoutTreeFromBlock(connectedBlock, workspaceLayout: workspaceLayout)
      }

      // Build the field tree underneath this input
      for field in input.fields {
        if let fieldLayout = buildLayoutTreeFromField(field, workspaceLayout: workspaceLayout) {
          inputLayout.appendFieldLayout(fieldLayout)
        }
      }

      return inputLayout
  }

  // TODO:(vicng) Re-factor this method so that any user-defined Field could be created here.
  /**
  Builds and returns an entire `FieldLayout` tree from a given field.
  */
  public static func buildLayoutTreeFromField(
    field: Field, workspaceLayout: WorkspaceLayout) -> FieldLayout? {
      // TODO:(vicng) Implement error handling if the field's layout could not be found
      if let fieldLabel = field as? FieldLabel {
        return FieldLabelLayout(fieldLabel: fieldLabel, workspaceLayout: workspaceLayout)
      }

      return nil
  }
}
