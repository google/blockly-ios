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
  private var codeManager = CodeManager()

  /// List of all objects that are currently running Javascript code.
  private var codeRunners = [CodeRunner]()

  /// The current button ID that is being edited.
  private var editingButtonID: String = ""

  /// Instruction label.
  @IBOutlet weak var instructions: UILabel!

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    // Load code for each button
    for i in 1...9 {
      generateCode(forButtonID: String(i))
    }

    // Start in edit mode
    setEditing(true, animated: false)
    updateState(animated: false)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // If this view controller is appearing again after editing a button, generate new code for it.
    if !editingButtonID.isEmpty {
      generateCode(forButtonID: editingButtonID)
      editingButtonID = ""
    }
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - State

  private func updateState(animated: Bool) {
    if isEditing {
      let button = UIBarButtonItem(
        barButtonSystemItem: .done, target: self, action: #selector(toggleEditing(_:)))
      navigationItem.setRightBarButton(button, animated: animated)
      navigationItem.title = "Music Maker Configuration"
    } else {
      let button = UIBarButtonItem(
        barButtonSystemItem: .edit, target: self, action: #selector(toggleEditing(_:)))
      navigationItem.setRightBarButton(button, animated: animated)
      navigationItem.title = "Music Maker"
      instructions.text = ""
    }

    UIView.animate(withDuration: animated ? 0.3 : 0.0) {
      if self.isEditing {
        self.instructions.text = "\nTap any button to edit its code.\n\nWhen complete, press Done."
        self.instructions.alpha = 1
        self.view.backgroundColor =
          UIColor(red: 224.0/255.0, green: 224.0/255.0, blue: 224.0/255.0, alpha: 1.0)
      } else {
        self.instructions.text = ""
        self.instructions.alpha = 0
        self.view.backgroundColor = UIColor.white
      }
    }
  }

  // MARK: - User Interaction Handlers

  private dynamic func toggleEditing(_ sender: UIButton) {
    setEditing(!isEditing, animated: true)
    updateState(animated: true)
  }

  @IBAction func pressedMusicButton(_ sender: Any) {
    guard let button = sender as? UIButton,
      let buttonID = button.currentTitle else {
      return
    }

    if isEditing {
      editButton(buttonID: buttonID)
    } else {
      runCode(forButtonID: buttonID)
    }
  }

  // MARK: - Editing and Running Code

  /**
   Opens the code editor for a given button ID.

   - parameter buttonID: The button ID to edit.
   */
  func editButton(buttonID: String) {
    editingButtonID = buttonID

    // Load the editor for this button number
    let buttonEditorViewController = ButtonEditorViewController()
    buttonEditorViewController.loadBlocks(forButtonID: buttonID)
    navigationController?.pushViewController(buttonEditorViewController, animated: true)
  }

  /**
   Requests that the code manager generate code for a given button ID.

   - parameter buttonID: The button ID.
   */
  func generateCode(forButtonID buttonID: String) {
    // If a saved workspace file exists for this button, generate the code for it.
    if let workspaceXML = FileHelper.loadContents(of: "workspace\(buttonID).xml") {
      codeManager.generateCode(forKey: String(buttonID), workspaceXML: workspaceXML)
    }
  }

  /**
   Runs code associated with a given button ID.

   - parameter buttonID: The button ID.
   */
  func runCode(forButtonID buttonID: String) {
    // If code exists for this button, run it.
    if let code = codeManager.code(forKey: buttonID),
      code != "" {
      let codeRunner = CodeRunner()

      // Add this code runner to the list of code runners to keep it in memory while it is
      // executing.
      codeRunners.append(codeRunner)

      codeRunner.runJavascriptCode(code, completion: {
        // Remove this code runner from the list of code runners, so it is deallocated.
        self.codeRunners = self.codeRunners.filter { $0 !== codeRunner }
      })
    } else {
      print("No code has been set up for button \(buttonID).")
    }
  }
}
