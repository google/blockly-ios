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
 Delegate for events that occur on `DropdownView`.
 */
@objc(BKYDropdownViewDelegate)
public protocol DropdownViewDelegate: class {
  /**
   Event that is called when the user has tapped on the dropdown.
   */
  func dropDownDidReceiveTap()
}

/**
 A view that resembles a dropdown. It contains a text field with a dropdown arrow image.

 e.g.

 ```
  =========

 | ITEM  ▼ |

  =========
 ```
 */
@objc(BKYDropdownView)
@objcMembers public final class DropdownView: UIView {
  // MARK: - Properties

  /// The current text of the dropdown
  public var text: String? {
    get { return _label.text }
    set(value) { _label.text = value }
  }
  /// The font for the dropdown text
  public var textFont: UIFont? {
    get { return _label.font }
    set(value) { _label.font = value }
  }
  /// The color for the dropdown text
  public var textColor: UIColor? {
    get { return _label.textColor }
    set(value) { _label.textColor = value }
  }
  /// The background color of the area inside the dropdown
  public var dropDownBackgroundColor: UIColor? {
    didSet { layer.backgroundColor = dropDownBackgroundColor?.cgColor }
  }
  /// The horizontal spacing to use for elements within the dropdown
  public var horizontalSpacing = CGFloat(6) {
    didSet {
      if horizontalSpacing != oldValue {
        setNeedsLayout()
      }
    }
  }
  /// The vertical spacing to use for elements within the dropdown
  public var verticalSpacing = CGFloat(2) {
    didSet {
      if verticalSpacing != oldValue {
        setNeedsLayout()
      }
    }
  }
  /// The dropdown border's color
  public var borderColor: UIColor? {
    didSet(value) { layer.borderColor = borderColor?.cgColor }
  }
  /// The dropdown border's width
  public var borderWidth: CGFloat {
    get { return layer.borderWidth }
    set(value) { layer.borderWidth = value }
  }
  /// The dropdown border's corner radius
  public var borderCornerRadius: CGFloat {
    get { return layer.cornerRadius }
    set(value) { layer.cornerRadius = value }
  }
  /// The image to use for the drop down view
  public var dropDownArrowImage: UIImage? {
    get { return _dropDownArrow.image }
    set(value) {
      _dropDownArrow.image = value
      _dropDownArrow.sizeToFit()
    }
  }
  /// An optional size to use for the drop down arrow view
  public var dropDownArrowImageSize: CGSize? {
    didSet {
      if dropDownArrowImageSize != oldValue {
        setNeedsLayout()
      }
    }
  }
  /// The tint color to use for the drop down arrow.
  public var dropDownArrowTintColor: UIColor! {
    get { return _dropDownArrow.tintColor }
    set(value) { _dropDownArrow.tintColor = value }
  }
  /// Delegate for receiving events that occur on this dropdown
  public weak var delegate: DropdownViewDelegate?

  /// The text field to render
  fileprivate let _label = UILabel(frame: CGRect.zero)

  /// The button for receiving taps on this dropdown
  fileprivate lazy var _button: UIButton = {
    let button = UIButton(type: .custom)
    button.addTarget(self, action: #selector(didTapButton(_:)), for: .touchUpInside)
    return button
  }()

  /// The drop down arrow image beside the text field
  fileprivate let _dropDownArrow: UIImageView = {
    let dropDownArrow = UIImageView(image: nil)
    dropDownArrow.contentMode = .scaleAspectFit
    return dropDownArrow
  }()

  // MARK: - Initializers

  /**
   Initializer with an optional drop down arrow image.

   - parameter dropDownArrowImage: [Optional] If specified, this image is used to populate
   `self.dropDownArrowImage`. If nil, `DropDownView.defaultDropDownArrowImage()` is used instead.
   */
  public init(dropDownArrowImage: UIImage? = nil) {
    super.init(frame: CGRect.zero)

    self.dropDownArrowImage = dropDownArrowImage ?? DropdownView.defaultDropDownArrowImage()

    addSubview(_button)
    addSubview(_dropDownArrow)
    addSubview(_label)
    sendSubview(toBack: _button)
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  public override func layoutSubviews() {
    super.layoutSubviews()

    let xMargin = horizontalSpacing + borderWidth
    let dropDownArrowImageSize =
      self.dropDownArrowImageSize ?? dropDownArrowImage?.size ?? CGSize.zero

    _button.frame = bounds

    _dropDownArrow.frame = CGRect(
      x: bounds.width - dropDownArrowImageSize.width - xMargin,
      y: (bounds.height - dropDownArrowImageSize.height) / 2,
      width: dropDownArrowImageSize.width,
      height: dropDownArrowImageSize.height)

    _label.sizeToFit()
    _label.frame.origin = CGPoint(x: xMargin, y: (bounds.height - _label.bounds.height) / 2)
  }

  // MARK: - Public

  /**
   Calculates the required size of a theoretical `DropDownView` instance (`dropDownView`) based on
   if properties were set that instance.

   - parameter text: Corresponds to setting `dropDownView.text`.
   - parameter dropDownArrowImageSize: Corresponds to setting `dropDownView.dropDownArrowImageSize`.
   - parameter textFont: Corresponds to setting `dropDownView.labelFont`.
   - parameter borderWidth: Corresponds to setting `dropDownView.borderWidth`.
   - parameter horizontalSpacing: Corresponds to setting `dropDownView.horizontalSpacing`.
   - parameter verticalSpacing: Corresponds to setting `dropDownView.verticalSpacing`.
   - returns: The required size of the theoretical instance `dropDownView`
   */
  public static func measureSize(
    text: String, dropDownArrowImageSize: CGSize, textFont: UIFont, borderWidth: CGFloat,
         horizontalSpacing: CGFloat, verticalSpacing: CGFloat) -> CGSize
  {
    // Measure text size
    let textSize = text.bky_singleLineSize(forFont: textFont)

    // Measure drop down arrow image size
    let imageSize = dropDownArrowImageSize

    // Return size required
    return CGSize(
      width: ceil(textSize.width + horizontalSpacing * 3 + imageSize.width + borderWidth * 2),
      height: ceil(max(textSize.height + verticalSpacing * 2, imageSize.height) + borderWidth * 2))
  }

  /**
   Returns the default drop down arrow image for the dropdown view.

   - returns: The `UIImage` containing the default drop down arrow.
   */
  public static func defaultDropDownArrowImage() -> UIImage? {
    return ImageLoader.loadImage(named: "arrow_dropdown", forClass: DropdownView.self)?
      .withRenderingMode(.alwaysTemplate) // This allows us to tint the image.
  }

  /**
   Returns the size to use for the default drop down arrow image.

   - returns: A `CGSize`.
   */
  public static func defaultDropDownArrowImageSize() -> CGSize {
    return CGSize(width: 10, height: 5)
  }

  // MARK: - Private

  @objc private dynamic func didTapButton(_ sender: UIButton) {
    delegate?.dropDownDidReceiveTap()
  }
}
