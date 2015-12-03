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

import UIKit
import Blockly

class SimpleWorkbenchViewController: WorkbenchViewController {
  // MARK: - Super

  /// Factory that produces block instances from a parsed json file
  private var _blockFactory: BlockFactory!

  // MARK: - Initializers

  override init() {
    super.init()
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    // Load the block factory
    do {
      _blockFactory = try BlockFactory(jsonPath: "TestBlocks")
    } catch let error as NSError {
      print("An error occurred loading the test blocks: \(error)")
    }
  }

  // MARK: - Internal

  func loadWorkspace() {
    // Create a workspace
    let workspace = Workspace(isFlyout: false)

    do {
      // Add some blocks to the workspace
      try addChainedBlocksToWorkspace(workspace)

      // Create the workspace layout, which is required for viewing the workspace
      workspace.layout = WorkspaceLayout(workspace: workspace, layoutBuilder: LayoutBuilder())

      // Build its layout tree, which creates layout objects for all of its blocks/inputs/fields
      // (allowing them to show up in the workspace view)
      try workspace.layout!.layoutBuilder.buildLayoutTree()

      // TODO(vicng): Add method to automatically space out top-level blocks from overlapping

      // Perform a layout update for the entire tree
      workspace.layout!.updateLayoutDownTree()
    } catch let error as NSError {
      print("Couldn't build layout tree for workspace: \(error)")
    }

    self.workspace = workspace
  }

  func addChainedBlocksToWorkspace(workspace: Workspace) throws {
    if let block1 = buildChainedStatementBlock(workspace) {
      if let block2 = buildOutputBlock(workspace) {
        try block1.inputs[1].connection?.connectTo(block2.outputConnection)

        if let block3 = buildChainedStatementBlock(workspace) {
          try block2.inputs[0].connection?.connectTo(block3.previousConnection)
        }

        if let block4 = buildOutputBlock(workspace) {
          try block2.inputs[1].connection?.connectTo(block4.outputConnection)
        }
      }
    }
  }

  func addToolboxBlocksToWorkspace(workspace: Workspace) {
    let blocks = ["controls_repeat_ext", "controls_whileUntil", "math_number",
      "simple_input_output", "multiple_input_output", "statement_no_input", "statement_value_input",
      "statement_multiple_value_input", "statement_statement_input", "output_no_input",
      "statement_no_next", "block_output", "block_statement"]

    for block in blocks {
      _blockFactory.obtain(block, forWorkspace: workspace)
    }
  }

  func addSpaghettiBlocksToWorkspace(workspace: Workspace) {
    buildSpaghettiBlock(workspace, level: 4, blocksPerLevel: 5)
  }

  func buildOutputBlock(workspace: Workspace) -> Block? {
    return _blockFactory.obtain("block_output", forWorkspace: workspace)
  }

  func buildStatementBlock(workspace: Workspace) -> Block? {
    return _blockFactory.obtain("block_statement", forWorkspace: workspace)
  }

  func buildChainedStatementBlock(workspace: Workspace) -> Block? {
    if let block = buildStatementBlock(workspace) {
      var previousBlock = block
      for (var i = 0; i < 100; i++) {
        if let nextBlock = buildStatementBlock(workspace) {
          try! previousBlock.nextConnection?.connectTo(nextBlock.previousConnection)
          previousBlock = nextBlock
        }
      }

      return block
    }

    return nil
  }

  func buildSpaghettiBlock(workspace: Workspace, level: Int, blocksPerLevel: Int) -> Block?
  {
    if level <= 0 {
      return nil
    }
    var firstBlock: Block?
    var previousBlock: Block? = nil

    for (var i = 0; i < blocksPerLevel; i++) {
      if let nextBlock = _blockFactory.obtain("statement_statement_input", forWorkspace: workspace)
      {
        if let spaghettiBlock =
          buildSpaghettiBlock(workspace, level: level - 1, blocksPerLevel: blocksPerLevel)
        {
          try! nextBlock.inputs[0].connection?.connectTo(spaghettiBlock.previousConnection)
        }

        try! previousBlock?.nextConnection?.connectTo(nextBlock.previousConnection)
        if i == 0 {
          firstBlock = nextBlock
        }
        previousBlock = nextBlock
      }
    }
    return firstBlock
  }
}
