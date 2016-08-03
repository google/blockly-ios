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
 View for rendering a `FieldInputLayout`.
 */
@objc(BKYFieldInputView)
public class FieldInputView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.fieldLayout` as a `FieldInputLayout`
  public var fieldInputLayout: FieldInputLayout? {
    return fieldLayout as? FieldInputLayout
  }

  /// The text field to render
  public private(set) lazy var textField: InsetTextField = {
    let textField = InsetTextField(frame: CGRectZero)
    textField.delegate = self
    textField.borderStyle = .RoundedRect
    textField.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    textField
      .addTarget(self, action: #selector(textFieldDidChange(_:)), forControlEvents: .EditingChanged)
    return textField
  }()

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    addSubview(textField)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  public override func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All) {
    super.refreshView(forFlags: flags)

    guard let fieldInputLayout = self.fieldInputLayout else {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      let text = fieldInputLayout.text
      if textField.text != text {
        textField.text = text
      }

      // TODO:(#27) Standardize this font
      textField.font = UIFont.systemFontOfSize(14 * fieldInputLayout.engine.scale)
      textField.insetPadding =
        fieldInputLayout.config.edgeInsetsFor(LayoutConfig.FieldTextFieldInsetPadding)
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    textField.text = ""
  }

  // MARK: - Private

  private dynamic func textFieldDidChange(sender: UITextField) {
    fieldInputLayout?.updateText(textField.text ?? "")
  }
}

// MARK: - UITextFieldDelegate

extension FieldInputView: UITextFieldDelegate {
  public func textFieldShouldReturn(textField: UITextField) -> Bool {
    // This will dismiss the keyboard
    textField.resignFirstResponder()
    return true
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldInputView: FieldLayoutMeasurer {
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldInputLayout = layout as? FieldInputLayout else {
      bky_assertionFailure("`layout` is of type `\(layout.dynamicType)`. " +
        "Expected type `FieldInputLayout`.")
      return CGSizeZero
    }

    let textPadding = layout.config.edgeInsetsFor(LayoutConfig.FieldTextFieldInsetPadding)
    let maxWidth = layout.config.floatFor(LayoutConfig.FieldTextFieldMaximumWidth)
    // TODO:(#27) Use a standardized font size that can be configurable for the project
    let measureText = fieldInputLayout.text + " "
    let font = UIFont.systemFontOfSize(14 * scale)
    var measureSize = measureText.bky_singleLineSizeForFont(font)
    measureSize.height += textPadding.top + textPadding.bottom
    measureSize.width =
      min(measureSize.width + textPadding.leading + textPadding.trailing, maxWidth)
    return measureSize
  }
}
