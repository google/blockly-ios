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

import UIKit

/**
 View controller for displaying music maker buttons.

 In "run" mode, pressing a button will run code configured for that button.

 In "edit" mode, pressing a button will allow the user to edit the code for that button.
 */
class MusicMakerViewController: UIViewController {

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    updateState()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - User Interaction Handlers

  private dynamic func toggleEditing(_ sender: UIButton) {
    setEditing(!isEditing, animated: true)
    updateState()
  }

  @IBAction func pressedMusicButton(_ sender: Any) {
    guard let button = sender as? UIButton else {
      return
    }

    // Each button is uniquely tagged in the storyboard with a number
    let buttonNumber = button.tag

    if isEditing {
      // Load the editor for this button number
      let buttonEditorViewController = ButtonEditorViewController()
      buttonEditorViewController.loadBlocks(forButtonNumber: buttonNumber)
      navigationController?.pushViewController(buttonEditorViewController, animated: true)
    } else {
      // TODO: Run code for this button
      print("Pressed music button #\(buttonNumber).")

      let codeRunner = CodeRunner()
      codeRunner.runJavascriptCode("for (var i = 0; i < 100; i++) { MusicMaker.playSound('\(buttonNumber)'); }")
    }
  }

  // MARK: - State

  private func updateState() {
    if isEditing {
      let button = UIBarButtonItem(
        barButtonSystemItem: .done, target: self, action: #selector(toggleEditing(_:)))
      navigationItem.setRightBarButton(button, animated: true)
      navigationItem.title = "Configure Music Maker"
    } else {
      let button = UIBarButtonItem(
        barButtonSystemItem: .edit, target: self, action: #selector(toggleEditing(_:)))
      navigationItem.setRightBarButton(button, animated: true)
      navigationItem.title = "Music Maker"
    }
  }
}
