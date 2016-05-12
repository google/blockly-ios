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
public class FieldDateView: FieldView {
  // MARK: - Properties

  /// The `FieldDate` backing this view
  public var fieldDate: FieldDate? {
    return fieldLayout?.field as? FieldDate
  }

  /// The text field to render the date
  public private(set) lazy var textField: InsetTextField = {
    let textField = InsetTextField(frame: self.bounds)
    textField.delegate = self
    textField.borderStyle = .RoundedRect
    textField.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    textField.inputView = self.datePicker
    textField.inputAccessoryView = self.datePickerToolbar
    textField.textAlignment = .Center
    return textField
  }()

  /// The picker for choosing a date
  public private(set) lazy var datePicker: UIDatePicker = {
    let datePicker = UIDatePicker()
    datePicker.datePickerMode = .Date
    datePicker.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    datePicker
      .addTarget(self, action: #selector(datePickerDidChange(_:)), forControlEvents: .ValueChanged)
    return datePicker
  }()

  /// The toolbar that appears above the date picker
  private private(set) lazy var datePickerToolbar: UIToolbar = {
    let datePickerToolbar = UIToolbar()
    datePickerToolbar.barStyle = .Default
    datePickerToolbar.translucent = true
    datePickerToolbar.items = [
      UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil),
      UIBarButtonItem(barButtonSystemItem: .Done, target: self,
        action: #selector(didTapDoneButton(_:)))
    ]
    datePickerToolbar.sizeToFit() // This is important or else the bar won't render!
    return datePickerToolbar
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

    guard let layout = self.fieldLayout,
      let fieldDate = self.fieldDate else
    {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      textField.text = FieldDateView.stringFromDate(fieldDate.date)

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

  private class func stringFromDate(date: NSDate) -> String {
    // Format the date based on the user's current locale, in a short style
    // (which is generally numeric)
    let dateFormatter = NSDateFormatter()
    dateFormatter.locale = NSLocale.currentLocale()
    dateFormatter.dateStyle = .ShortStyle
    return dateFormatter.stringFromDate(date)
  }

  private dynamic func didTapDoneButton(sender: UITextField) {
    updateDateFromDatePicker()

    // Stop editing the text field
    textField.resignFirstResponder()
  }

  private dynamic func datePickerDidChange(sender: UIDatePicker) {
    // Immediately update the date when the date picker changes
    updateDateFromDatePicker()
  }

  private func updateDateFromDatePicker() {
    fieldDate?.date = datePicker.date
  }
}

// MARK: - UITextFieldDelegate

extension FieldDateView: UITextFieldDelegate {
  public func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange,
    replacementString string: String) -> Bool
  {
    // Disable direct editing of the text field
    return false
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldDateView: FieldLayoutMeasurer {
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldDate = layout.field as? FieldDate else {
      bky_assertionFailure("`layout.field` is of type `(layout.field.dynamicType)`. " +
        "Expected type `FieldDate`.")
      return CGSizeZero
    }

    let textPadding = layout.config.edgeInsetFor(LayoutConfig.FieldTextFieldInsetPadding)
    let text = FieldDateView.stringFromDate(fieldDate.date)
    // TODO:(#27) Use a standardized font size that can be configurable for the project
    var measureSize = text.bky_singleLineSizeForFont(UIFont.systemFontOfSize(14 * scale))
    measureSize.height += textPadding.top + textPadding.bottom
    measureSize.width += textPadding.left + textPadding.right
    return measureSize
  }
}
