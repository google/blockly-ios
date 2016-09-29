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
  let _blockFactory = BlockFactory()

  // MARK: - Initializers

  init() {
    super.init(style: .defaultStyle)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    // Load blocks into the block factory
    do {
      try _blockFactory.load(fromJSONPaths: ["Blocks/simple_workbench_blocks.json"])
    } catch let error as NSError {
      print("An error occurred loading the test blocks: \(error)")
    }
  }

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    // Don't allow the navigation controller bar cover this view controller
    self.edgesForExtendedLayout = UIRectEdge()
    self.navigationItem.title = "Simple Workbench Demo"

    // Load data
    loadWorkspace()
    loadToolbox()
  }

  override var prefersStatusBarHidden : Bool {
    return true
  }

  // MARK: - Private

  private func loadWorkspace() {
    do {
      // Create a workspace
      let workspace = Workspace()

      // Add some blocks to the workspace
      // try addChainedBlocks(toWorkspace: workspace)
      // try addSpaghettiBlocks(toWorkspace: workspace)

      try loadWorkspace(workspace)
    } catch let error as NSError {
      print("Couldn't build layout tree for workspace: \(error)")
    }
  }

  private func loadToolbox() {
    // Create a toolbox
    do {
      let toolbox = Toolbox()

      let loopIcon = UIImage(named: "icon_loop")
      let loops = toolbox.addCategory(name: "Loops", color: UIColor.yellow, icon: loopIcon)
      if let repeatBlock = try? _blockFactory.makeBlock(name: "controls_repeat_ext"),
        let repeatBlockInput = repeatBlock.firstInput(withName: "TIMES"),
        let numberBlock = try? _blockFactory.makeBlock(name: "non_negative_integer", shadow: true)
      {
        // Add shadow block to repeat loop
        try repeatBlockInput.connection?.connectShadowTo(numberBlock.outputConnection)
        try loops.addBlockTree(repeatBlock)
      }
      try addBlock("controls_whileUntil", toWorkspace: loops)

      let prevNextIcon = UIImage(named: "icon_prevnext")
      let prevNextCategory =
        toolbox.addCategory(name: "Prev / Next", color: UIColor.green, icon: prevNextIcon)
      try addBlock("statement_no_input", toWorkspace: prevNextCategory)
      if
        let statementValueInputBlock = try? _blockFactory.makeBlock(name: "statement_value_input"),
        let noNextBlock = try? _blockFactory.makeBlock(name: "statement_value_input", shadow: true),
        let noNextBlock2 = try? _blockFactory.makeBlock(name: "statement_no_input", shadow: true),
        let simpleInputOutput = try? _blockFactory.makeBlock(
          name: "simple_input_output", shadow: true)
      {
        // Add shadow block to next block
        try statementValueInputBlock.nextConnection?.connectShadowTo(noNextBlock.previousConnection)
        try noNextBlock.lastInputValueConnectionInChain()?.connectShadowTo(
          simpleInputOutput.outputConnection)
        try noNextBlock.nextConnection?.connectShadowTo(noNextBlock2.previousConnection)
        try prevNextCategory.addBlockTree(statementValueInputBlock)
      }
      try addBlock("statement_multiple_value_input", toWorkspace: prevNextCategory)
      try addBlock("statement_no_next", toWorkspace: prevNextCategory)
      try addBlock("statement_statement_input", toWorkspace: prevNextCategory)
      try addBlock("block_statement", toWorkspace: prevNextCategory)

      let blockIcon = UIImage(named: "icon_block")
      let random = toolbox.addCategory(name: "Random", color: UIColor.orange, icon: blockIcon)
      try addBlock("web_image", toWorkspace: random)
      try addBlock("local_image", toWorkspace: random)
      try addBlock("angle", toWorkspace: random)
      try addBlock("checkbox", toWorkspace: random)
      try addBlock("date_picker", toWorkspace: random)
      try addBlock("colour_picker", toWorkspace: random)
      try addBlock("test_dropdown", toWorkspace: random)
      try addBlock("text_input_block", toWorkspace: random)
      try addBlock("any_number", toWorkspace: random)
      try addBlock("currency", toWorkspace: random)
      try addBlock("constrained_decimal", toWorkspace: random)
      random.addGap(40)
      try addBlock("variables_get", toWorkspace: random)
      try addBlock("variables_set", toWorkspace: random)
      random.addGap(40)
      try addBlock("simple_input_output", toWorkspace: random)
      try addBlock("multiple_input_output", toWorkspace: random)
      try addBlock("output_no_input", toWorkspace: random)
      try addBlock("block_output", toWorkspace: random)

      try loadToolbox(toolbox)
    } catch let error as NSError {
      print("An error occurred loading the toolbox: \(error)")
    }
  }

  @discardableResult
  private func addBlock(_ blockName: String, toWorkspace workspace: Workspace) throws -> Block? {
    if let block = try? _blockFactory.makeBlock(name: blockName) {
      try workspace.addBlockTree(block)
      return block
    }
    return nil
  }

  private func addChainedBlocks(toWorkspace workspace: Workspace) throws {
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

  private func addToolboxBlocks(toWorkspace workspace: Workspace) throws {
    let blocks = ["controls_repeat_ext", "controls_whileUntil", "math_number",
      "simple_input_output", "multiple_input_output", "statement_no_input", "statement_value_input",
      "statement_multiple_value_input", "statement_statement_input", "output_no_input",
      "statement_no_next", "block_output", "block_statement"]

    for block in blocks {
      try addBlock(block, toWorkspace: workspace)
    }
  }

  private func addSpaghettiBlocks(toWorkspace workspace: Workspace) throws {
    try buildSpaghettiBlock(workspace, level: 4, blocksPerLevel: 5)
  }

  private func buildOutputBlock(_ workspace: Workspace) throws -> Block? {
    return try addBlock("block_output", toWorkspace: workspace)
  }

  private func buildStatementBlock(_ workspace: Workspace) throws -> Block? {
    return try addBlock("block_statement", toWorkspace: workspace)
  }

  private func buildChainedStatementBlock(_ workspace: Workspace) throws -> Block? {
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

  @discardableResult
  private func buildSpaghettiBlock(_ workspace: Workspace, level: Int, blocksPerLevel: Int) throws
    -> Block?
  {
    if level <= 0 {
      return nil
    }
    var firstBlock: Block?
    var previousBlock: Block? = nil

    for i in 0 ..< blocksPerLevel {
      if let nextBlock = try addBlock("statement_statement_input", toWorkspace: workspace)
      {
        if let spaghettiBlock =
          try buildSpaghettiBlock(workspace, level: level - 1, blocksPerLevel: blocksPerLevel)
        {
          try nextBlock.inputs[0].connection?.connectTo(spaghettiBlock.previousConnection)
        }

        try previousBlock?.nextConnection?.connectTo(nextBlock.previousConnection)
        if i == 0 {
          firstBlock = nextBlock
        }
        previousBlock = nextBlock
      }
    }
    return firstBlock
  }
}
