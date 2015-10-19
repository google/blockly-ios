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
public class FieldLabelView: LayoutView {
  // MARK: - Properties

  /// Layout object to render
  public var fieldLabelLayout: FieldLabelLayout? {
    return layout as? FieldLabelLayout
  }

  /// The label to render
  private var label: UILabel!

  // MARK: - Initializers

  public required init() {
    self.label = UILabel(frame: CGRectZero)
    super.init(frame: CGRectZero)

    label.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    self.autoresizesSubviews = true
    addSubview(label)
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func internalRefreshView() {
    guard let layout = self.layout as? FieldLabelLayout else {
      return
    }

    self.label.text = layout.fieldLabel.text

    // TODO:(vicng) This is only for debugging. Remove this once block rendering is in a "good"
    // state.
    self.backgroundColor = UIColor.redColor()

    // TODO:(vicng) Standardize this font
    self.label.font = UIFont.systemFontOfSize(14 * layout.workspaceLayout.scale)
  }

  public override func internalPrepareForReuse() {
    self.frame = CGRectZero
    self.label.text = ""
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldLabelView: FieldLayoutMeasurer {
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldLayout = layout as? FieldLabelLayout else {
      bky_assertionFailure("Cannot measure layout of type [\(layout.dynamicType.description)]. " +
        "Expected type [FieldLabelLayout].")
      return CGSizeZero
    }
    // TODO:(vicng) Return different values based on the scale
    // TODO:(vicng) Use a standardized font size that can be configurable for the project
    return fieldLayout.fieldLabel.text.bky_singleLineSizeForFont(
      UIFont.systemFontOfSize(14 * scale))
  }
}
