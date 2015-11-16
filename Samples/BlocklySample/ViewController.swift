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

class ViewController: UIViewController {
  // MARK: - Super

  private var _blockFactory: BlockFactory!

  override func viewDidLoad() {
    super.viewDidLoad()

    do {
      _blockFactory = try BlockFactory(jsonPath: "TestBlocks")
    } catch let error as NSError {
      print("An error occurred loading the test blocks: \(error)")
    }

    let workspace = createWorkspace()

    do {
      // Create the workspace layout, which is required for viewing the workspace
      workspace.layout = WorkspaceLayout(workspace: workspace, layoutBuilder: LayoutBuilder())

      // Build its layout tree, which creates layout objects for all of its blocks/inputs/fields
      // (allowing them to show up in the workspace view)
      try workspace.layout!.layoutBuilder.buildLayoutTree()

      // Perform a layout update for the entire tree
      workspace.layout!.updateLayoutDownTree()
    } catch let error as NSError {
      print("Couldn't build layout tree for workspace: \(error)")
    }

    let workspaceView = WorkspaceView()
    workspaceView.layout = workspace.layout
    workspaceView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
    workspaceView.frame = self.view.bounds
    workspaceView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    self.view.addSubview(workspaceView)
    self.view.sendSubviewToBack(workspaceView)
    workspaceView.refreshView()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }

  // MARK: - Private

  func createWorkspace() -> Workspace {
    // Create workspace
    let workspace = Workspace(isFlyout: false)

    if let block1 = buildChainedStatementBlock(workspace) {
      if let block2 = buildOutputBlock(workspace) {
        try! block1.inputs[1].connection?.connectTo(block2.outputConnection)

        if let block3 = buildChainedStatementBlock(workspace) {
          try! block2.inputs[0].connection?.connectTo(block3.previousConnection)
        }

        if let block4 = buildOutputBlock(workspace) {
          try! block2.inputs[1].connection?.connectTo(block4.outputConnection)
        }
      }
    }

    return workspace
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
      for (var i = 0; i < 30; i++) {
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
