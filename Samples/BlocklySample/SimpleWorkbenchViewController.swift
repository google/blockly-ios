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
//      addSpaghettiBlocksToWorkspace(workspace)

      // Create a layout for the workspace, which is required for viewing the workspace
      self.workspaceLayout =
        try WorkspaceLayout(workspace: workspace, layoutBuilder: LayoutBuilder())
    } catch let error as NSError {
      print("Couldn't build layout tree for workspace: \(error)")
    }
  }

  private func loadToolbox() {
    // Create a toolbox
    do {
      let toolbox = Toolbox()

      let loops = toolbox.addCategory("Loops", colour: UIColor.yellowColor())
      try addBlock("controls_repeat_ext", toCategory: loops)
      try addBlock("controls_whileUntil", toCategory: loops)

      let math = toolbox.addCategory("Math", colour: UIColor.greenColor())
      try addBlock("controls_whileUntil", toCategory: math)

      let random = toolbox.addCategory("Random", colour: UIColor.orangeColor())
      try addBlock("web_image", toCategory: random)
      try addBlock("local_image", toCategory: random)
      try addBlock("checkbox", toCategory: random)
      try addBlock("date_picker", toCategory: random)
      try addBlock("colour_picker", toCategory: random)
      try addBlock("test_dropdown", toCategory: random)
      random.addGap(40)

      try addBlock("text_input_block", toCategory: random)
      random.addGap(40)

      try addBlock("simple_input_output", toCategory: random)
      try addBlock("multiple_input_output", toCategory: random)
      try addBlock("output_no_input", toCategory: random)
      random.addGap(40)

      try addBlock("statement_no_input", toCategory: random)
      try addBlock("statement_value_input", toCategory: random)
      try addBlock("statement_multiple_value_input", toCategory: random)
      try addBlock("statement_no_next", toCategory: random)
      random.addGap(40)

      try addBlock("statement_statement_input", toCategory: random)
      try addBlock("block_statement", toCategory: random)
      try addBlock("block_output", toCategory: random)

      self.toolbox = toolbox
    } catch let error as NSError {
      print("An error occurred loading the toolbox: \(error)")
    }
  }

  private func addBlock(blockName: String, toCategory category: Toolbox.Category) throws {
    if let block = try _blockFactory.buildBlock(blockName) {
      category.addBlockTree(block)
    }
  }

  private func addChainedBlocksToWorkspace(workspace: Workspace) throws {
    if let block1 = try buildChainedStatementBlock(workspace) {
      if let block2 = try buildOutputBlock(workspace) {
        try block1.inputs[1].connection?.connectTo(block2.outputConnection)

        if let block3 = try buildChainedStatementBlock(workspace) {
          try block2.inputs[0].connection?.connectTo(block3.previousConnection)
        }

        if let block4 = try buildOutputBlock(workspace) {
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
      try! _blockFactory.addBlock(block, toWorkspace: workspace)
    }
  }

  private func addSpaghettiBlocksToWorkspace(workspace: Workspace) {
    buildSpaghettiBlock(workspace, level: 4, blocksPerLevel: 5)
  }

  private func buildOutputBlock(workspace: Workspace) throws -> Block? {
    return try _blockFactory.addBlock("block_output", toWorkspace: workspace)
  }

  private func buildStatementBlock(workspace: Workspace) throws -> Block? {
    return try _blockFactory.addBlock("block_statement", toWorkspace: workspace)
  }

  private func buildChainedStatementBlock(workspace: Workspace) throws -> Block? {
    if let block = try buildStatementBlock(workspace) {
      var previousBlock = block
      for _ in 0 ..< 100 {
        if let nextBlock = try buildStatementBlock(workspace) {
          try previousBlock.nextConnection?.connectTo(nextBlock.previousConnection)
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

    for i in 0 ..< blocksPerLevel {
      if let nextBlock = try! _blockFactory.addBlock("statement_statement_input", toWorkspace: workspace)
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
