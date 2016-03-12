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
public class DemoPickerViewController: UITableViewController {
  private let DEMO_VIEW_CONTROLLERS = [
    "Simple Workbench Demo",
    "Turtle Demo",
  ]

  public override func viewDidLoad() {
    self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "DemoPickerViewCell")
  }

  public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
  {
    return DEMO_VIEW_CONTROLLERS.count
  }

  public override func tableView(
    tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
  {
    let cell =
      tableView.dequeueReusableCellWithIdentifier("DemoPickerViewCell", forIndexPath: indexPath)
    cell.textLabel?.text = DEMO_VIEW_CONTROLLERS[indexPath.row]

    return cell
  }

  public override func tableView(
    tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
  {
    tableView.deselectRowAtIndexPath(indexPath, animated: true)

    var viewController: UIViewController!
    switch indexPath.row {
    case 0:
      viewController = SimpleWorkbenchViewController()
    case 1:
      viewController = TurtleViewController()
    default:
      break
    }

    if viewController != nil {
      self.navigationController?.pushViewController(viewController, animated: true)
    }
  }
}
