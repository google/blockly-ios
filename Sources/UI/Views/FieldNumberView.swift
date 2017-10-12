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
@objcMembers open class FieldNumberView: FieldView {
  // MARK: - Properties

  /// Convenience property accessing `self.layout` as `FieldNumberLayout`
  fileprivate var fieldNumberLayout: FieldNumberLayout? {
    return layout as? FieldNumberLayout
  }

  /// The text field that displays the number.
  public fileprivate(set) lazy var textField: InsetTextField = {
    let textField = InsetTextField(frame: CGRect.zero)
    textField.delegate = self
    textField.borderStyle = .roundedRect
    textField.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    textField.textAlignment = .center
    textField.adjustsFontSizeToFitWidth = false
    return textField
  }()

  /// Group ID to use when grouping events together.
  fileprivate var _eventGroupID: String?

  /// The number pad view controller being presented in a popover.
  fileprivate weak var numberPadViewController: NumberPadViewController?

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
        self.updateTextFieldFromLayout()

        let textField = self.textField
        textField.font = layout.config.font(for: LayoutConfig.GlobalFont)
        textField.textColor = layout.config.color(for: LayoutConfig.FieldEditableTextColor)
        textField.insetPadding =
          layout.config.viewEdgeInsets(for: LayoutConfig.FieldTextFieldInsetPadding)
      }
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    textField.text = ""
  }

  // MARK: - Private

  fileprivate func updateTextFieldFromLayout() {
    let text = fieldNumberLayout?.currentTextValue ?? ""
    if textField.text != text {
      textField.text = text
    }
  }

  fileprivate func commitUpdate() {
    guard let fieldNumberLayout = self.fieldNumberLayout else { return }

    EventManager.shared.groupAndFireEvents(groupID: _eventGroupID) {
      fieldNumberLayout.setValueFromLocalizedText(fieldNumberLayout.currentTextValue)

      // Update the text field based on the current fieldNumber
      updateTextFieldFromLayout()
    }
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

    let textPadding = layout.config.viewEdgeInsets(for: LayoutConfig.FieldTextFieldInsetPadding)
    let maxWidth = layout.config.viewUnit(for: LayoutConfig.FieldTextFieldMaximumWidth)
    let measureText = fieldNumberLayout.currentTextValue + " "
    let font = layout.config.font(for: LayoutConfig.GlobalFont)
    var measureSize = measureText.bky_singleLineSize(forFont: font)
    measureSize.height = measureSize.height + textPadding.top + textPadding.bottom
    measureSize.width =
      min(measureSize.width + textPadding.leading + textPadding.trailing, maxWidth)
    measureSize.width =
      max(measureSize.width, layout.config.viewUnit(for: LayoutConfig.FieldTextFieldMinimumWidth))
    measureSize.height =
      max(measureSize.height, layout.config.viewUnit(for: LayoutConfig.FieldMinimumHeight))
    return measureSize
  }
}

// MARK: - UITextFieldDelegate implementation

extension FieldNumberView: UITextFieldDelegate {
  public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    guard let fieldNumberLayout = self.fieldNumberLayout else { return false }

    // Don't actually edit the text field with the keyboard, but show a number pad instead.
    let numberPadOptions = fieldNumberLayout.config.untypedValue(
      for: LayoutConfig.FieldNumberPadOptions) as? NumberPad.Options
    let viewController = NumberPadViewController(options: numberPadOptions)
    viewController.numberPad.text = textField.text ?? ""
    viewController.numberPad.allowDecimal = !fieldNumberLayout.isInteger
    viewController.numberPad.allowMinusSign = (fieldNumberLayout.minimumValue ?? -1) < 0
    viewController.numberPad.delegate = self

    if let fontCreator = fieldNumberLayout.config.fontCreator(for: LayoutConfig.PopoverLabelFont) {
      // Use the popover font, but use a scale of 1.0.
      viewController.numberPad.font = fontCreator(1.0)
    }

    // Start a new event group for this edit.
    _eventGroupID = UUID().uuidString

    popoverDelegate?.layoutView(self,
                                requestedToPresentPopoverViewController: viewController,
                                fromView: self,
                                presentationDelegate: self)

    self.numberPadViewController = viewController

    // Hide keyboard
    endEditing(true)

    return false
  }
}

// MARK: - UIPopoverPresentationControllerDelegate

extension FieldNumberView: UIPopoverPresentationControllerDelegate {
  public func prepareForPopoverPresentation(
    _ popoverPresentationController: UIPopoverPresentationController) {
    guard let rtl = self.fieldNumberLayout?.engine.rtl else { return }

    // Prioritize arrow directions, so it won't obstruct the view of the field
    popoverPresentationController.bky_prioritizeArrowDirections([.up, .down, .right], rtl: rtl)
  }

  public func popoverPresentationControllerShouldDismissPopover(
    _ popoverPresentationController: UIPopoverPresentationController) -> Bool {

    // Commit the change right before the popover is being dismissed (as opposed to after, which
    // causes a visual delay).
    commitUpdate()

    numberPadViewController = nil

    // Always allow the dismissal of the popover.
    return true
  }
}

// MARK: - NumberPadViewControllerDelegate

extension FieldNumberView: NumberPadDelegate {
  public func numberPad(_ numberPad: NumberPad, didChangeText text: String) {
    // Update the current text value, but don't commit anything yet.
    fieldNumberLayout?.currentTextValue = text
    updateTextFieldFromLayout()
  }

  public func numberPadDidPressReturnKey(_ numberPad: NumberPad) {
    // Commit update
    commitUpdate()

    // Dismiss the popover
    if let numberPadViewController = self.numberPadViewController {
      popoverDelegate?.layoutView(
        self, requestedToDismissPopoverViewController: numberPadViewController, animated: true)
      self.numberPadViewController = nil
    }
  }
}
