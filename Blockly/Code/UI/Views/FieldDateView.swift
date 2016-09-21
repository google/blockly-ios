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

// TODO:(#25) Change this view so it is a button that opens a date picker in a popover
/**
 View for rendering a `FieldDateLayout`.
 */
@objc(BKYFieldDateView)
open class FieldDateView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldDateLayout`
  open var fieldDateLayout: FieldDateLayout? {
    return layout as? FieldDateLayout
  }

  /// The text field to render the date
  open fileprivate(set) lazy var textField: InsetTextField = {
    let textField = InsetTextField(frame: self.bounds)
    textField.delegate = self
    textField.borderStyle = .roundedRect
    textField.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    textField.inputView = self.datePicker
    textField.inputAccessoryView = self.datePickerToolbar
    textField.textAlignment = .center
    return textField
  }()

  /// The picker for choosing a date
  open fileprivate(set) lazy var datePicker: UIDatePicker = {
    let datePicker = UIDatePicker()
    datePicker.datePickerMode = .date
    datePicker.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    datePicker
      .addTarget(self, action: #selector(datePickerDidChange(_:)), for: .valueChanged)
    return datePicker
  }()

  /// The toolbar that appears above the date picker
  fileprivate fileprivate(set) lazy var datePickerToolbar: UIToolbar = {
    let datePickerToolbar = UIToolbar()
    datePickerToolbar.barStyle = .default
    datePickerToolbar.isTranslucent = true
    datePickerToolbar.items = [
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
      UIBarButtonItem(barButtonSystemItem: .done, target: self,
        action: #selector(didTapDoneButton(_:)))
    ]
    datePickerToolbar.sizeToFit() // This is important or else the bar won't render!
    return datePickerToolbar
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

    guard let fieldDateLayout = self.fieldDateLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
        let textField = self.textField
        textField.text = fieldDateLayout.textValue

        // TODO:(#27) Standardize this font
        textField.font = UIFont.systemFont(ofSize: 14 * fieldDateLayout.engine.scale)
        textField.insetPadding =
          fieldDateLayout.config.edgeInsets(for: LayoutConfig.FieldTextFieldInsetPadding)
      }
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    textField.text = ""
  }

  // MARK: - Private

  fileprivate dynamic func didTapDoneButton(_ sender: UITextField) {
    updateDateFromDatePicker()

    // Stop editing the text field
    textField.resignFirstResponder()
  }

  fileprivate dynamic func datePickerDidChange(_ sender: UIDatePicker) {
    // Immediately update the date when the date picker changes
    updateDateFromDatePicker()
  }

  fileprivate func updateDateFromDatePicker() {
    fieldDateLayout?.updateDate(datePicker.date)
  }
}

// MARK: - UITextFieldDelegate

extension FieldDateView: UITextFieldDelegate {
  public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
    replacementString string: String) -> Bool
  {
    // Disable direct editing of the text field
    return false
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldDateView: FieldLayoutMeasurer {
  public static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldDateLayout = layout as? FieldDateLayout else {
      bky_assertionFailure("`layout` is of type `\(type(of: layout))`. " +
        "Expected type `FieldDateLayout`.")
      return CGSize.zero
    }

    let textPadding = layout.config.edgeInsets(for: LayoutConfig.FieldTextFieldInsetPadding)
    let text = fieldDateLayout.textValue
    // TODO:(#27) Use a standardized font size that can be configurable for the project
    var measureSize = text.bky_singleLineSize(forFont: UIFont.systemFont(ofSize: 14 * scale))
    measureSize.height += textPadding.top + textPadding.bottom
    measureSize.width += textPadding.leading + textPadding.trailing
    return measureSize
  }
}
