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
 A button for an animatable trash can.
 */
public class TrashCanButton: UIButton {

  private var _desiredSize: CGSize = CGSizeZero
  private var _trashCanHeightConstraint: NSLayoutConstraint!
  private var _trashCanWidthConstraint: NSLayoutConstraint!

  // MARK: - Initializers

  public required init(imageNamed imageName: String, size: CGSize? = nil) {
    super.init(frame: CGRectZero)

    if let desiredSize = size {
      _desiredSize = desiredSize
    }

    // Load image
    if let image = ImageLoader.loadImage(named: imageName, forClass: TrashCanButton.self) {
      self.setImage(image, forState: .Normal)
      if size == nil {
        _desiredSize = image.size
      }
    }

    // Forces the image to completely fill the button
    self.imageView?.contentMode = .ScaleAspectFit
    self.contentHorizontalAlignment = .Fill
    self.contentVerticalAlignment = .Fill

    // Create height/width constraints
    self.translatesAutoresizingMaskIntoConstraints = false
    _trashCanHeightConstraint = NSLayoutConstraint(item: self, attribute: .Height,
      relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1,
      constant: _desiredSize.height)
    _trashCanWidthConstraint = NSLayoutConstraint(item: self, attribute: .Width,
      relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1,
      constant: _desiredSize.width)
    self.addConstraints([_trashCanHeightConstraint, _trashCanWidthConstraint])
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Public

  public func setHighlighted(highlighted: Bool, animated: Bool) {
    if highlighted {
      self._trashCanHeightConstraint.constant = self._desiredSize.height * 2
      self._trashCanWidthConstraint.constant = self._desiredSize.width * 2
      self.layer.opacity = 0.7
    } else {
      self._trashCanHeightConstraint.constant = self._desiredSize.height
      self._trashCanWidthConstraint.constant = self._desiredSize.width
      self.layer.opacity = 1.0
    }

    if animated {
      UIView.animateWithDuration(0.3, delay: 0.0, options: .CurveEaseInOut, animations: {
        self.layoutIfNeeded()
        }, completion: nil)
    } else {
      self.layoutIfNeeded()
    }
  }
}