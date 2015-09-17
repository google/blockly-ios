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
    let workspaceLayout = LayoutBuilder.buildLayoutTreeFromWorkspace(workspace)
    workspaceLayout.updateLayout()

    let workspaceView = WorkspaceView()
    workspaceView.layout = workspaceLayout
    workspaceView.backgroundColor = UIColor.greenColor()
    workspaceView.translatesAutoresizingMaskIntoConstraints = false
    workspaceView.frame = self.view.bounds
    workspaceView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    self.view.addSubview(workspaceView)
    self.view.sendSubviewToBack(workspaceView)
    workspaceView.refresh()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }

  // MARK: - Private

  func buildWorkspace() -> Workspace {
    let workspace = Workspace(isFlyout: false)

    if let block1 = buildBlock(workspace) {
      workspace.addBlock(block1, asTopBlock: true)

      if let block2 = buildBlock(workspace) {
        workspace.addBlock(block2, asTopBlock: false)
        block1.nextConnection?.connectTo(block2.previousConnection)
      }
    }

    return workspace
  }

  func buildBlock(workspace: Workspace) -> Block? {
    do {
      let path = NSBundle.mainBundle().pathForResource("TestBlock", ofType: "json")
      let jsonString = try String(contentsOfFile: path!, encoding: NSUTF8StringEncoding)
      let json = try NSJSONSerialization.bky_JSONDictionaryFromString(jsonString)
      return try Block.blockFromJSON(json, workspace: workspace)
    } catch let error as NSError {
      print("An error occurred loading the block: \(error)")
    }

    return nil
  }
}
