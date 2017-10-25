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
@objc(BKYToolboxCategoryListViewControllerDelegate)
public protocol ToolboxCategoryListViewControllerDelegate: class {
  /**
  Event that occurs when a category has been selected.
  */
  func toolboxCategoryListViewController(
    _ controller: ToolboxCategoryListViewController, didSelectCategory category: Toolbox.Category)

  /**
  Event that occurs when the category selection has been deselected.
  */
  func toolboxCategoryListViewControllerDidDeselectCategory(
    _ controller: ToolboxCategoryListViewController)
}

// MARK: - ToolboxCategoryListViewController (Class)

/**
 A view for displaying a vertical list of categories from a `Toolbox`.
 */
@objc(BKYToolboxCategoryListViewController)
@objcMembers public final class ToolboxCategoryListViewController: UICollectionViewController {

  // MARK: - Constants

  /// Possible view orientations for the toolbox category list
  @objc(BKYToolboxCategoryListViewControllerOrientation)
  public enum Orientation: Int {
    case
      /// Specifies the toolbox is horizontally-oriented.
      horizontal = 0,
      /// Specifies the toolbox is vertically-oriented.
      vertical
  }

  // MARK: - Properties

  /// The orientation of how the categories should be laid out
  public let orientation: Orientation

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
        let indexPath = indexPath(forCategory: selectedCategory),
        let cell = self.collectionView?.cellForItem(at: indexPath) , !cell.isSelected
      {
        // Select the new value (which automatically deselects the previous value)
        self.collectionView?.selectItem(
          at: indexPath, animated: true, scrollPosition: UICollectionViewScrollPosition())
      } else if selectedCategory == nil,
        let indexPath = indexPath(forCategory: oldValue)
      {
        // No new category was selected. Just de-select the previous value.
        self.collectionView?.deselectItem(at: indexPath, animated: true)
      }
    }
  }

  /// The font to use for the category cell.
  public var categoryFont = UIFont.systemFont(ofSize: 16)

  /// The text color to use for a selected category.
  public var selectedCategoryTextColor: UIColor?

  /// The background color to use for an unselected category.
  public var unselectedCategoryBackgroundColor: UIColor?

  /// The text color to use for an unselected category.
  public var unselectedCategoryTextColor: UIColor?

  /// Delegate for handling category selection events
  public weak var delegate: ToolboxCategoryListViewControllerDelegate?
  /// Stores the last known view bounds size.
  private var _lastTrackedViewBoundsSize = CGSize.zero
  /// Pointer used for distinguishing changes in `view.bounds`
  private var _kvoContextBounds = 0

  // MARK: - Initializers

  /**
   Initializes the toolbox category list view controller.

   - parameter orientation: The `Orientation` for the view.
   */
  public required init(orientation: Orientation) {
    self.orientation = orientation

    let flowLayout = FlowLayout()
    switch orientation {
    case .horizontal:
      flowLayout.scrollDirection = .horizontal
    case .vertical:
      flowLayout.scrollDirection = .vertical
    }

    super.init(collectionViewLayout: flowLayout)
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  deinit {
    if isViewLoaded {
      view.removeObserver(self, forKeyPath: "bounds")
    }
  }

  // MARK: - Super

  open override func viewDidLoad() {
    super.viewDidLoad()

    guard let collectionView = self.collectionView else { return }

    if #available (iOS 11.0, *) {
      // Always auto-adjust for the safe area in the scrollable direction.
      collectionView.contentInsetAdjustmentBehavior = .scrollableAxes
    }

    collectionView.backgroundColor = .clear
    collectionView.register(ToolboxCategoryListViewCell.self,
      forCellWithReuseIdentifier: ToolboxCategoryListViewCell.ReusableCellIdentifier)
    collectionView.showsVerticalScrollIndicator = false
    collectionView.showsHorizontalScrollIndicator = false

    // Automatically constrain this view to a certain size.
    // In iOS 11, size is determined relative to the safe area of the view.
    if orientation == .horizontal {
      if #available(iOS 11.0, *) {
        view.safeAreaLayoutGuide.bottomAnchor.constraint(
          equalTo: collectionView.topAnchor,
          constant: ToolboxCategoryListViewCell.CellHeight).isActive = true
      } else {
        view.bky_addHeightConstraint(ToolboxCategoryListViewCell.CellHeight)
      }
    } else {
      // `ToolboxCategoryListViewCell.CellHeight` is used since in the vertical orientation,
      // cells are rotated by 90 degrees
      if #available(iOS 11.0, *) {
        collectionView.trailingAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.leadingAnchor,
          constant: ToolboxCategoryListViewCell.CellHeight).isActive = true
      } else {
        view.bky_addWidthConstraint(ToolboxCategoryListViewCell.CellHeight)
      }
    }

    // We need to observe whenever the bounds of the collection view changes so we can update the
    // size of the tabs.
    view.addObserver(self, forKeyPath: "bounds", options: .new, context: &_kvoContextBounds)
  }

  open override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey : Any]?,
    context: UnsafeMutableRawPointer?)
  {
    if context == &_kvoContextBounds {
      if (orientation == .vertical && view.bounds.width != _lastTrackedViewBoundsSize.width) ||
        (orientation == .horizontal && view.bounds.height != _lastTrackedViewBoundsSize.height) {
        // The bounds of the view have changed, so the collection view's layout needs to be
        // invalidated. This will force the cells to be re-sized and re-laid out to the new
        // dimensions.
        collectionView?.collectionViewLayout.invalidateLayout()
      }
      _lastTrackedViewBoundsSize = view.bounds.size
    } else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }

  // MARK: - Public

  /**
   Refreshes the UI based on the current version of `self.toolbox`.
   */
  public func refreshView() {
    collectionView?.reloadData()
  }

  // MARK: - UICollectionViewDataSource Methods

  public override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }

  public override func collectionView(
    _ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
      return toolboxLayout?.categoryLayoutCoordinators.count ?? 0
  }

  public override func collectionView(_ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
  {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: ToolboxCategoryListViewCell.ReusableCellIdentifier,
      for: indexPath) as! ToolboxCategoryListViewCell
    cell.nameLabel.font = categoryFont
    cell.selectedTextColor = selectedCategoryTextColor
    cell.unselectedTextColor = unselectedCategoryTextColor
    cell.unselectedBackgroundColor = unselectedCategoryBackgroundColor
    cell.loadCategory(category(forIndexPath: indexPath), orientation: orientation)
    cell.isSelected = (selectedCategory == cell.category)
    return cell
  }

  // MARK: - UICollectionViewDelegate Methods

  public override func collectionView(
    _ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
  {
    let cell = collectionView.cellForItem(at: indexPath) as! ToolboxCategoryListViewCell

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

  fileprivate func indexPath(forCategory category: Toolbox.Category?) -> IndexPath? {
    if toolboxLayout == nil || category == nil {
      return nil
    }

    for i in 0 ..< toolboxLayout!.categoryLayoutCoordinators.count {
      if toolboxLayout!.categoryLayoutCoordinators[i].workspaceLayout.workspace == category {
        return IndexPath(row: i, section: 0)
      }
    }
    return nil
  }

  fileprivate func category(forIndexPath indexPath: IndexPath) -> Toolbox.Category {
    return toolboxLayout!
      .categoryLayoutCoordinators[(indexPath as NSIndexPath).row]
      .workspaceLayout.workspace as! Toolbox.Category
  }

}

extension ToolboxCategoryListViewController: UICollectionViewDelegateFlowLayout {
  // MARK: - UICollectionViewDelegateFlowLayout implementation

  public func collectionView(_ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath) -> CGSize
  {
    let indexedCategory = category(forIndexPath: indexPath)
    let size = ToolboxCategoryListViewCell.descriptionSize(forCategory: indexedCategory,
                                                           font: categoryFont)

    // Flip width/height for the vertical orientation (its contents are actually rotated 90
    // degrees). Note that the width (in vertical orientation) or height (in horizontal
    // orientation) is maximized for the collection view size.
    if orientation == .vertical {
      return CGSize(width: collectionView.bounds.width, height: size.width)
    } else {
      return CGSize(width: size.width, height: collectionView.bounds.height)
    }
  }
}

// MARK: - ToolboxCategoryListViewCell (Class)

/**
 An individual cell category list view cell.
*/
@objc(BKYToolboxCategoryListViewCell)
@objcMembers private class ToolboxCategoryListViewCell: UICollectionViewCell {
  static let ReusableCellIdentifier = "ToolboxCategoryListViewCell"

  static let ColorTagViewHeight = CGFloat(8)
  static let LabelInsets = UIEdgeInsetsMake(4, 8, 4, 8)
  static let CellHeight = CGFloat(48)
  static let IconSize = CGSize(width: 32, height: 32)

  /// The category this cell represents
  var category: Toolbox.Category?

  /// Subview holding all contents of the cell
  let rotationView = UIView()

  /// Label for the category name
  let nameLabel = UILabel()

  /// Image for the category icon
  let iconView: UIImageView = {
    let view = UIImageView()
    view.contentMode = .scaleAspectFit
    return view
  }()

  /// Orientation for the category list.
  var orientation = ToolboxCategoryListViewController.Orientation.horizontal

  /// View representing the category's color
  let colorTagView = UIView()

  var selectedTextColor: UIColor?
  var unselectedBackgroundColor: UIColor?
  var unselectedTextColor: UIColor?

  override var isSelected: Bool {
    didSet {
      backgroundColor = isSelected ? category?.color : unselectedBackgroundColor
      nameLabel.textColor = isSelected ? selectedTextColor : unselectedTextColor
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

  func configureSubviews() {
    self.autoresizesSubviews = true
    self.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    self.translatesAutoresizingMaskIntoConstraints = true

    self.contentView.frame = self.bounds
    self.contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    self.contentView.translatesAutoresizingMaskIntoConstraints = true

    // Create a view specifically dedicated to rotating its contents (rotating the contentView
    // causes problems)
    rotationView.frame =
      CGRect(x: 0, y: 0,
             width: self.contentView.bounds.height, height: self.contentView.bounds.width)
    rotationView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    rotationView.autoresizesSubviews = true
    self.contentView.addSubview(rotationView)

    // Add color tag, category name label, and icon views
    rotationView.addSubview(colorTagView)
    rotationView.addSubview(nameLabel)
    rotationView.addSubview(iconView)

    nameLabel.baselineAdjustment = .alignCenters
    nameLabel.textAlignment = .center

    setNeedsLayout()
  }

  // MARK: - Super

  override func prepareForReuse() {
    rotationView.transform = CGAffineTransform.identity
    nameLabel.text = ""
    iconView.image = nil
    colorTagView.backgroundColor = UIColor.clear
    isSelected = false
  }

  override func layoutSubviews() {
    // NOTE: All subviews of `rotationView` are manually laid out here since using auto-layout
    // constraints does not work when modifying `rotationView.transform` (which is required for
    // rotating the view in vertical mode).

    guard let category = self.category else { return }

    let descriptionSize = ToolboxCategoryListViewCell.descriptionSize(
      forCategory: category, font: nameLabel.font)

    if orientation == .vertical {
      let rtlAdjustment: CGFloat =
        UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? -1 : 1

      // Re-frame the rotation view as if it's rotated.
      rotationView.center = self.contentView.center // We need the rotation to occur in the center
      rotationView.bounds =
        CGRect(x: 0, y: 0, width: contentView.bounds.height, height: contentView.bounds.width)
      // Rotate by -90° (in LTR) or 90° (in RTL) so the category appears vertically
      rotationView.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2.0 * rtlAdjustment)

      // Position color tag at the bottom of the rotation view.
      colorTagView.frame = CGRect(
        x: 0,
        y: rotationView.bounds.height - ToolboxCategoryListViewCell.ColorTagViewHeight,
        width: rotationView.bounds.width,
        height: ToolboxCategoryListViewCell.ColorTagViewHeight)

      // Position name/icon above the color tag.
      nameLabel.frame = CGRect(
        x: 0,
        y: colorTagView.frame.minY - descriptionSize.height,
        width: rotationView.bounds.width,
        height: descriptionSize.height)

      let labelInsets = ToolboxCategoryListViewCell.LabelInsets
      iconView.frame = UIEdgeInsetsInsetRect(nameLabel.frame, labelInsets)

      // We want icons to appear right-side up, so we un-rotate them by 90° (in LTR) or
      // -90° (in RTL)
      iconView.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0 * rtlAdjustment)
    } else {
      rotationView.frame = contentView.bounds

      // Position color tag at the top of the rotation view.
      colorTagView.frame = CGRect(
        x: 0,
        y: 0,
        width: rotationView.bounds.width,
        height: ToolboxCategoryListViewCell.ColorTagViewHeight)

      // Position name/icon below the color tag.
      nameLabel.frame = CGRect(
        x: 0,
        y: colorTagView.frame.maxY,
        width: rotationView.bounds.width,
        height: descriptionSize.height)

      let labelInsets = ToolboxCategoryListViewCell.LabelInsets
      iconView.frame = UIEdgeInsetsInsetRect(nameLabel.frame, labelInsets)
    }
  }

  // MARK: - Private

  func loadCategory(_ category: Toolbox.Category,
    orientation: ToolboxCategoryListViewController.Orientation)
  {
    self.category = category
    self.orientation = orientation

    if let icon = category.icon {
      iconView.image = icon
    } else {
      nameLabel.text = category.name
    }
    colorTagView.backgroundColor = category.color

    setNeedsLayout()
  }

  static func descriptionSize(forCategory category: Toolbox.Category, font: UIFont) -> CGSize {
    var size: CGSize
    if category.icon != nil {
      size = IconSize
    } else {
      size = category.name.bky_singleLineSize(forFont: font)
    }

    // Add padding to the required size
    return CGSize(
      width: size.width + LabelInsets.left + LabelInsets.right,
      height: IconSize.height + LabelInsets.top + LabelInsets.bottom) // Cap the cell height
  }
}

extension ToolboxCategoryListViewController {
  /**
   Custom `UICollectionViewFlowLayout` in order to:
   - force the layout to be invalidated when the collection view's bounds changes
   - flip its fill mode in RTL when the layout is horizontal
   */
  class FlowLayout: UICollectionViewFlowLayout {
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
      return true
    }

    override var flipsHorizontallyInOppositeLayoutDirection: Bool {
      return true
    }
  }
}
