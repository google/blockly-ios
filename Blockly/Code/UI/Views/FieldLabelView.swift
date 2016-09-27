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
open class FieldLabelView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldLabelLayout`
  open var fieldLabelLayout: FieldLabelLayout? {
    return layout as? FieldLabelLayout
  }

  /// The label to render
  fileprivate let label: UILabel = {
    let label = UILabel(frame: CGRect.zero)
    label.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    return label
  }()

  // MARK: - Initializers

  /// Initializes the label field view.
  public required init() {
    super.init(frame: CGRect.zero)

    addSubview(label)
  }

  /**
   :nodoc:
   NOTE: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  open override func refreshView(
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
        label.font = UIFont.systemFont(ofSize: 14 * fieldLabelLayout.engine.scale)
      }
    }
  }

  /// :nodoc:
  open override func prepareForReuse() {
    super.prepareForReuse()

    self.frame = CGRect.zero
    self.label.text = ""
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldLabelView: FieldLayoutMeasurer {
  public static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldLabelLayout = layout as? FieldLabelLayout else {
      bky_assertionFailure("`layout` is of type `\(type(of: layout))`. " +
        "Expected type `FieldLabelLayout`.")
      return CGSize.zero
    }

    // TODO:(#27) Use a standardized font size that can be configurable for the project
    return fieldLabelLayout.text.bky_singleLineSize(forFont: UIFont.systemFont(ofSize: 14 * scale))
  }
}
