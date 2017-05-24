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

  /// The text field that displays the angle.
  public fileprivate(set) lazy var textField: InsetTextField = {
    let textField = InsetTextField(frame: self.bounds)
    textField.frame = self.bounds
    textField.delegate = self
    textField.borderStyle = .roundedRect
    textField.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    textField.textAlignment = .right
    return textField
  }()

  /// Group ID to use when grouping events together.
  fileprivate var _eventGroupID: String?

  // MARK: - Initializers

  /// Initializes the angle field view.
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

    guard let fieldAngleLayout = self.fieldAngleLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
        self.updateTextFieldFromLayout()

        let textField = self.textField
        textField.font = fieldAngleLayout.config.font(for: LayoutConfig.GlobalFont)
        textField.textColor =
          fieldAngleLayout.config.color(for: LayoutConfig.FieldEditableTextColor)
        textField.insetPadding =
          fieldAngleLayout.config.edgeInsets(for: LayoutConfig.FieldTextFieldInsetPadding)
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
}

// MARK: - UITextFieldDelegate

extension FieldAngleView: UITextFieldDelegate {
  public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    guard let fieldAngleLayout = self.fieldAngleLayout else {
      return false
    }

    // Don't actually edit the text field with the keyboard, but show the angle picker instead.
    let pickerOptions = fieldAngleLayout.config.untypedValue(
      for: LayoutConfig.FieldAnglePickerOptions) as? AnglePicker.Options
    let viewController = AnglePickerViewController(options: pickerOptions)
    viewController.delegate = self
    viewController.angle = fieldAngleLayout.angle

    // Start a new event group for this edit.
    _eventGroupID = UUID().uuidString

    popoverDelegate?
      .layoutView(self, requestedToPresentPopoverViewController: viewController, fromView: self)

    // Hide keyboard
    endEditing(true)

    return false
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldAngleView: FieldLayoutMeasurer {
  public static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldAngleLayout = layout as? FieldAngleLayout else {
      bky_assertionFailure("`layout` is of type `\(type(of: layout))`. " +
        "Expected type `FieldAngleLayout`.")
      return CGSize.zero
    }

    let textPadding = layout.config.edgeInsets(for: LayoutConfig.FieldTextFieldInsetPadding)
    let maxWidth = layout.config.viewUnit(for: LayoutConfig.FieldTextFieldMaximumWidth)
    // Use a minimum size that can at least accomodate 3 digits and °. This is to help ensure that
    //  the angle picker popover doesn't ever accidentally obstruct the view of the text field
    // (edge case scenario).
    let minimumText = "000°"
    let actualText = fieldAngleLayout.textValue
    let font = layout.config.font(for: LayoutConfig.GlobalFont)
    let minimumSize = minimumText.bky_singleLineSize(forFont: font)
    let actualSize = actualText.bky_singleLineSize(forFont: font)

    var measureSize = CGSize(
      width: max(minimumSize.width, actualSize.width),
      height: max(minimumSize.height, actualSize.height))
    measureSize.height += textPadding.top + textPadding.bottom
    measureSize.width =
      min(measureSize.width + textPadding.leading + textPadding.trailing, maxWidth)
    return measureSize
  }
}

// MARK: - AnglePickerViewControllerDelegate

extension FieldAngleView: AnglePickerViewControllerDelegate {
  public func anglePickerViewController(
    _ viewController: AnglePickerViewController, didUpdateAngle angle: Double) {
    EventManager.shared.groupAndFireEvents(groupID: _eventGroupID) {
      fieldAngleLayout?.updateAngle(angle)

      // Update the text from the layout
      updateTextFieldFromLayout()
    }
  }
}
