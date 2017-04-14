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
  private let workbenchViewController = WorkbenchViewController(style: .defaultStyle)

  /// The button number to edit.
  public private(set) var buttonNumber: Int = 0

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

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

    // TODO: Load saved blocks for button
  }

  public func saveBlocks() {
    // TODO
  }
}
