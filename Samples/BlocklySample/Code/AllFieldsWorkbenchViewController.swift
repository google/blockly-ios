/*
 * Copyright 2016 Google Inc. All Rights Reserved.
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

class AllFieldsWorkbenchViewController: WorkbenchViewController {
  // MARK: - Properties

  /// Factory that produces block instances from a parsed json file
  lazy var _blockFactory: BlockFactory = {
    let blockFactory = BlockFactory()

    do {
      try blockFactory.load(fromJSONPaths: ["AllFieldsDemo/custom_field_blocks.json"])
    } catch let error {
      print("Couldn't load `custom_field_blocks.json` into the block factory: \(error)")
    }

    return blockFactory
  }()

  // MARK: - Initializers

  init() {
    super.init(style: .defaultStyle)
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    // Don't allow the navigation controller bar cover this view controller
    self.edgesForExtendedLayout = UIRectEdge()
    self.navigationItem.title = "Workbench with All Field Types"

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

      try loadWorkspace(workspace)
    } catch let error {
      print("Couldn't build layout tree for workspace: \(error)")
    }
  }

  private func loadToolbox() {
    // Create a new toolbox with a "Blocks" category
    let toolbox = Toolbox()
    let blocksCategory =
      toolbox.addCategory(name: "Blocks", color: UIColor.yellow, icon: UIImage(named: "icon_block"))

    // Add all field blocks to the "Blocks" category
    let blockNames = [
      "field_angle_block", "field_checkbox_block", "field_colour_block", "field_date_block",
      "field_dropdown_block", "field_input_block", "field_image_local_block",
      "field_image_web_block", "field_label_block", "field_number_nonconstrained_block",
      "field_number_integer_block", "field_number_currency_block", "field_number_constrained_block",
      "field_variable_block"
    ]

    for blockName in blockNames {
      do {
        let block = try _blockFactory.makeBlock(name: blockName)
        try blocksCategory.addBlockTree(block)
      } catch let error {
        print("Error adding '\(blockName)' block to category: \(error)")
      }
    }

    // Load the toolbox into the workbench
    do {
      try loadToolbox(toolbox, blockFactory: _blockFactory)
    } catch let error {
      print("Error loading toolbox into workbench: \(error)")
      return
    }
  }
}
