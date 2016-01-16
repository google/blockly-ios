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

  init() {
    super.init(nibName: nil, bundle: nil)
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

    // TODO:(vicng) Read in layout direction from system
  }

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    // Load data
    self.enableTrashCan = true
    loadWorkspace()
    loadToolbox()

    // Refresh the view
    refreshView()
  }

  override func prefersStatusBarHidden() -> Bool {
    return true
  }

  // MARK: - Private

  private func loadWorkspace() {
    do {
      // Create a workspace
      let workspace = Workspace()

      // Add some blocks to the workspace
      // try addChainedBlocksToWorkspace(workspace)
      addSpaghettiBlocksToWorkspace(workspace)

      // Create a layout for the workspace, which is required for viewing the workspace
      self.workspaceLayout =
        try WorkspaceLayout(workspace: workspace, layoutBuilder: LayoutBuilder())
    } catch let error as NSError {
      print("Couldn't build layout tree for workspace: \(error)")
    }
  }

  private func loadToolbox() {
    // Create a toolbox
    let toolbox = Toolbox()

    let loops = toolbox.addCategory("Loops", color: UIColor.blueColor())
    addBlock("controls_repeat_ext", toCategory: loops)
    addBlock("controls_whileUntil", toCategory: loops)

    let math = toolbox.addCategory("Math", color: UIColor.greenColor())
    addBlock("controls_whileUntil", toCategory: math)

    let random = toolbox.addCategory("Random", color: UIColor.redColor())
    addBlock("simple_input_output", toCategory: random)
    addBlock("multiple_input_output", toCategory: random)
    addBlock("output_no_input", toCategory: random)
    random.addGap(40)

    addBlock("statement_no_input", toCategory: random)
    addBlock("statement_value_input", toCategory: random)
    addBlock("statement_multiple_value_input", toCategory: random)
    addBlock("statement_no_next", toCategory: random)
    random.addGap(40)

    addBlock("statement_statement_input", toCategory: random)
    addBlock("block_statement", toCategory: random)
    addBlock("block_output", toCategory: random)

    self.toolbox = toolbox
  }

  private func addBlock(blockName: String, toCategory category: Toolbox.Category) {
    if let block = _blockFactory.buildBlock(blockName) {
      category.addBlockTree(block)
    }
  }

  private func addChainedBlocksToWorkspace(workspace: Workspace) throws {
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

  private func addToolboxBlocksToWorkspace(workspace: Workspace) {
    let blocks = ["controls_repeat_ext", "controls_whileUntil", "math_number",
      "simple_input_output", "multiple_input_output", "statement_no_input", "statement_value_input",
      "statement_multiple_value_input", "statement_statement_input", "output_no_input",
      "statement_no_next", "block_output", "block_statement"]

    for block in blocks {
      _blockFactory.addBlock(block, toWorkspace: workspace)
    }
  }

  private func addSpaghettiBlocksToWorkspace(workspace: Workspace) {
    buildSpaghettiBlock(workspace, level: 4, blocksPerLevel: 5)
  }

  private func buildOutputBlock(workspace: Workspace) -> Block? {
    return _blockFactory.addBlock("block_output", toWorkspace: workspace)
  }

  private func buildStatementBlock(workspace: Workspace) -> Block? {
    return _blockFactory.addBlock("block_statement", toWorkspace: workspace)
  }

  private func buildChainedStatementBlock(workspace: Workspace) -> Block? {
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

  private func buildSpaghettiBlock(workspace: Workspace, level: Int, blocksPerLevel: Int) -> Block?
  {
    if level <= 0 {
      return nil
    }
    var firstBlock: Block?
    var previousBlock: Block? = nil

    for (var i = 0; i < blocksPerLevel; i++) {
      if let nextBlock = _blockFactory.addBlock("statement_statement_input", toWorkspace: workspace)
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
