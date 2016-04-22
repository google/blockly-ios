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
public protocol FieldColorPickerViewControllerDelegate: class {
  /**
   Event that is called when the user has selected a color for a color field.

   - Parameter viewController: The view controller where this event occurred.
   - Parameter colouur: The selected color.
   */
  func fieldColorPickerViewController(viewController: FieldColorPickerViewController,
    didPickColor color: UIColor)
}

/**
 View controller for selecting a color for a `FieldColor`.
 */
@objc(BKYFieldColorPickerViewController)
public class FieldColorPickerViewController: UICollectionViewController {
  // MARK: - Properties

  /// Array of colors for a simple-grid color picker.
  /// From: https://github.com/google/closure-library/blob/master/closure/goog/ui/colorpicker.js
  public var colors = [
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
  public var preferredColorsPerRow = 7

  /// The size of each color button
  public var buttonSize: CGSize = CGSizeMake(44, 44) {
    didSet {
      _flowLayout.itemSize = self.buttonSize
    }
  }

  /// The color field to display
  public var fieldColor: FieldColor?

  /// Delegate for events that occur on this controller
  public weak var delegate: FieldColorPickerViewControllerDelegate?

  /// The flow layout used for this collection view
  private var _flowLayout: UICollectionViewFlowLayout!

  /// Reusable cell ID for each color picker cell
  private let _reusableCellIdentifier = "FieldColorPickerViewCell"

  // MARK: - Initializers

  public init() {
    _flowLayout = UICollectionViewFlowLayout()
    _flowLayout.scrollDirection = .Vertical
    _flowLayout.minimumLineSpacing = 0
    _flowLayout.minimumInteritemSpacing = 0
    super.init(collectionViewLayout: _flowLayout)
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func viewDidLoad() {
    super.viewDidLoad()

    self.collectionView?.backgroundColor = UIColor.clearColor()
    self.collectionView?.registerClass(FieldColorPickerViewCell.self,
      forCellWithReuseIdentifier: _reusableCellIdentifier)
  }

  public override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)

    refreshView()
  }

  public override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)

    // Update the selected color after the view has appeared (it doesn't work if called from
    // viewWillAppear)
    updateSelectedColor(animated: true)
  }

  public override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
    return 1
  }

  public override func collectionView(
    collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
  {
    return self.colors.count
  }

  public override func collectionView(collectionView: UICollectionView,
    cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
  {
    let cell = collectionView.dequeueReusableCellWithReuseIdentifier(
      _reusableCellIdentifier, forIndexPath: indexPath) as! FieldColorPickerViewCell
    cell.color = colorForIndexPath(indexPath)
    return cell
  }

  public override func collectionView(
    collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
  {
    if let color = colorForIndexPath(indexPath) {
      delegate?.fieldColorPickerViewController(self, didPickColor: color)
    }
  }

  // MARK: - Public

  public func refreshView() {
    // Set the preferred content size when this view controller is displayed in a popover
    let rows = ceil(CGFloat(self.colors.count) / CGFloat(self.preferredColorsPerRow))
    self.preferredContentSize = CGSizeMake(
      CGFloat(self.preferredColorsPerRow) * _flowLayout.itemSize.width,
      CGFloat(rows) * _flowLayout.itemSize.height)

    // Refresh the collection view
    self.collectionView?.reloadData()

    updateSelectedColor(animated: false)
  }

  // MARK: - Private

  private func updateSelectedColor(animated animated: Bool) {
    guard let selectedColor = self.fieldColor?.color else {
      return
    }

    // Set the selected color, if it exists in the color picker
    for i in 0 ..< colors.count {
      if selectedColor == ColorHelper.colorFromRGB(colors[i]) {
        let indexPath = NSIndexPath(forRow: i, inSection: 0)
        self.collectionView?.selectItemAtIndexPath(
          indexPath, animated: animated, scrollPosition: .CenteredVertically)
        break
      }
    }
  }

  private func colorForIndexPath(indexPath: NSIndexPath) -> UIColor? {
    return ColorHelper.colorFromRGB(self.colors[indexPath.row])
  }
}

// MARK: - FieldColorPickerViewCell

private class FieldColorPickerViewCell: UICollectionViewCell {
  var color: UIColor? {
    didSet { refreshView() }
  }
  override var selected: Bool {
    didSet { refreshView() }
  }

  // MARK: - Super

  override func prepareForReuse() {
    self.backgroundColor = UIColor.clearColor()
    self.contentView.backgroundColor = UIColor.clearColor()
    self.selected = false
    self.layer.borderColor = UIColor.clearColor().CGColor
    self.layer.borderWidth = 0
  }

  // MARK: - Public

  func refreshView() {
    self.backgroundColor = self.color

    if self.selected {
      self.layer.borderColor = UIColor.whiteColor().CGColor
      self.layer.borderWidth = 2
    } else {
      self.layer.borderColor = UIColor.clearColor().CGColor
      self.layer.borderWidth = 0
    }

    self.setNeedsDisplay()
    self.layer.setNeedsDisplay()
  }
}
