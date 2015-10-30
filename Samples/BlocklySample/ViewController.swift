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

  override func viewDidLoad() {
    super.viewDidLoad()

    let workspace = buildWorkspace()

    guard let workspaceLayout = workspace.layout else {
      return
    }
    workspaceLayout.updateLayoutDownTree()

    let workspaceView = WorkspaceView()
    workspaceView.layout = workspaceLayout
    workspaceView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
    workspaceView.translatesAutoresizingMaskIntoConstraints = false
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

  func buildWorkspace() -> Workspace {
    let layoutFactory = LayoutFactory()
    let workspace = Workspace(layoutFactory: layoutFactory, isFlyout: false)

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

  func buildBlock(workspace: Workspace, filename: String) -> Block? {
    do {
      let path = NSBundle.mainBundle().pathForResource(filename, ofType: "json")
      let jsonString = try String(contentsOfFile: path!, encoding: NSUTF8StringEncoding)
      let json = try NSJSONSerialization.bky_JSONDictionaryFromString(jsonString)
      return try Block.blockFromJSON(json, workspace: workspace)
    } catch let error as NSError {
      print("An error occurred loading the block: \(error)")
    }

    return nil
  }

  func buildOutputBlock(workspace: Workspace) -> Block? {
    return buildBlock(workspace, filename: "TestBlockOutput")
  }

  func buildStatementBlock(workspace: Workspace) -> Block? {
    return buildBlock(workspace, filename: "TestBlockStatement")
  }

  func buildChainedStatementBlock(workspace: Workspace) -> Block? {
    if let block = buildStatementBlock(workspace) {
      var previousBlock = block
      for (var i = 0; i < 10; i++) {
        if let nextBlock = buildStatementBlock(workspace) {
          try! previousBlock.nextConnection?.connectTo(nextBlock.previousConnection)
          previousBlock = nextBlock
        }
      }

      return block
    }

    return nil
  }
}
