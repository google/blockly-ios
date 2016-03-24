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

// MARK: - ToolboxCategoryListViewControllerDelegate (Protocol)

/**
 Handler for events that occur on `ToolboxCategoryListViewController`.
 */
public protocol ToolboxCategoryListViewControllerDelegate: class {
  /**
  Event that occurs when a category has been selected.
  */
  func toolboxCategoryListViewController(
    controller: ToolboxCategoryListViewController, didSelectCategory category: Toolbox.Category)

  /**
  Event that occurs when the category selection has been deselected.
  */
  func toolboxCategoryListViewControllerDidDeselectCategory(
    controller: ToolboxCategoryListViewController)
}

// MARK: - ToolboxCategoryListViewController (Class)

/**
 A view for displaying a vertical list of categories from a `Toolbox`.
 */
public class ToolboxCategoryListViewController: UICollectionViewController {

  // MARK: - Properties

  /// The toolbox to display
  public var toolbox: Toolbox?

  /// The category that the user has currently selected
  public var selectedCategory: Toolbox.Category? {
    didSet {
      if selectedCategory == oldValue {
        return
      }

      // Update the UI to match the new selected category.

      if selectedCategory != nil,
        let indexPath = indexPathForCategory(selectedCategory),
        let cell = self.collectionView?.cellForItemAtIndexPath(indexPath) where !cell.selected
      {
        // Select the new value (which automatically deselects the previous value)
        self.collectionView?.selectItemAtIndexPath(
          indexPath, animated: true, scrollPosition: UICollectionViewScrollPosition.None)
      } else if selectedCategory == nil,
        let indexPath = indexPathForCategory(oldValue)
      {
        // No new category was selected. Just de-select the previous value.
        self.collectionView?.deselectItemAtIndexPath(indexPath, animated: true)
      }
    }
  }

  /// Delegate for handling category selection events
  public weak var delegate: ToolboxCategoryListViewControllerDelegate?

  // MARK: - Initializers

  public required init() {
    let flowLayout = UICollectionViewFlowLayout()
    flowLayout.scrollDirection = .Vertical
    super.init(collectionViewLayout: flowLayout)
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func viewDidLoad() {
    super.viewDidLoad()

    guard let collectionView = self.collectionView else {
      bky_print("`self.collectionView` is nil. Did you forget to set it?")
      return
    }

    collectionView.backgroundColor = UIColor.whiteColor()
    collectionView.registerClass(ToolboxCategoryListViewCell.self,
      forCellWithReuseIdentifier: ToolboxCategoryListViewCell.ReusableCellIdentifier)
    collectionView.showsVerticalScrollIndicator = false
    collectionView.showsHorizontalScrollIndicator = false
  }

  // MARK: - Public

  /**
   Refreshes the UI based on the current version of `self.toolbox`.
   */
  public func refreshView() {
    self.collectionView?.reloadData()
  }

  // MARK: - UICollectionViewDataSource overrides

  public override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
    return 1
  }

  public override func collectionView(
    collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
      return toolbox?.categoryLayouts.count ?? 0
  }

  public override func collectionView(collectionView: UICollectionView,
    cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
      let cell = collectionView.dequeueReusableCellWithReuseIdentifier(
        ToolboxCategoryListViewCell.ReusableCellIdentifier,
        forIndexPath: indexPath) as! ToolboxCategoryListViewCell
      cell.loadCategory(categoryForIndexPath(indexPath))
      cell.selected = (self.selectedCategory == cell.category)
      return cell
  }

  // MARK: - UICollectionViewDelegate overrides

  public override func collectionView(
    collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
  {
    let cell = collectionView.cellForItemAtIndexPath(indexPath) as! ToolboxCategoryListViewCell

    if self.selectedCategory == cell.category {
      // If the category has already been selected, de-select it
      self.selectedCategory = nil
      delegate?.toolboxCategoryListViewControllerDidDeselectCategory(self)
    } else {
      // Select the new category
      self.selectedCategory = cell.category
      delegate?.toolboxCategoryListViewController(self, didSelectCategory: cell.category)
    }
  }

  // MARK: - Private

  private func indexPathForCategory(category: Toolbox.Category?) -> NSIndexPath? {
    if toolbox == nil || category == nil {
      return nil
    }

    for i in 0 ..< toolbox!.categoryLayouts.count {
      if toolbox!.categoryLayouts[i].workspace == category {
        return NSIndexPath(forRow: i, inSection: 0)
      }
    }
    return nil
  }

  private func categoryForIndexPath(indexPath: NSIndexPath) -> Toolbox.Category {
    return toolbox!.categoryLayouts[indexPath.row].workspace as! Toolbox.Category
  }
}

extension ToolboxCategoryListViewController: UICollectionViewDelegateFlowLayout {
  // MARK: - UICollectionViewDelegateFlowLayout implementation

  public func collectionView(collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
  {
    let category = categoryForIndexPath(indexPath)
    let size = ToolboxCategoryListViewCell.sizeRequiredForCategory(category)

    // Flip width/height (its contents are actually rotated 90 degrees)
    return CGSizeMake(size.height, size.width)
  }
}

// MARK: - ToolboxCategoryListViewCell (Class)

/**
 An individual cell category list view cell.
*/
private class ToolboxCategoryListViewCell: UICollectionViewCell {
  static let ReusableCellIdentifier = "ToolboxCategoryListViewCell"

  static let ColorTagViewHeight = CGFloat(5)
  static let LabelPadding = CGFloat(5)

  var category: Toolbox.Category!
  var rotationView: UIView!
  var nameLabel: UILabel!
  var colorTagView: UIView!

  override var selected: Bool {
    didSet {
      self.backgroundColor = self.selected ?
        self.category.colour.colorWithAlphaComponent(0.6) : UIColor(white: 0.6, alpha: 1.0)
    }
  }

  // MARK: - Initializers

  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  func commonInit() {
    self.autoresizesSubviews = true
    self.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    self.translatesAutoresizingMaskIntoConstraints = true

    self.contentView.frame = self.bounds
    self.contentView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    self.contentView.translatesAutoresizingMaskIntoConstraints = true

    // Create a view specifically dedicated to rotating its contents (rotating the contentView
    // causes problems)
    rotationView = UIView()
    rotationView.frame =
      CGRectMake(0, 0, self.contentView.bounds.size.height, self.contentView.bounds.size.width)
    rotationView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    rotationView.autoresizesSubviews = true
    self.contentView.addSubview(rotationView)

    // NOTE: The following views weren't created using auto-layout constraints since they don't mix
    // well with `rotationView.transform`, which is required for rotating the view.

    // Create color tag for the top of the view
    colorTagView = UIView()
    colorTagView.frame = CGRectMake(0, 0, rotationView.bounds.size.width,
        ToolboxCategoryListViewCell.ColorTagViewHeight)
    colorTagView.autoresizingMask = [.FlexibleWidth, .FlexibleBottomMargin]
    rotationView.addSubview(colorTagView)

    // Create category name label for the bottom of the view
    let labelPadding = ToolboxCategoryListViewCell.LabelPadding
    nameLabel = UILabel()
    nameLabel.frame = CGRectMake(labelPadding, colorTagView.bounds.size.height + labelPadding,
      rotationView.bounds.size.width - labelPadding * 2,
      rotationView.bounds.size.height - colorTagView.bounds.size.height - labelPadding * 2)
    nameLabel.autoresizingMask = [.FlexibleWidth]
    nameLabel.font = ToolboxCategoryListViewCell.fontForNameLabel()
    rotationView.addSubview(nameLabel)
  }

  // MARK: - Super

  override func prepareForReuse() {
    rotationView.transform = CGAffineTransformIdentity
    nameLabel.text = ""
    colorTagView.backgroundColor = UIColor.clearColor()
    self.selected = false
  }

  // MARK: - Private

  func loadCategory(category: Toolbox.Category) {
    self.category = category

    let size = ToolboxCategoryListViewCell.sizeRequiredForCategory(category)

    nameLabel.text = category.name
    colorTagView.backgroundColor = category.colour

    // Rotate so the category appears vertically
    rotationView.center = self.contentView.center // We need the rotation to occur in the center
    rotationView.bounds = CGRectMake(0, 0, size.width, size.height)
    rotationView.transform = CGAffineTransformMakeRotation(-CGFloat(M_PI_2)) // Rotate -90 degrees
  }

  static func sizeRequiredForCategory(category: Toolbox.Category) -> CGSize {
    let nameSize = category.name.bky_singleLineSizeForFont(fontForNameLabel())

    let totalSize = CGSizeMake(
      nameSize.width + (self.LabelPadding * 2),
      self.ColorTagViewHeight + nameSize.height + (self.LabelPadding * 2))

    return totalSize
  }

  static func fontForNameLabel() -> UIFont {
    return UIFont.systemFontOfSize(16)
  }
}
