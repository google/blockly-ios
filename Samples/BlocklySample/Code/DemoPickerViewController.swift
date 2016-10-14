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

/**
 View controller for picking between Blockly demos.
 */
class DemoPickerViewController: UITableViewController {
  private let DEMO_VIEW_CONTROLLERS = [
    "Workbench with Default Blocks",
    "Workbench with All Field Types",
    "Swift Turtle Demo",
    "Objective-C Turtle Demo",
  ]

  override func viewDidLoad() {
    self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DemoPickerViewCell")
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
  {
    return DEMO_VIEW_CONTROLLERS.count
  }

  override func tableView(
    _ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
  {
    let cell =
      tableView.dequeueReusableCell(withIdentifier: "DemoPickerViewCell", for: indexPath)
    cell.textLabel?.text = DEMO_VIEW_CONTROLLERS[(indexPath as NSIndexPath).row]

    return cell
  }

  override func tableView(
    _ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
  {
    tableView.deselectRow(at: indexPath, animated: true)

    var viewController: UIViewController!
    switch (indexPath as NSIndexPath).row {
    case 0:
      viewController = SimpleWorkbenchViewController()
    case 1:
      viewController = AllFieldsWorkbenchViewController()
    case 2:
      viewController = TurtleSwiftViewController()
    case 3:
      viewController = TurtleObjCViewController()
    default:
      break
    }

    if viewController != nil {
      self.navigationController?.pushViewController(viewController, animated: true)
    }
  }
}
