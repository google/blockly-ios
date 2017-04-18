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
 View controller for displaying music maker buttons.

 In "run" mode, pressing a button will run code configured for that button.

 In "edit" mode, pressing a button will allow the user to edit the code for that button.
 */
class MusicMakerViewController: UIViewController {

  /// Generates and stores Javascript code for each button.
  var codeManager = CodeManager()

  /// List of all objects that are currently running Javascript code.
  var codeRunners = [CodeRunner]()

  /// The current button number that is being edited.
  var editingButtonNumber = 0

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    // Load code for each button
    for i in 1...6 {
      generateCode(forButton: i)
    }

    updateState(animated: false)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // If this view controller is appearing again after editing a button, generate new code for it.
    if editingButtonNumber > 0 {
      generateCode(forButton: editingButtonNumber)
      editingButtonNumber = 0
    }
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - User Interaction Handlers

  private dynamic func toggleEditing(_ sender: UIButton) {
    setEditing(!isEditing, animated: true)
    updateState(animated: true)
  }

  @IBAction func pressedMusicButton(_ sender: Any) {
    guard let button = sender as? UIButton else {
      return
    }

    // Each button is uniquely tagged in the storyboard with a number
    let buttonNumber = button.tag

    if isEditing {
      editButton(buttonNumber)
    } else {
      runCode(forButton: buttonNumber)
    }
  }

  // MARK: - Editing

  func editButton(_ button: Int) {
    // Load the editor for this button number
    let buttonEditorViewController = ButtonEditorViewController()
    buttonEditorViewController.loadBlocks(forButtonNumber: button)
    navigationController?.pushViewController(buttonEditorViewController, animated: true)

    editingButtonNumber = button
  }

  func generateCode(forButton button: Int) {
    // If a saved workspace file exists for this button, generate the code for it.
    if let workspaceXML = FileHelper.loadContents(of: "workspace\(button).xml") {
      codeManager.generateCode(forKey: String(button), workspaceXML: workspaceXML)
    }
  }

  func runCode(forButton button: Int) {
    // If code exists for this button, run it.
    if let code = codeManager.code(forKey: String(button)) {
      let codeRunner = CodeRunner()
      codeRunners.append(codeRunner)

      codeRunner.runJavascriptCode(code) {
        self.codeRunners = self.codeRunners.filter { $0 !== codeRunner }
      }
    }
  }

  // MARK: - State

  private func updateState(animated: Bool) {
    if isEditing {
      let button = UIBarButtonItem(
        barButtonSystemItem: .done, target: self, action: #selector(toggleEditing(_:)))
      navigationItem.setRightBarButton(button, animated: animated)
      navigationItem.title = "Configure Music Maker"
    } else {
      let button = UIBarButtonItem(
        barButtonSystemItem: .edit, target: self, action: #selector(toggleEditing(_:)))
      navigationItem.setRightBarButton(button, animated: animated)
      navigationItem.title = "Music Maker"
    }

    UIView.animate(withDuration: animated ? 0.3 : 0.0) {
      self.view.backgroundColor = self.isEditing ?
        UIColor(red: 158.0/255.0, green: 158.0/255.0, blue: 158.0/255.0, alpha: 1.0) :
        UIColor.white
    }
  }
}
