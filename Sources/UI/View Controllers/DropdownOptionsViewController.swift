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
@objc(BKYDropdownOptionsViewControllerDelegate)
public protocol DropdownOptionsViewControllerDelegate: class {
  /**
   Event that is called when the user has selected an option for the drop-down field.

   - parameter viewController: The view controller where this event occurred.
   - parameter optionIndex: The selected option index.
   */
  func dropdownOptionsViewController(
    _ viewController: DropdownOptionsViewController, didSelectOptionIndex optionIndex: Int)
}

/**
 View controller for selecting an option from inside a dropdown.
 */
@objc(BKYDropdownOptionsViewController)
@objcMembers open class DropdownOptionsViewController: UITableViewController {

  // MARK: - Tuples

  /// Represents a dropdown option, with a display name and value
  public typealias Option = (displayName: String, value: String)

  // MARK: - Properties

  /// The list of drop-down options to display.
  open var options = [Option]() {
    didSet {
      // Recalculate the preferred content size
      calculatePreferredContentSize()
    }
  }
  /// The currently selected index.
  open var selectedIndex = -1 {
    didSet {
      if selectedIndex != oldValue {
        calculatePreferredContentSize()
      }
    }
  }
  /// Delegate for events that occur on this controller
  open weak var delegate: DropdownOptionsViewControllerDelegate?
  /// The font to render each cell
  open var textLabelFont = UIFont.systemFont(ofSize: 18) {
    didSet {
      // Recalculate the preferred content size
      calculatePreferredContentSize()
    }
  }
  /// The color of the font on each cell
  open var textLabelColor: UIColor? = .black
  /// The maximum size to use when displaying this view controller as a popover
  open var maximumPopoverSize = CGSize(width: 300, height: 300)
  /// Identifier for reusing cells for this table
  fileprivate let cellReuseIdentifier = "DropdownOptionsViewControllerCell"
  /// The estimated width of the checkmark accessory (this value does not appear to be accessible)
  fileprivate let accessoryWidth = CGFloat(30)
  /// The cell padding
  fileprivate let cellPadding = UIEdgeInsetsMake(16, 16, 16, 16)

  // MARK: - Super

  open override func viewDidLoad() {
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
    tableView.reloadData()
  }

  open override func viewWillAppear(_ animated: Bool) {
    if 0 <= selectedIndex && selectedIndex < options.count {
      // Automatically scroll to the selected index when the view first appears
      let path = IndexPath(row: selectedIndex, section: 0)
      tableView.scrollToRow(at: path, at: .middle, animated: false)
    }
  }

  // MARK: - UITableViewDataSource

  open override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
  {
    return options.count
  }

  open override func tableView(
    _ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
  {
    return cellSizeForRow((indexPath as NSIndexPath).row, constrainedToWidth: view.bounds.width).height
  }

  open override func tableView(
    _ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
  {
    let cell = tableView.dequeueReusableCell(
      withIdentifier: cellReuseIdentifier, for: indexPath)
    cell.accessoryType = (selectedIndex == (indexPath as NSIndexPath).row ? .checkmark : .none)
    cell.selectionStyle = .default
    cell.textLabel?.font = textLabelFont
    cell.textLabel?.textColor = textLabelColor
    cell.textLabel?.numberOfLines = 0
    cell.textLabel?.text = options[(indexPath as NSIndexPath).row].displayName
    cell.textLabel?.sizeToFit()

    return cell
  }

  // MARK: - UITableViewDelegate

  open override func tableView(
    _ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
  {
    tableView.deselectRow(at: indexPath, animated: true)

    delegate?.dropdownOptionsViewController(self, didSelectOptionIndex: (indexPath as NSIndexPath).row)
  }

  // MARK: - Private

  fileprivate func calculatePreferredContentSize() {
    var contentSize = CGSize.zero

    for i in 0 ..< options.count {
      let cellSize = cellSizeForRow(i, constrainedToWidth: maximumPopoverSize.width)
      contentSize.height =
        min(contentSize.height + cellSize.height, maximumPopoverSize.height)
      contentSize.width = max(contentSize.width, cellSize.width)
    }

    preferredContentSize = contentSize
  }

  fileprivate func cellSizeForRow(_ row: Int, constrainedToWidth width: CGFloat) -> CGSize {
    // Measure the text width (taking into account the cell's x-padding)
    let text = options[row].displayName
    let xPadding =
      cellPadding.left + cellPadding.right + (selectedIndex == row ? accessoryWidth : 0)
    let width = width - xPadding
    var size = text.bky_multiLineSize(forFont: textLabelFont, constrainedToWidth: width)

    // Add the cell padding back to the measured text size
    size.height += cellPadding.top + cellPadding.bottom
    size.width += xPadding
    return size
  }
}
