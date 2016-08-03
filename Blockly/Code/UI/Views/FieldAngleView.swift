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
public class FieldAngleView: FieldView {
  // MARK: - Properties

  /// Convenience property accessing `self.layout` as `FieldAngleLayout`
  private var fieldAngleLayout: FieldAngleLayout? {
    return layout as? FieldAngleLayout
  }

  /// The text field to render
  public private(set) lazy var textField: InsetTextField = {
    let textField = InsetTextField(frame: self.bounds)
    textField.delegate = self
    textField.borderStyle = .RoundedRect
    textField.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    textField.keyboardType = .NumbersAndPunctuation
    textField.textAlignment = .Right
    textField.inputAccessoryView = self.toolbar
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

    guard let fieldAngleLayout = self.fieldAngleLayout else {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      updateTextFieldFromLayout()

      // TODO:(#27) Standardize this font
      textField.text = fieldAngleLayout.textValue
      textField.font = UIFont.systemFontOfSize(14 * fieldAngleLayout.engine.scale)
      textField.insetPadding =
        fieldAngleLayout.config.edgeInsetsFor(LayoutConfig.FieldTextFieldInsetPadding)
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    textField.text = ""
  }

  // MARK: - Private

  private func updateTextFieldFromLayout() {
    let text = fieldAngleLayout?.textValue ?? ""
    if textField.text != text {
      textField.text = text
    }
  }

  private dynamic func didTapDoneButton(sender: UITextField) {
    // Stop editing the text field
    textField.resignFirstResponder()
  }
}

// MARK: - UITextFieldDelegate

extension FieldAngleView: UITextFieldDelegate {
  public func textField(textField: UITextField,
    shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool
  {
    if string != "" && string != "-" && Int(string) == nil {
      // Don't allow non-integer/"-" characters
      return false
    }
    return true
  }

  public func textFieldDidBeginEditing(textField: UITextField) {
    // Temporarily remove any non-number characters from the text
    let invalidCharacters = NSCharacterSet.decimalDigitCharacterSet().invertedSet
    textField.text = textField.text?.bky_removingOccurrences(ofCharacterSet: invalidCharacters)
  }

  public func textFieldDidEndEditing(textField: UITextField) {
    // Only commit the change after the user has finished editing the field
    fieldAngleLayout?.updateAngle(fromText: (textField.text ?? ""))

    // Update the text from the layout
    updateTextFieldFromLayout()
  }

  public func textFieldShouldReturn(textField: UITextField) -> Bool {
    // This will dismiss the keyboard
    textField.resignFirstResponder()
    return true
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldAngleView: FieldLayoutMeasurer {
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    if !(layout is FieldAngleLayout) {
      bky_assertionFailure("`layout` is of type `\(layout.dynamicType)`. " +
        "Expected type `FieldAngleLayout`.")
      return CGSizeZero
    }

    let textPadding = layout.config.edgeInsetsFor(LayoutConfig.FieldTextFieldInsetPadding)
    let maxWidth = layout.config.floatFor(LayoutConfig.FieldTextFieldMaximumWidth)
    // TODO:(#27) Use a standardized font size that can be configurable for the project
    // Use a size that can accomodate 3 digits and °.
    let measureText = "000°"
    let font = UIFont.systemFontOfSize(14 * scale)
    var measureSize = measureText.bky_singleLineSizeForFont(font)
    measureSize.height += textPadding.top + textPadding.bottom
    measureSize.width =
      min(measureSize.width + textPadding.leading + textPadding.trailing, maxWidth)
    return measureSize
  }
}
