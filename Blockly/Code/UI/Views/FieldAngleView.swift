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

  /// The `FieldAngle` backing this view
  public var fieldAngle: FieldAngle? {
    return fieldLayout?.field as? FieldAngle
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

    guard let layout = self.fieldLayout where layout.field is FieldAngle else {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      updateTextFieldFromFieldAngle()

      // TODO:(#27) Standardize this font
      textField.font = UIFont.systemFontOfSize(14 * layout.engine.scale)
      textField.insetPadding = layout.config.edgeInsetFor(LayoutConfig.FieldTextFieldInsetPadding)
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    textField.text = ""
  }

  // MARK: - Private

  private dynamic func didTapDoneButton(sender: UITextField) {
    // Stop editing the text field
    textField.resignFirstResponder()
  }

  private func updateTextFieldFromFieldAngle() {
    textField.text = String(fieldAngle?.angle ?? 0) + "°"
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
    // Temporarily remove the "°" from the text
    textField.text = textField.text?.stringByReplacingOccurrencesOfString("°", withString: "")
  }

  public func textFieldDidEndEditing(textField: UITextField) {
    // Only commit the change after the user has finished editing the field
    if let newAngle = Int(textField.text ?? "") { // Only update it if it's a valid value
      fieldAngle?.angle = newAngle
    }
    updateTextFieldFromFieldAngle()
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
    if !(layout.field is FieldAngle) {
      bky_assertionFailure("`layout.field` is of type `(layout.field.dynamicType)`. " +
        "Expected type `FieldAngle`.")
      return CGSizeZero
    }

    let textPadding = layout.config.edgeInsetFor(LayoutConfig.FieldTextFieldInsetPadding)
    let maxWidth = layout.config.floatFor(LayoutConfig.FieldTextFieldMaximumWidth)
    // TODO:(#27) Use a standardized font size that can be configurable for the project
    // Use a size that can accomodate 3 digits and °.
    let measureText = "000°"
    let font = UIFont.systemFontOfSize(14 * scale)
    var measureSize = measureText.bky_singleLineSizeForFont(font)
    measureSize.height += textPadding.top + textPadding.bottom
    measureSize.width = min(measureSize.width + textPadding.left + textPadding.right, maxWidth)
    return measureSize
  }
}
