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
public class TrashCanView: UIView {

  // MARK: - Struct - Padding
  public struct Padding {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat
    public init(_ top: CGFloat, _ leading: CGFloat, _ bottom: CGFloat, _ trailing: CGFloat) {
      self.top = top
      self.leading = leading
      self.bottom = bottom
      self.trailing = trailing
    }
  }

  /// The trash can button
  public let button = UIButton()
  /// The desired size of the trash can image
  private var _imageSize: CGSize = CGSizeZero
  /// The height constraint of the trash can button
  private var _trashCanHeightConstraint: NSLayoutConstraint!
  /// The width constraint of the trash can button
  private var _trashCanWidthConstraint: NSLayoutConstraint!
  /// Flag indicating whether the trash can should be highlighted
  private var _highlighted: Bool = false

  // MARK: - Initializers

  /**
   Creates the trash can button with an image.

   - Parameter imageName: Loads an image using
   `ImageLoader.loadImage(named: imageName, forClass: self.dynamicType)`.
   - Parameter size: [Optional] The size of the trash can button. If `nil`, the image's size is
   used as a default.
   */
  public required init(imageNamed imageName: String, size: CGSize? = nil) {
    super.init(frame: CGRectZero)

    if let imageSize = size {
      _imageSize = imageSize
    }

    // Load the image
    if let image = ImageLoader.loadImage(named: imageName, forClass: self.dynamicType) {
      self.button.setImage(image, forState: .Normal)
      if size == nil {
        _imageSize = image.size
      }
    }

    // Forces the image to completely fill the button
    self.button.imageView?.contentMode = .ScaleAspectFit
    self.button.contentHorizontalAlignment = .Fill
    self.button.contentVerticalAlignment = .Fill

    // Add the button and its constraints
    let views: [String: UIView] = ["button": button]
    let constraints = [
      "H:|-[button]-|",
      "V:|-[button]-|"
    ]
    bky_addSubviews(Array(views.values))
    bky_addVisualFormatConstraints(constraints, metrics: nil, views: views)

    _trashCanHeightConstraint = self.button.bky_addHeightConstraint(_imageSize.height)
    _trashCanWidthConstraint = self.button.bky_addWidthConstraint(_imageSize.width)
    self.translatesAutoresizingMaskIntoConstraints = false
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Public

  public func setHighlighted(highlighted: Bool, animated: Bool) {
    if _highlighted == highlighted {
      return
    }

    _highlighted = highlighted

    self.bky_updateConstraints(animated: animated, updateConstraints: {
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
