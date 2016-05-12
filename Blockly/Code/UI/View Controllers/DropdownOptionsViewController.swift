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
 Delegate for events that occur on `DropdownOptionsViewController`.
 */
public protocol DropdownOptionsViewControllerDelegate: class {
  /**
   Event that is called when the user has selected an option for the drop-down field.

   - Parameter viewController: The view controller where this event occurred.
   - Parameter optionIndex: The selected option index.
   */
  func dropdownOptionsViewController(viewController: DropdownOptionsViewController,
    didSelectOptionIndex optionIndex: Int)
}

/**
 View controller for selecting an option from inside a dropdown.
 */
@objc(BKYDropdownOptionsViewController)
public class DropdownOptionsViewController: UITableViewController {

  // MARK: - Type Alias - Option

  /// Represents a dropdown option, with a display name and value
  public typealias Option = (displayName: String, value: String)

  // MARK: - Properties

  /// The list of drop-down options to display.
  public var options = [Option]() {
    didSet {
      // Recalculate the preferred content size
      calculatePreferredContentSize()
    }
  }
  /// The currently selected index.
  public var selectedIndex = -1 {
    didSet {
      if selectedIndex != oldValue {
        calculatePreferredContentSize()
      }
    }
  }
  /// Delegate for events that occur on this controller
  public weak var delegate: DropdownOptionsViewControllerDelegate?
  /// The font to render each cell
  public var textLabelFont = UIFont.systemFontOfSize(18)
  /// The maximum size to use when displaying this view controller as a popover
  public var maximumPopoverSize = CGSizeMake(248, 248)
  /// Identifier for reusing cells for this table
  private let cellReuseIdentifier = "DropdownOptionsViewControllerCell"
  /// The estimated width of the checkmark accessory (this value does not appear to be accessible)
  private let accessoryWidth = CGFloat(30)
  /// The cell padding
  private let cellPadding = UIEdgeInsetsMake(16, 16, 16, 16)

  // MARK: - Super

  public override func viewDidLoad() {
    tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
    tableView.reloadData()
  }

  public override func viewWillAppear(animated: Bool) {
    if 0 <= selectedIndex && selectedIndex < options.count {
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
    return options.count ?? 0
  }

  public override func tableView(
    tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
  {
    return cellSizeForRow(indexPath.row, constrainedToWidth: view.bounds.width).height
  }

  public override func tableView(
    tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
  {
    let cell = tableView.dequeueReusableCellWithIdentifier(
      self.cellReuseIdentifier, forIndexPath: indexPath)
    cell.accessoryType = (selectedIndex == indexPath.row ? .Checkmark : .None)
    cell.selectionStyle = .Default
    cell.textLabel?.font = textLabelFont
    cell.textLabel?.numberOfLines = 0
    cell.textLabel?.text = options[indexPath.row].displayName
    cell.textLabel?.sizeToFit()

    return cell
  }

  // MARK: - UITableViewDelegate

  public override func tableView(
    tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
  {
    tableView.deselectRowAtIndexPath(indexPath, animated: true)

    delegate?.dropdownOptionsViewController(self, didSelectOptionIndex: indexPath.row)
  }

  // MARK: - Private

  private func calculatePreferredContentSize() {
    var preferredContentSize = CGSizeZero

    for i in 0 ..< options.count {
      let cellSize = cellSizeForRow(i, constrainedToWidth: maximumPopoverSize.width)
      preferredContentSize.height =
        min(preferredContentSize.height + cellSize.height, maximumPopoverSize.height)
      preferredContentSize.width = max(preferredContentSize.width, cellSize.width)
    }

    self.preferredContentSize = preferredContentSize
  }

  private func cellSizeForRow(row: Int, constrainedToWidth width: CGFloat) -> CGSize {
    // Measure the text width (taking into account the cell's x-padding)
    let text = options[row].displayName
    let xPadding =
      cellPadding.left + cellPadding.right + (selectedIndex == row ? accessoryWidth : 0)
    let width = width - xPadding
    var size = text.bky_multiLineSizeForFont(textLabelFont, constrainedToWidth: width)

    // Add the cell padding back to the measured text size
    size.height += cellPadding.top + cellPadding.bottom
    size.width += xPadding
    return size
  }
}
