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
public final class DropdownView: UIView {
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
  public var dropDownBackgroundColor: CGColor? {
    get { return layer.backgroundColor }
    set(value) { layer.backgroundColor = value }
  }
  /// The horizontal spacing to use for elements within the dropdown
  public var horizontalSpacing = CGFloat(8) {
    didSet { configureSubviews() }
  }
  /// The vertical spacing to use for elements within the dropdown
  public var verticalSpacing = CGFloat(4) {
    didSet { configureSubviews() }
  }
  /// The dropdown border's color
  public var borderColor: CGColor? {
    get { return layer.borderColor }
    set(value) { layer.borderColor = value }
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
    set(value) { _dropDownArrow.image = value }
  }
  /// Delegate for receiving events that occur on this dropdown
  public weak var delegate: DropdownViewDelegate?

  /// The text field to render
  fileprivate let _label = UILabel(frame: CGRect.zero)

  /// The button for receiving taps on this dropdown
  fileprivate lazy var _button: UIButton = {
    let button = UIButton(type: .custom)
    button.addTarget(self, action: #selector(didTapButton(_:)), for: .touchUpInside)
    button.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    return button
  }()

  /// The drop down arrow image beside the text field
  fileprivate let _dropDownArrow: UIImageView = {
    let dropDownArrow = UIImageView(image: nil)
    dropDownArrow.contentMode = .center
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
    borderColor = UIColor.gray.cgColor
    dropDownBackgroundColor = UIColor.white.cgColor

    configureSubviews()
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Public

  /**
   Calculates the required size of a theoretical `DropDownView` instance (`dropDownView`) based on
   if properties were set that instance.

   - parameter text: Corresponds to setting `dropDownView.text`.
   - parameter dropDownArrowImage: Corresponds to setting `dropDownView.dropDownArrowImage`.
   - parameter textFont: Corresponds to setting `dropDownView.labelFont`.
   - parameter borderWidth: Corresponds to setting `dropDownView.borderWidth`.
   - parameter horizontalSpacing: Corresponds to setting `dropDownView.horizontalSpacing`.
   - parameter verticalSpacing: Corresponds to setting `dropDownView.verticalSpacing`.
   - returns: The required size of the theoretical instance `dropDownView`
   */
  public static func measureSize(
    text: String, dropDownArrowImage: UIImage?, textFont: UIFont, borderWidth: CGFloat,
    horizontalSpacing: CGFloat, verticalSpacing: CGFloat) -> CGSize
  {
    // Measure text size
    let textSize = text.bky_singleLineSize(forFont: textFont)

    // Measure drop down arrow image size
    let imageSize = (dropDownArrowImage?.size ?? CGSize.zero)

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
    return ImageLoader.loadImage(named: "arrow_dropdown", forClass: DropdownView.self)
  }

  // MARK: - Private

  private func configureSubviews() {
    let views = [
      "label": _label,
      "dropDownArrow": _dropDownArrow,
      "button": _button,
      ]
    let metrics = [
      "xSpacing": horizontalSpacing,
      "ySpacing": verticalSpacing,
      ]
    let constraints = [
      "H:|-(xSpacing)-[label]-(xSpacing)-[dropDownArrow]-(xSpacing)-|",
      "H:|[button]|",
      "V:|-(ySpacing)-[label]-(ySpacing)-|",
      "V:|[dropDownArrow]|",
      "V:|[button]|",
      ]

    // Re-add all views
    views.forEach({ $1.removeFromSuperview()})
    bky_addSubviews(Array(views.values))
    sendSubview(toBack: _button)

    // Add constraints
    bky_addVisualFormatConstraints(constraints, metrics: metrics, views: views)
  }

  private dynamic func didTapButton(_ sender: UIButton) {
    delegate?.dropDownDidReceiveTap()
  }
}
