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

  // MARK: - Orientation Enum
  public enum Orientation {
    case Horizontal, Vertical
  }

  // MARK: - Properties

  /// The orientation of how the categories should be laid out
  public var orientation: Orientation!

  /// The toolbox layout to display
  public var toolboxLayout: ToolboxLayout?

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

  public required init(orientation: Orientation) {
    self.orientation = orientation

    let flowLayout = UICollectionViewFlowLayout()
    switch orientation {
    case .Horizontal:
      flowLayout.scrollDirection = .Horizontal
    case .Vertical:
      flowLayout.scrollDirection = .Vertical
    }

    super.init(collectionViewLayout: flowLayout)
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
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

    // Automatically constrain this view to a certain size
    if orientation == .Horizontal {
      self.view.bky_addHeightConstraint(ToolboxCategoryListViewCell.CellHeight)
    } else {
      // `ToolboxCategoryListViewCell.CellHeight` is used since in the vertical orientation,
      // cells are rotated by 90 degrees
      self.view.bky_addWidthConstraint(ToolboxCategoryListViewCell.CellHeight)
    }
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
      return toolboxLayout?.categoryLayouts.count ?? 0
  }

  public override func collectionView(collectionView: UICollectionView,
    cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
      let cell = collectionView.dequeueReusableCellWithReuseIdentifier(
        ToolboxCategoryListViewCell.ReusableCellIdentifier,
        forIndexPath: indexPath) as! ToolboxCategoryListViewCell
      cell.loadCategory(categoryForIndexPath(indexPath), orientation: orientation)
      cell.selected = (selectedCategory == cell.category)
      return cell
  }

  // MARK: - UICollectionViewDelegate overrides

  public override func collectionView(
    collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
  {
    let cell = collectionView.cellForItemAtIndexPath(indexPath) as! ToolboxCategoryListViewCell

    if selectedCategory == cell.category {
      // If the category has already been selected, de-select it
      self.selectedCategory = nil
      delegate?.toolboxCategoryListViewControllerDidDeselectCategory(self)
    } else {
      // Select the new category
      self.selectedCategory = cell.category

      if let category = cell.category {
        delegate?.toolboxCategoryListViewController(self, didSelectCategory: category)
      }
    }
  }

  // MARK: - Private

  private func indexPathForCategory(category: Toolbox.Category?) -> NSIndexPath? {
    if toolboxLayout == nil || category == nil {
      return nil
    }

    for i in 0 ..< toolboxLayout!.categoryLayouts.count {
      if toolboxLayout!.categoryLayouts[i].workspace == category {
        return NSIndexPath(forRow: i, inSection: 0)
      }
    }
    return nil
  }

  private func categoryForIndexPath(indexPath: NSIndexPath) -> Toolbox.Category {
    return toolboxLayout!.categoryLayouts[indexPath.row].workspace as! Toolbox.Category
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

    // Flip width/height for the vertical orientation (its contents are actually rotated 90 degrees)
    return (orientation == .Vertical) ? CGSizeMake(size.height, size.width) : size
  }
}

// MARK: - ToolboxCategoryListViewCell (Class)

/**
 An individual cell category list view cell.
*/
private class ToolboxCategoryListViewCell: UICollectionViewCell {
  static let ReusableCellIdentifier = "ToolboxCategoryListViewCell"

  static let ColorTagViewHeight = CGFloat(8)
  static let LabelInsets = UIEdgeInsetsMake(4, 8, 4, 8)
  static let CellHeight = CGFloat(48)
  static let IconSize = CGSizeMake(48, 48)

  /// The category this cell represents
  var category: Toolbox.Category?

  /// Subview holding all contents of the cell
  let rotationView = UIView()

  /// Label for the category name
  let nameLabel: UILabel = {
    let view = UILabel()
    view.font = ToolboxCategoryListViewCell.fontForNameLabel()
    return view
  }()

  /// Image for the category icon
  let iconView: UIImageView = {
    let view = UIImageView()
    view.contentMode = .ScaleAspectFit
    return view
  }()

  /// View representing the category's color
  let colorTagView = UIView()

  override var selected: Bool {
    didSet {
      self.backgroundColor = selected ?
        category?.color.colorWithAlphaComponent(0.6) : UIColor(white: 0.6, alpha: 1.0)
    }
  }

  // MARK: - Initializers

  override init(frame: CGRect) {
    super.init(frame: frame)
    configureSubviews()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configureSubviews()
  }

  // MARK: - Super

  override func prepareForReuse() {
    rotationView.transform = CGAffineTransformIdentity
    nameLabel.text = ""
    iconView.image = nil
    colorTagView.backgroundColor = UIColor.clearColor()
    selected = false
  }

  // MARK: - Private

  func configureSubviews() {
    self.autoresizesSubviews = true
    self.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    self.translatesAutoresizingMaskIntoConstraints = true

    self.contentView.frame = self.bounds
    self.contentView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    self.contentView.translatesAutoresizingMaskIntoConstraints = true

    // Create a view specifically dedicated to rotating its contents (rotating the contentView
    // causes problems)
    rotationView.frame =
      CGRectMake(0, 0, self.contentView.bounds.height, self.contentView.bounds.width)
    rotationView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    rotationView.autoresizesSubviews = true
    self.contentView.addSubview(rotationView)

    // NOTE: The following views weren't created using auto-layout constraints since they don't mix
    // well with `rotationView.transform`, which is required for rotating the view.

    // Create color tag for the top of the view
    colorTagView.frame = CGRectMake(0, 0, rotationView.bounds.width,
                                    ToolboxCategoryListViewCell.ColorTagViewHeight)
    colorTagView.autoresizingMask = [.FlexibleWidth, .FlexibleBottomMargin]
    rotationView.addSubview(colorTagView)

    // Create category name label for the bottom of the view
    let labelInsets = ToolboxCategoryListViewCell.LabelInsets
    nameLabel.frame = CGRectMake(labelInsets.left,
                                 colorTagView.bounds.height + labelInsets.top,
                                 rotationView.bounds.width - labelInsets.left - labelInsets.right,
                                 rotationView.bounds.height - colorTagView.bounds.height
                                  - labelInsets.top - labelInsets.bottom)
    nameLabel.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
    rotationView.addSubview(nameLabel)

    // Create category name label for the bottom of the view
    iconView.frame = nameLabel.frame
    iconView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
    rotationView.addSubview(iconView)
  }

  // MARK: - Private

  func loadCategory(category: Toolbox.Category,
    orientation: ToolboxCategoryListViewController.Orientation)
  {
    self.category = category

    if let icon = category.icon {
      iconView.image = icon
    } else {
      nameLabel.text = category.name
    }
    colorTagView.backgroundColor = category.color

    let size = ToolboxCategoryListViewCell.sizeRequiredForCategory(category)
    rotationView.center = self.contentView.center // We need the rotation to occur in the center
    rotationView.bounds = CGRectMake(0, 0, size.width, size.height)

    if orientation == .Vertical {
      // Rotate so the category appears vertically
      rotationView.transform = CGAffineTransformMakeRotation(-CGFloat(M_PI_2)) // Rotate -90 degrees

      // We want icons to appear right-side up, so we un-rotate them by 90 degrees
      iconView.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
    }
  }

  static func sizeRequiredForCategory(category: Toolbox.Category) -> CGSize {
    let size: CGSize
    if let icon = category.icon {
      size =
        CGSizeMake(max(icon.size.width, IconSize.width), max(icon.size.height, IconSize.height))
    } else {
      size = category.name.bky_singleLineSizeForFont(fontForNameLabel())
    }

    return CGSizeMake(size.width + LabelInsets.left + LabelInsets.right, CellHeight)
  }

  static func fontForNameLabel() -> UIFont {
    return UIFont.systemFontOfSize(16)
  }
}
