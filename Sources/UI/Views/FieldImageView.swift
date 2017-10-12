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
 View for rendering a `FieldImageLayout`.
 */
@objc(BKYFieldImageView)
@objcMembers open class FieldImageView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldImageLayout`
  open var fieldImageLayout: FieldImageLayout? {
    return layout as? FieldImageLayout
  }

  /// The image to render
  fileprivate lazy var imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.frame = self.bounds
    imageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
    return imageView
  }()

  // MARK: - Initializers

  /// Initializes the image field view.
  public required init() {
    super.init(frame: CGRect.zero)

    addSubview(imageView)
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  open override func refreshView(
    forFlags flags: LayoutFlag = LayoutFlag.All, animated: Bool = false)
  {
    super.refreshView(forFlags: flags, animated: animated)

    guard let fieldImageLayout = self.fieldImageLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
        fieldImageLayout.loadImage(completion: { (image) in
          self.imageView.image = image
        })

        self.imageView.transform = fieldImageLayout.flipRtl
          ? CGAffineTransform(scaleX: -1, y: 1)
          : CGAffineTransform.identity
      }
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    self.frame = CGRect.zero
    self.imageView.image = nil
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldImageView: FieldLayoutMeasurer {
  public static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldImageLayout = layout as? FieldImageLayout else {
      bky_assertionFailure("`layout` is of type `\(type(of: layout))`. " +
        "Expected type `FieldImageLayout`.")
      return CGSize.zero
    }

    return layout.engine.viewSizeFromWorkspaceSize(fieldImageLayout.size)
  }
}
