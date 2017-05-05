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
 View controller for editing the "code" when pressing a music button.
 */
class ButtonEditorViewController: UIViewController {

  // MARK: - Properties

  /// The ID of the button that is being edited.
  public private(set) var buttonID: String = "" {
    didSet {
      self.navigationItem.title = "Edit Button \(buttonID)"
    }
  }

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    edgesForExtendedLayout = []
  }

  override func viewDidAppear(_ animated: Bool) {
    self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
  }

  // MARK: - Load / Write

  /**
   Load a workspace for a button ID into the workbench, if it exists on disk.

   - parameter buttonID: The button ID to load.
   */
  public func loadBlocks(forButtonID buttonID: String) {
    self.buttonID = buttonID

    print("TODO: Load blocks for button \(buttonID).")
  }

  /**
   Saves the workspace for this button ID to disk.
   */
  public func saveBlocks() {
    print("TODO: Save blocks to disk.")
  }
}
