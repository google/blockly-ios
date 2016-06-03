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
 View for rendering a `FieldNumber`.
 */
@objc(BKYFieldNumberView)
public class FieldNumberView: FieldView {
  // MARK: - Properties

  /// The `FieldNumberLayout` backing this view
  public var fieldNumberLayout: FieldNumberLayout? {
    if fieldLayout != nil && !(fieldLayout is FieldNumberLayout) {
      bky_assertionFailure(
        "`fieldLayout` is of type `\(layout.dynamicType)`. Expected type `FieldNumberLayout`.")
    }
    return fieldLayout as? FieldNumberLayout
  }

  /// The text field to render
  public private(set) lazy var textField: InsetTextField = {
    let textField = InsetTextField(frame: CGRectZero)
    textField.delegate = self
    textField.borderStyle = .RoundedRect
    textField.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    textField.keyboardType = .NumbersAndPunctuation
    textField.textAlignment = .Right
    textField.inputAccessoryView = self.toolbar
    textField.adjustsFontSizeToFitWidth = false
    textField
      .addTarget(self, action: #selector(textFieldDidChange(_:)), forControlEvents: .EditingChanged)
    return textField
  }()

  /// A toolbar that appears above the input keyboard
  public private(set) lazy var toolbar: UIToolbar = {
    let toolbar = UIToolbar()
    toolbar.barStyle = .Default
    toolbar.translucent = true
    toolbar.items = [
      UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil),
      UIBarButtonItem(barButtonSystemItem: .Done, target: self,
        action: #selector(didTapDoneButton(_:)))
    ]
    toolbar.sizeToFit() // This is important or else the bar won't render!
    return toolbar
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

    guard let layout = self.fieldLayout where layout.field is FieldNumber else {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      updateTextFieldFromFieldNumber()

      // TODO:(#27) Standardize this font
      textField.font = UIFont.systemFontOfSize(14 * layout.engine.scale)
      textField.insetPadding = layout.config.edgeInsetsFor(LayoutConfig.FieldTextFieldInsetPadding)
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    self.frame = CGRectZero
    self.textField.text = ""
  }

  // MARK: - Private

  private dynamic func didTapDoneButton(sender: UITextField) {
    // Stop editing the text field
    textField.resignFirstResponder()
  }

  private dynamic func textFieldDidChange(sender: UITextField) {
    // Remove whitespace
    textField.text = textField.text?.stringByReplacingOccurrencesOfString(" ", withString: "")

    // Update the text value of fieldNumberLayout, but don't actually change its value yet
    fieldNumberLayout?.currentTextValue = (textField.text ?? "")
  }

  private func updateTextFieldFromFieldNumber() {
    let text = fieldNumberLayout?.currentTextValue ?? ""
    if textField.text != text {
      textField.text = text
    }
  }
}

// MARK: - UITextFieldDelegate implementation

extension FieldNumberView: UITextFieldDelegate {
  public func textField(
    textField: UITextField, shouldChangeCharactersInRange range: NSRange,
    replacementString string: String) -> Bool
  {
    if string.isEmpty {
      // Always allow deletions
      return true
    } else {
      // Don't allow extra whitespace
      return !string.stringByTrimmingCharactersInSet(
        NSCharacterSet.whitespaceAndNewlineCharacterSet()).isEmpty
    }
  }

  public func textFieldDidEndEditing(textField: UITextField) {
    // Only commit the change after the user has finished editing the field
    fieldNumberLayout?.setValueFromLocalizedText(self.textField.text ?? "")

    // Update the text field based on the current fieldNumber
    updateTextFieldFromFieldNumber()
  }

  public func textFieldShouldReturn(textField: UITextField) -> Bool {
    // This will dismiss the keyboard
    textField.resignFirstResponder()
    return true
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldNumberView: FieldLayoutMeasurer {
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldNumberLayout = layout as? FieldNumberLayout else {
      bky_assertionFailure("`layout` is of type `\(layout.dynamicType)`. " +
        "Expected type `FieldNumberLayout`.")
      return CGSizeZero
    }

    let textPadding = layout.config.edgeInsetsFor(LayoutConfig.FieldTextFieldInsetPadding)
    let maxWidth = layout.config.floatFor(LayoutConfig.FieldTextFieldMaximumWidth)
    let measureText = fieldNumberLayout.currentTextValue + " "
    // TODO:(#27) Use a standardized font size that can be configurable for the project
    let font = UIFont.systemFontOfSize(14 * scale)
    var measureSize = measureText.bky_singleLineSizeForFont(font)
    measureSize.height = measureSize.height + textPadding.top + textPadding.bottom
    measureSize.width =
      min(measureSize.width + textPadding.leading + textPadding.trailing, maxWidth)
    return measureSize
  }
}
