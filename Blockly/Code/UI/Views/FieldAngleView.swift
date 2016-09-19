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
 View for rendering a `FieldAngleLayout`.
 */
@objc(BKYFieldAngleView)
open class FieldAngleView: FieldView {
  // MARK: - Properties

  /// Convenience property accessing `self.layout` as `FieldAngleLayout`
  fileprivate var fieldAngleLayout: FieldAngleLayout? {
    return layout as? FieldAngleLayout
  }

  /// The text field to render
  open fileprivate(set) lazy var textField: InsetTextField = {
    let textField = InsetTextField(frame: self.bounds)
    textField.delegate = self
    textField.borderStyle = .roundedRect
    textField.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    textField.keyboardType = .numbersAndPunctuation
    textField.textAlignment = .right
    textField.inputAccessoryView = self.toolbar
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

  public required init() {
    super.init(frame: CGRect.zero)

    addSubview(textField)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  open override func refreshView(
    forFlags flags: LayoutFlag = LayoutFlag.All, animated: Bool = false)
  {
    super.refreshView(forFlags: flags, animated: animated)

    guard let fieldAngleLayout = self.fieldAngleLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
        self.updateTextFieldFromLayout()

        // TODO:(#27) Standardize this font
        let textField = self.textField
        textField.text = fieldAngleLayout.textValue
        textField.font = UIFont.systemFont(ofSize: 14 * fieldAngleLayout.engine.scale)
        textField.insetPadding =
          fieldAngleLayout.config.edgeInsetsFor(LayoutConfig.FieldTextFieldInsetPadding)
      }
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    textField.text = ""
  }

  // MARK: - Private

  fileprivate func updateTextFieldFromLayout() {
    let text = fieldAngleLayout?.textValue ?? ""
    if textField.text != text {
      textField.text = text
    }
  }

  fileprivate dynamic func didTapDoneButton(_ sender: UITextField) {
    // Stop editing the text field
    textField.resignFirstResponder()
  }
}

// MARK: - UITextFieldDelegate

extension FieldAngleView: UITextFieldDelegate {
  public func textField(_ textField: UITextField,
    shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
  {
    if string != "" && string != "-" && Int(string) == nil {
      // Don't allow non-integer/"-" characters
      return false
    }
    return true
  }

  public func textFieldDidBeginEditing(_ textField: UITextField) {
    // Temporarily remove any non-number characters from the text
    let invalidCharacters = CharacterSet.decimalDigits.inverted
    textField.text = textField.text?.bky_removingOccurrences(ofCharacterSet: invalidCharacters)
  }

  public func textFieldDidEndEditing(_ textField: UITextField) {
    // Only commit the change after the user has finished editing the field
    fieldAngleLayout?.updateAngle(fromText: (textField.text ?? ""))

    // Update the text from the layout
    updateTextFieldFromLayout()
  }

  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    // This will dismiss the keyboard
    textField.resignFirstResponder()
    return true
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldAngleView: FieldLayoutMeasurer {
  public static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize {
    if !(layout is FieldAngleLayout) {
      bky_assertionFailure("`layout` is of type `\(type(of: layout))`. " +
        "Expected type `FieldAngleLayout`.")
      return CGSize.zero
    }

    let textPadding = layout.config.edgeInsetsFor(LayoutConfig.FieldTextFieldInsetPadding)
    let maxWidth = layout.config.floatFor(LayoutConfig.FieldTextFieldMaximumWidth)
    // TODO:(#27) Use a standardized font size that can be configurable for the project
    // Use a size that can accomodate 3 digits and °.
    let measureText = "000°"
    let font = UIFont.systemFont(ofSize: 14 * scale)
    var measureSize = measureText.bky_singleLineSizeForFont(font)
    measureSize.height += textPadding.top + textPadding.bottom
    measureSize.width =
      min(measureSize.width + textPadding.leading + textPadding.trailing, maxWidth)
    return measureSize
  }
}
