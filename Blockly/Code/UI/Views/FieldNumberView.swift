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
open class FieldNumberView: FieldView {
  // MARK: - Properties

  /// Convenience property accessing `self.layout` as `FieldNumberLayout`
  open var fieldNumberLayout: FieldNumberLayout? {
    return layout as? FieldNumberLayout
  }

  /// The text field to render
  open fileprivate(set) lazy var textField: InsetTextField = {
    let textField = InsetTextField(frame: CGRect.zero)
    textField.delegate = self
    textField.borderStyle = .roundedRect
    textField.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    textField.keyboardType = .numbersAndPunctuation
    textField.textAlignment = .right
    textField.inputAccessoryView = self.toolbar
    textField.adjustsFontSizeToFitWidth = false
    textField
      .addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
    return textField
  }()

  /// A toolbar that appears above the input keyboard
  open fileprivate(set) lazy var toolbar: UIToolbar = {
    let toolbar = UIToolbar()
    toolbar.barStyle = .default
    toolbar.isTranslucent = true
    toolbar.items = [
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
      UIBarButtonItem(barButtonSystemItem: .done, target: self,
        action: #selector(didTapDoneButton(_:)))
    ]
    toolbar.sizeToFit() // This is important or else the bar won't render!
    return toolbar
  }()

  // MARK: - Initializers

  /// Initializes the number field view.
  public required init() {
    super.init(frame: CGRect.zero)

    addSubview(textField)
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

    guard let layout = self.layout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
        self.updateTextFieldFromFieldNumber()

        // TODO:(#27) Standardize this font
        let textField = self.textField
        textField.font = UIFont.systemFont(ofSize: 14 * layout.engine.scale)
        textField.insetPadding =
          layout.config.edgeInsets(for: LayoutConfig.FieldTextFieldInsetPadding)
      }
    }
  }

  /// :nodoc:
  open override func prepareForReuse() {
    super.prepareForReuse()

    self.frame = CGRect.zero
    self.textField.text = ""
  }

  // MARK: - Private

  fileprivate dynamic func didTapDoneButton(_ sender: UITextField) {
    // Stop editing the text field
    textField.resignFirstResponder()
  }

  fileprivate dynamic func textFieldDidChange(_ sender: UITextField) {
    // Remove whitespace
    textField.text = textField.text?.replacingOccurrences(of: " ", with: "")

    // Update the text value of fieldNumberLayout, but don't actually change its value yet
    fieldNumberLayout?.currentTextValue = (textField.text ?? "")
  }

  fileprivate func updateTextFieldFromFieldNumber() {
    let text = fieldNumberLayout?.currentTextValue ?? ""
    if textField.text != text {
      textField.text = text
    }
  }
}

// MARK: - UITextFieldDelegate implementation

extension FieldNumberView: UITextFieldDelegate {
  /// :nodoc:
  public func textField(
    _ textField: UITextField, shouldChangeCharactersIn range: NSRange,
    replacementString string: String) -> Bool
  {
    if string.isEmpty {
      // Always allow deletions
      return true
    } else {
      // Don't allow extra whitespace
      return !string.trimmingCharacters(
        in: CharacterSet.whitespacesAndNewlines).isEmpty
    }
  }

  /// :nodoc:
  public func textFieldDidEndEditing(_ textField: UITextField) {
    // Only commit the change after the user has finished editing the field
    fieldNumberLayout?.setValueFromLocalizedText(self.textField.text ?? "")

    // Update the text field based on the current fieldNumber
    updateTextFieldFromFieldNumber()
  }

  /// :nodoc:
  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    // This will dismiss the keyboard
    textField.resignFirstResponder()
    return true
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldNumberView: FieldLayoutMeasurer {
  public static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldNumberLayout = layout as? FieldNumberLayout else {
      bky_assertionFailure("`layout` is of type `\(type(of: layout))`. " +
        "Expected type `FieldNumberLayout`.")
      return CGSize.zero
    }

    let textPadding = layout.config.edgeInsets(for: LayoutConfig.FieldTextFieldInsetPadding)
    let maxWidth = layout.config.float(for: LayoutConfig.FieldTextFieldMaximumWidth)
    let measureText = fieldNumberLayout.currentTextValue + " "
    // TODO:(#27) Use a standardized font size that can be configurable for the project
    let font = UIFont.systemFont(ofSize: 14 * scale)
    var measureSize = measureText.bky_singleLineSize(forFont: font)
    measureSize.height = measureSize.height + textPadding.top + textPadding.bottom
    measureSize.width =
      min(measureSize.width + textPadding.leading + textPadding.trailing, maxWidth)
    return measureSize
  }
}
