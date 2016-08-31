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
public class FieldImageView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldImageLayout`
  public var fieldImageLayout: FieldImageLayout? {
    return layout as? FieldImageLayout
  }

  /// The image to render
  private lazy var imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.frame = self.bounds
    imageView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    imageView.contentMode = .ScaleAspectFill
    return imageView
  }()

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    addSubview(imageView)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  public override func refreshView(
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
      }
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    self.frame = CGRectZero
    self.imageView.image = nil
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldImageView: FieldLayoutMeasurer {
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldImageLayout = layout as? FieldImageLayout else {
      bky_assertionFailure("`layout` is of type `\(layout.dynamicType)`. " +
        "Expected type `FieldImageLayout`.")
      return CGSizeZero
    }

    return layout.engine.viewSizeFromWorkspaceSize(fieldImageLayout.size)
  }
}
