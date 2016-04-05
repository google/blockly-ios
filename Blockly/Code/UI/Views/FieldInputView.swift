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
  // MARK: - Static Properties

  /// The maximum width that each instance can grow to, expressed as a UIView coordinate system unit
  public static var maximumTextFieldWidth = CGFloat(300)

  /**
   When measuring the size required to render this view's input text, this is the amount to pad
   to that calculated value (to account for the text decoration applied by the system when it draws
   the `.RoundedRect` borderStyle of the text field).
   */
  public static var textFieldPadding = CGSizeMake(14, 6)

  // MARK: - Properties

  /// The `FieldInput` backing this view
  public var fieldInput: FieldInput? {
    return fieldLayout?.field as? FieldInput
  }

  /// The text field to render
  private var textField: UITextField!

  // MARK: - Initializers

  public required init() {
    self.textField = UITextField(frame: CGRectZero)
    super.init(frame: CGRectZero)

    textField.delegate = self
    textField.borderStyle = .RoundedRect
    textField.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    textField.addTarget(self, action: "textFieldDidChange:", forControlEvents: .EditingChanged)
    addSubview(textField)
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func internalRefreshView(forFlags flags: LayoutFlag)
  {
    guard let layout = self.fieldLayout,
      let fieldInput = self.fieldInput else
    {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      if self.textField.text != fieldInput.text {
        self.textField.text = fieldInput.text
      }

      // TODO:(#27) Standardize this font
      self.textField.font = UIFont.systemFontOfSize(14 * layout.engine.scale)
    }
  }

  public override func internalPrepareForReuse() {
    self.frame = CGRectZero
    self.textField.text = ""
  }

  // MARK: - Private

  private dynamic func textFieldDidChange(sender: UITextField) {
    self.fieldInput?.text = self.textField.text ?? ""
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
    guard let fieldInput = layout.field as? FieldInput else {
      bky_assertionFailure("`layout.field` is of type `(layout.field.dynamicType)`. " +
        "Expected type `FieldInput`.")
      return CGSizeZero
    }

    // TODO:(#27) Use a standardized font size that can be configurable for the project
    let measureText = fieldInput.text + "   "
    let font = UIFont.systemFontOfSize(14 * scale)
    var measureSize = measureText.bky_singleLineSizeForFont(font)
    measureSize.height = measureSize.height + textFieldPadding.height
    measureSize.width =
      min(measureSize.width, FieldInputView.maximumTextFieldWidth) + textFieldPadding.width
    return measureSize
  }
}
