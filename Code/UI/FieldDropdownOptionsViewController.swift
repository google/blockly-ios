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

import Foundation

/**
 Delegate for events that occur on `FieldDropdownOptionsViewController`.
 */
public protocol FieldDropdownOptionsViewControllerDelegate: class {
  /**
   Event that is called when the user has selected an option for the drop-down field.

   - Parameter viewController: The view controller where this event occurred.
   - Parameter optionIndex: The selected option index.
   */
  func fieldDropdownOptionsViewController(viewController: FieldDropdownOptionsViewController,
    didSelectOptionIndex optionIndex: Int)
}

/**
 View controller for selecting an option inside a `FieldDropdown`.
 */
@objc(BKYFieldDropdownOptionsViewController)
public class FieldDropdownOptionsViewController: UITableViewController {

  // MARK: - Properties

  /// The drop-down field to display
  public var field: FieldDropdown? {
    didSet {
      // Recalculate the preferred content size
      calculatePreferredContentSize()
    }
  }
  /// Delegate for events that occur on this controller
  public weak var delegate: FieldDropdownOptionsViewControllerDelegate?
  // TODO: (#335) Pull font style up into configuration.
  /// The font to render each cell
  public var textLabelFont = UIFont.systemFontOfSize(18)
  /// The maximum size to use when displaying to view controller as a popover
  public var maximumPopoverSize = CGSizeMake(250, 250)
  /// Identifier for reusing cells for this table
  private let cellReuseIdentifier = "FieldDropdownOptionsViewControllerCell"
  /// The estimated width of the checkmark accessory (this value does not appear to be accessible)
  private let accessoryWidth = CGFloat(30)
  /// The cell padding
  private let cellPadding = UIEdgeInsetsMake(15, 15, 15, 15)

  // MARK: - Super

  public override func viewDidLoad() {
    tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
    tableView.reloadData()
  }

  public override func viewWillAppear(animated: Bool) {
    if let selectedIndex = field?.selectedIndex {
      // Automatically scroll to the selected index when the view first appears
      let path = NSIndexPath(forRow: selectedIndex, inSection: 0)
      tableView.scrollToRowAtIndexPath(path, atScrollPosition: .Middle, animated: false)
    }
  }

  // MARK: - UITableViewDataSource

  public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }

  public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
  {
    return field?.options.count ?? 0
  }

  public override func tableView(
    tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
  {
    return cellSizeForRow(indexPath.row, constrainedToWidth: self.view.bounds.size.width).height
  }

  public override func tableView(
    tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
  {
    let cell = tableView.dequeueReusableCellWithIdentifier(self.cellReuseIdentifier,
      forIndexPath: indexPath)
    cell.accessoryType  = field?.selectedIndex == indexPath.row ? .Checkmark : .None
    cell.selectionStyle = .Default
    cell.textLabel?.font = self.textLabelFont
    cell.textLabel?.numberOfLines = 0
    cell.textLabel?.text = field?.options[indexPath.row].displayName
    cell.textLabel?.sizeToFit()

    return cell
  }

  // MARK: - UITableViewDelegate

  public override func tableView(
    tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
  {
    tableView.deselectRowAtIndexPath(indexPath, animated: true)

    delegate?.fieldDropdownOptionsViewController(self, didSelectOptionIndex: indexPath.row)
  }

  // MARK: - Private

  private func calculatePreferredContentSize() {
    var preferredContentSize = CGSizeZero

    if let field = self.field {
      for i in 0 ..< field.options.count {
        let cellSize = cellSizeForRow(i, constrainedToWidth: maximumPopoverSize.width)
        preferredContentSize.height =
          min(preferredContentSize.height + cellSize.height, maximumPopoverSize.height)
        preferredContentSize.width = max(preferredContentSize.width, cellSize.width)
      }
    }

    self.preferredContentSize = preferredContentSize
  }

  private func cellSizeForRow(row: Int, constrainedToWidth width: CGFloat) -> CGSize {
    guard let text = field?.options[row].displayName else {
      return CGSizeZero
    }

    // Measure the text width (taking into account the cell's x-padding)
    let xPadding =
      cellPadding.left + cellPadding.right + (field?.selectedIndex == row ? accessoryWidth : 0)
    let width = width - xPadding
    var size = text.bky_multiLineSizeForFont(self.textLabelFont, constrainedToWidth: width)

    // Add the cell padding back to the measured text size
    size.height += cellPadding.top + cellPadding.bottom
    size.width += xPadding
    return size
  }
}
