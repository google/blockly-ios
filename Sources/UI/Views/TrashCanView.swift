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
 An area containing a button for an animatable trash can.
 */
@objc(BKYTrashCanView)
@objcMembers public final class TrashCanView: UIView {

  // MARK: - Properties

  /// The trash can button
  public let button = UIButton(type: .system)
  /// The desired size of the trash can image
  private var _imageSize: CGSize = CGSize.zero
  /// The height constraint of the trash can button
  private var _trashCanHeightConstraint: NSLayoutConstraint!
  /// The width constraint of the trash can button
  private var _trashCanWidthConstraint: NSLayoutConstraint!
  /// Flag indicating whether the trash can should be highlighted
  private var _highlighted: Bool = false

  // MARK: - Initializers

  /**
   Creates the trash can button with an image.

   - parameter imageName: Loads an image using
   `ImageLoader.loadImage(named: imageName, forClass: self.dynamicType)`.
   - parameter size: [Optional] The size of the trash can button. If `nil`, the image's size is
   used as a default.
   */
  public required init(imageNamed imageName: String, size: CGSize? = nil) {
    super.init(frame: CGRect.zero)

    if let imageSize = size {
      _imageSize = imageSize
    }

    // Load the image
    if let image = ImageLoader.loadImage(named: imageName, forClass: type(of: self)) {
      button.setImage(image, for: UIControlState())
      if size == nil {
        _imageSize = image.size
      }
    }

    // Forces the image to completely fill the button
    button.imageView?.contentMode = .scaleAspectFit
    button.contentHorizontalAlignment = .fill
    button.contentVerticalAlignment = .fill

    // Add the button and its constraints
    let views: [String: UIView] = ["button": button]
    let constraints = [
      "H:|-[button]-|",
      "V:|-[button]-|"
    ]
    bky_addSubviews(Array(views.values))
    bky_addVisualFormatConstraints(constraints, metrics: nil, views: views)

    _trashCanHeightConstraint = button.bky_addHeightConstraint(_imageSize.height)
    _trashCanWidthConstraint = button.bky_addWidthConstraint(_imageSize.width)
    self.translatesAutoresizingMaskIntoConstraints = false
    self.layoutMargins = UIEdgeInsets.zero
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
   Sets the amount of padding that should be added around the trash can button.

   - parameter top: The padding to add to the top edge of the button
   - parameter leading: The padding to add to the leading edge of the button
   - parameter bottom: The padding to add to the bottom edge of the button
   - parameter trailing: The padding to add to the trailing edge of the button
   */
  public func setButtonPadding(
    top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {

    self.layoutMargins = bky_UIEdgeInsetsMake(top, leading, bottom, trailing)
  }

  /**
   Sets the highlighted state for the trash can view.

   - parameter highlighted: Specifies whether the trash can should be highlighted. `true` if it
   should, `false` if not.
   - parameter animated: Specifies whether the change should be animated (`true`) or
   if it should be performed immediately (`false`).
   */
  public func setHighlighted(_ highlighted: Bool, animated: Bool) {
    if _highlighted == highlighted {
      return
    }

    _highlighted = highlighted

    bky_updateConstraints(animated: animated, update: {
      if self._highlighted {
        self._trashCanHeightConstraint.constant = self._imageSize.height * 2
        self._trashCanWidthConstraint.constant = self._imageSize.width * 2
        self.layer.opacity = 0.7
      } else {
        self._trashCanHeightConstraint.constant = self._imageSize.height
        self._trashCanWidthConstraint.constant = self._imageSize.width
        self.layer.opacity = 1.0
      }
    })
  }
}
