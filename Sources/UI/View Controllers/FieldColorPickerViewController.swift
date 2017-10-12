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
@objc(BKYFieldColorPickerViewControllerDelegate)
public protocol FieldColorPickerViewControllerDelegate: class {
  /**
   Event that is called when the user has selected a color for a color field.

   - parameter viewController: The view controller where this event occurred.
   - parameter color: The selected color.
   */
  func fieldColorPickerViewController(
    _ viewController: FieldColorPickerViewController, didPickColor color: UIColor)
}

/**
 View controller for selecting a color for a `FieldColor`.
 */
@objc(BKYFieldColorPickerViewController)
@objcMembers open class FieldColorPickerViewController: UICollectionViewController {
  // MARK: - Properties

  /// Array of colors for a simple-grid color picker.
  /// From: https://github.com/google/closure-library/blob/master/closure/goog/ui/colorpicker.js
  open var colors = [
    // grays
    "#ffffff", "#cccccc", "#c0c0c0", "#999999", "#666666", "#333333", "#000000",
    // reds
    "#ffcccc", "#ff6666", "#ff0000", "#cc0000", "#990000", "#660000", "#330000",
    // oranges
    "#ffcc99", "#ff9966", "#ff9900", "#ff6600", "#cc6600", "#993300", "#663300",
    // yellows
    "#ffff99", "#ffff66", "#ffcc66", "#ffcc33", "#cc9933", "#996633", "#663333",
    // olives
    "#ffffcc", "#ffff33", "#ffff00", "#ffcc00", "#999900", "#666600", "#333300",
    // greens
    "#99ff99", "#66ff99", "#33ff33", "#33cc00", "#009900", "#006600", "#003300",
    // turquoises
    "#99ffff", "#33ffff", "#66cccc", "#00cccc", "#339999", "#336666", "#003333",
    // blues
    "#ccffff", "#66ffff", "#33ccff", "#3366ff", "#3333ff", "#000099", "#000066",
    // purples
    "#ccccff", "#9999ff", "#6666cc", "#6633ff", "#6600cc", "#333399", "#330099",
    // violets
    "#ffccff", "#ff99ff", "#cc66cc", "#cc33cc", "#993399", "#663366", "#330033",
    ]
  {
    didSet {
      self.collectionView?.reloadData()
    }
  }

  /// Preferred number of colors to display per row (this value may not be respected if there is
  /// not enough space available).
  open var preferredColorsPerRow = 7

  /// The size of each color button
  open var buttonSize: CGSize = CGSize(width: 44, height: 44) {
    didSet {
      _flowLayout.itemSize = self.buttonSize
    }
  }

  /// The color field to display
  open var color: UIColor?

  /// Delegate for events that occur on this controller
  open weak var delegate: FieldColorPickerViewControllerDelegate?

  /// The flow layout used for this collection view
  fileprivate let _flowLayout: UICollectionViewFlowLayout = {
    let flowLayout = UICollectionViewFlowLayout()
    flowLayout.scrollDirection = .vertical
    flowLayout.minimumLineSpacing = 0
    flowLayout.minimumInteritemSpacing = 0
    return flowLayout
  }()

  /// Reusable cell ID for each color picker cell
  fileprivate let _reusableCellIdentifier = "FieldColorPickerViewCell"

  // MARK: - Initializers

  public init() {
    super.init(collectionViewLayout: _flowLayout)
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  open override func viewDidLoad() {
    super.viewDidLoad()

    self.collectionView?.backgroundColor = UIColor.clear
    self.collectionView?.register(FieldColorPickerViewCell.self,
      forCellWithReuseIdentifier: _reusableCellIdentifier)
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    refreshView()
  }

  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Update the selected color after the view has appeared (it doesn't work if called from
    // viewWillAppear)
    updateSelectedColor(animated: true)
  }

  open override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }

  open override func collectionView(
    _ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
  {
    return self.colors.count
  }

  open override func collectionView(_ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
  {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: _reusableCellIdentifier, for: indexPath) as! FieldColorPickerViewCell
    cell.color = makeColor(indexPath: indexPath)
    return cell
  }

  open override func collectionView(
    _ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
  {
    if let color = makeColor(indexPath: indexPath) {
      delegate?.fieldColorPickerViewController(self, didPickColor: color)
    }
  }

  // MARK: - Public

  open func refreshView() {
    // Set the preferred content size when this view controller is displayed in a popover
    let rows = ceil(CGFloat(self.colors.count) / CGFloat(self.preferredColorsPerRow))
    self.preferredContentSize = CGSize(
      width: CGFloat(self.preferredColorsPerRow) * _flowLayout.itemSize.width,
      height: CGFloat(rows) * _flowLayout.itemSize.height)

    // Refresh the collection view
    self.collectionView?.reloadData()

    updateSelectedColor(animated: false)
  }

  // MARK: - Private

  fileprivate func updateSelectedColor(animated: Bool) {
    guard let selectedColor = self.color else {
      return
    }

    // Set the selected color, if it exists in the color picker
    for i in 0 ..< colors.count {
      if selectedColor == ColorHelper.makeColor(rgb: colors[i]) {
        let indexPath = IndexPath(row: i, section: 0)
        self.collectionView?.selectItem(
          at: indexPath, animated: animated, scrollPosition: .centeredVertically)
        break
      }
    }
  }

  fileprivate func makeColor(indexPath: IndexPath) -> UIColor? {
    return ColorHelper.makeColor(rgb: self.colors[(indexPath as NSIndexPath).row])
  }
}

// MARK: - FieldColorPickerViewCell

private class FieldColorPickerViewCell: UICollectionViewCell {
  var color: UIColor? {
    didSet { refreshView() }
  }
  override var isSelected: Bool {
    didSet { refreshView() }
  }

  // MARK: - Super

  override func prepareForReuse() {
    self.backgroundColor = UIColor.clear
    self.contentView.backgroundColor = UIColor.clear
    self.isSelected = false
    self.layer.borderColor = UIColor.clear.cgColor
    self.layer.borderWidth = 0
  }

  // MARK: - Public

  func refreshView() {
    self.backgroundColor = self.color

    if self.isSelected {
      self.layer.borderColor = UIColor.white.cgColor
      self.layer.borderWidth = 2
    } else {
      self.layer.borderColor = UIColor.clear.cgColor
      self.layer.borderWidth = 0
    }

    self.setNeedsDisplay()
    self.layer.setNeedsDisplay()
  }
}
