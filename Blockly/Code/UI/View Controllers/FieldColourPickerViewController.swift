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
public protocol FieldColourPickerViewControllerDelegate: class {
  /**
   Event that is called when the user has selected a colour for a colour field.

   - Parameter viewController: The view controller where this event occurred.
   - Parameter colouur: The selected colour.
   */
  func fieldColourPickerViewController(viewController: FieldColourPickerViewController,
    didPickColour colour: UIColor)
}

/**
 View controller for selecting a colour for a `FieldColour`.
 */
@objc(BKYFieldColourPickerViewController)
public class FieldColourPickerViewController: UICollectionViewController {
  // MARK: - Properties

  /// Array of colors for a simple-grid color picker.
  /// From: https://github.com/google/closure-library/blob/master/closure/goog/ui/colorpicker.js
  public var colours = [
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

  /// Preferred number of colours to display per row (this value may not be respected if there is
  /// not enough space available).
  public var preferredColoursPerRow = 7

  /// The size of each colour button
  public var buttonSize: CGSize = CGSizeMake(44, 44) {
    didSet {
      _flowLayout.itemSize = self.buttonSize
    }
  }

  /// The colour field to display
  public var fieldColour: FieldColour?

  /// Delegate for events that occur on this controller
  public weak var delegate: FieldColourPickerViewControllerDelegate?

  /// The flow layout used for this collection view
  private var _flowLayout: UICollectionViewFlowLayout!

  /// Reusable cell ID for each colour picker cell
  private let _reusableCellIdentifier = "FieldColourPickerViewCell"

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
    self.collectionView?.registerClass(FieldColourPickerViewCell.self,
      forCellWithReuseIdentifier: _reusableCellIdentifier)
  }

  public override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)

    refreshView()
  }

  public override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)

    // Update the selected colour after the view has appeared (it doesn't work if called from
    // viewWillAppear)
    updateSelectedColour(animated: true)
  }

  public override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
    return 1
  }

  public override func collectionView(
    collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
  {
    return self.colours.count
  }

  public override func collectionView(collectionView: UICollectionView,
    cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
  {
    let cell = collectionView.dequeueReusableCellWithReuseIdentifier(
      _reusableCellIdentifier, forIndexPath: indexPath) as! FieldColourPickerViewCell
    cell.colour = colourForIndexPath(indexPath)
    return cell
  }

  public override func collectionView(
    collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
  {
    if let colour = colourForIndexPath(indexPath) {
      delegate?.fieldColourPickerViewController(self, didPickColour: colour)
    }
  }

  // MARK: - Public

  public func refreshView() {
    // Set the preferred content size when this view controller is displayed in a popover
    let rows = ceil(CGFloat(self.colours.count) / CGFloat(self.preferredColoursPerRow))
    self.preferredContentSize = CGSizeMake(
      CGFloat(self.preferredColoursPerRow) * _flowLayout.itemSize.width,
      CGFloat(rows) * _flowLayout.itemSize.height)

    // Refresh the collection view
    self.collectionView?.reloadData()

    updateSelectedColour(animated: false)
  }

  // MARK: - Private

  private func updateSelectedColour(animated animated: Bool) {
    guard let selectedColour = self.fieldColour?.colour else {
      return
    }

    // Set the selected colour, if it exists in the colour picker
    for i in 0 ..< colours.count {
      if selectedColour == UIColor.bky_colorFromRGB(colours[i]) {
        let indexPath = NSIndexPath(forRow: i, inSection: 0)
        self.collectionView?.selectItemAtIndexPath(
          indexPath, animated: animated, scrollPosition: .CenteredVertically)
        break
      }
    }
  }

  private func colourForIndexPath(indexPath: NSIndexPath) -> UIColor? {
    return UIColor.bky_colorFromRGB(self.colours[indexPath.row])
  }
}

// MARK: - FieldColourPickerViewCell

private class FieldColourPickerViewCell: UICollectionViewCell {
  var colour: UIColor? {
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
    self.backgroundColor = self.colour

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
