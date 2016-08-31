/*
* Copyright 2015 Google Inc. All Rights Reserved.
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
View for rendering a `FieldLabelLayout`.
*/
@objc(BKYFieldLabelView)
public class FieldLabelView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldLabelLayout`
  public var fieldLabelLayout: FieldLabelLayout? {
    return layout as? FieldLabelLayout
  }

  /// The label to render
  private let label: UILabel = {
    let label = UILabel(frame: CGRectZero)
    label.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    return label
  }()

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    addSubview(label)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  public override func refreshView(
    forFlags flags: LayoutFlag = LayoutFlag.All, animated: Bool = false)
  {
    super.refreshView(forFlags: flags, animated: animated)

    guard let fieldLabelLayout = self.fieldLabelLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
        let label = self.label
        label.text = fieldLabelLayout.text
        // TODO:(#27) Standardize this font
        label.font = UIFont.systemFontOfSize(14 * fieldLabelLayout.engine.scale)
      }
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    self.frame = CGRectZero
    self.label.text = ""
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldLabelView: FieldLayoutMeasurer {
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldLabelLayout = layout as? FieldLabelLayout else {
      bky_assertionFailure("`layout` is of type `\(layout.dynamicType)`. " +
        "Expected type `FieldLabelLayout`.")
      return CGSizeZero
    }

    // TODO:(#27) Use a standardized font size that can be configurable for the project
    return fieldLabelLayout.text.bky_singleLineSizeForFont(UIFont.systemFontOfSize(14 * scale))
  }
}
