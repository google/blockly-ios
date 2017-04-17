/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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

import Blockly
import UIKit

/**
 View controller for editing the "code" when pressing a music button.
 */
class ButtonEditorViewController: UIViewController {

  // MARK: - Properties

  /// The main Blockly editor.
  private var workbenchViewController: WorkbenchViewController = {
    let workbenchViewController = WorkbenchViewController(style: .alternate)

    // Load default blocks into the block factory
    let blockFactory = workbenchViewController.blockFactory
    blockFactory.load(fromDefaultFiles: .allDefault)

    // Load sound blocks into the block factory
    do {
      try blockFactory.load(fromJSONPaths: ["sound_blocks.json"])
    } catch let error {
      print("An error occurred loading the turtle blocks: \(error)")
    }

    // Load toolbox
    do {
      let toolboxPath = "toolbox.xml"
      if let bundlePath = Bundle.main.path(forResource: toolboxPath, ofType: nil) {
        let xmlString = try String(contentsOfFile: bundlePath, encoding: String.Encoding.utf8)
        let toolbox = try Toolbox.makeToolbox(xmlString: xmlString, factory: blockFactory)
        try workbenchViewController.loadToolbox(toolbox)
      } else {
        print("Could not load toolbox XML from '\(toolboxPath)'")
      }
    } catch let error {
      print("An error occurred loading the toolbox: \(error)")
    }

    return workbenchViewController
  }()

  /// The button number to edit.
  public private(set) var buttonNumber: Int = 0

  /// File where data is saved.
  private var saveFile: String {
    return "workspace\(buttonNumber).xml"
  }

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    edgesForExtendedLayout = []

    // Add editor to this view controller
    addChildViewController(workbenchViewController)
    view.addSubview(workbenchViewController.view)
    workbenchViewController.view.frame = view.bounds
    workbenchViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    workbenchViewController.didMove(toParentViewController: self)
  }

  override func viewWillDisappear(_ animated: Bool) {
    // Save on exit
    saveBlocks()

    super.viewWillDisappear(animated)
  }

  // MARK: - Load / Write

  public func loadBlocks(forButtonNumber buttonNumber: Int) {
    self.buttonNumber = buttonNumber

    // Load workspace from disk
    if let xml = FileHelper.loadContents(of: saveFile) {
      do {
        let workspace = Workspace()
        try workspace.loadBlocks(fromXMLString: xml, factory: workbenchViewController.blockFactory)
        try workbenchViewController.loadWorkspace(workspace)
      } catch let error {
        print("Couldn't load workspace from disk: \(error)")
      }
    }
  }

  public func saveBlocks() {
    // Save the workspace to disk
    if let workspace = workbenchViewController.workspace {
      do {
        let xml = try workspace.toXML()
        FileHelper.saveContents(xml, to: saveFile)
      } catch let error {
        print("Couldn't save workspace to disk: \(error)")
      }
    }
  }
}
