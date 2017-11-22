/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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
 Delegate for events that occur on `NumberPad`.
 */
@objc(BKYNumberPadDelegate)
public protocol NumberPadDelegate: class {
  /**
   Event that is fired if the number pad text has changed.

   - parameter numberPad: The `NumberPad` that triggered this event.
   - parameter text: The current text of the `numberPad`.
   */
  func numberPad(_ numberPad: NumberPad, didChangeText text: String)

  /**
   Event that is fired if the user pressed the return key (from a connected physical keyboard).

   - parameter numberPad: The `NumberPad` that triggered this event.
   */
  func numberPadDidPressReturnKey(_ numberPad: NumberPad)
}

/**
 UI control for typing numbers.
 */
@objc(BKYNumberPad)
@objcMembers public class NumberPad: UIView {
  // MARK: - Constants

  /**
   Options for configuring the behavior of the number pad.
   */
  public struct Options {
    /// The color to use for the backspace button.
    public var backspaceButtonColor: UIColor = ColorPalette.green.tint300

    /// The corner radius to use for the non-backspace buttons.
    public var buttonCornerRadius: CGFloat = 4

    /// The text color to use for non-backspace buttons.
    public var buttonTextColor: UIColor = ColorPalette.grey.tint900

    /// The background color to use for non-backspace buttons.
    public var buttonBackgroundColor: UIColor = ColorPalette.grey.tint300

    /// The border color to use for non-backspace buttons.
    public var buttonBorderColor: UIColor = ColorPalette.grey.tint300

    /// The color to use for the main number text field.
    public var textFieldColor: UIColor = ColorPalette.grey.tint900
  }

  // MARK: - Properties

  /// Button for the "0" value.
  @IBOutlet public weak var button0: UIButton?
  /// Button for the "1" value.
  @IBOutlet public weak var button1: UIButton?
  /// Button for the "2" value.
  @IBOutlet public weak var button2: UIButton?
  /// Button for the "3" value.
  @IBOutlet public weak var button3: UIButton?
  /// Button for the "4" value.
  @IBOutlet public weak var button4: UIButton?
  /// Button for the "5" value.
  @IBOutlet public weak var button5: UIButton?
  /// Button for the "6" value.
  @IBOutlet public weak var button6: UIButton?
  /// Button for the "7" value.
  @IBOutlet public weak var button7: UIButton?
  /// Button for the "8" value.
  @IBOutlet public weak var button8: UIButton?
  /// Button for the "9" value.
  @IBOutlet public weak var button9: UIButton?
  /// Button for the minus sign symbol.
  @IBOutlet public weak var buttonMinusSign: UIButton?
  /// Button for the decimal symbol.
  @IBOutlet public weak var buttonDecimal: UIButton?
  /// Button for deleting a character.
  @IBOutlet public weak var buttonBackspace: UIButton?
  /// Text field that holds the current number.
  @IBOutlet public weak var textField: NumberPadTextField? {
    didSet {
      // Prevent keyboard from appearing.
      _dummyKeyboardView.removeFromSuperview()
      textField?.inputView = _dummyKeyboardView

      if #available(iOS 9.0, *) {
        // Prevent shortcut toolbar from appearing at the bottom.
        textField?.inputAssistantItem.leadingBarButtonGroups = []
        textField?.inputAssistantItem.trailingBarButtonGroups = []
      }

      textField?.numberPad = self
    }
  }

  /// Empty view used to prevent the virtual keyboard from appearing when editing the number pad
  /// text field (we still want to enable use of a connected physical keyboard though, which
  /// is why the text field is still editable).
  private let _dummyKeyboardView = UIView()

  /// Flag that determines if this view is using the default number pad.
  public let isDefault: Bool

  /// Allows use of the minus sign button. Defaults to `true`.
  public var allowMinusSign: Bool = true {
    didSet { updateState() }
  }

  /// Allows use of the decimal button. Defaults to `true`.
  public var allowDecimal: Bool = true {
    didSet { updateState() }
  }

  /// Returns the displayed text of the number pad.
  public var text: String {
    get { return textField?.text ?? "" }
    set {
      textField?.text = newValue
      updateState()
    }
  }

  /// The font to use within the number pad.
  public var font: UIFont? {
    didSet {
      if let font = self.font {
        // Use a slightly larger font size for the number.
        textField?.font = font.withSize(font.pointSize + 2)
      }

      button0?.titleLabel?.font = font
      button1?.titleLabel?.font = font
      button2?.titleLabel?.font = font
      button3?.titleLabel?.font = font
      button4?.titleLabel?.font = font
      button5?.titleLabel?.font = font
      button6?.titleLabel?.font = font
      button7?.titleLabel?.font = font
      button8?.titleLabel?.font = font
      button9?.titleLabel?.font = font
      buttonMinusSign?.titleLabel?.font = font
      buttonDecimal?.titleLabel?.font = font
      updateState()
    }
  }

  /// Configurable options of the number pad.
  /// - note: These values are not used if a custom UI is provided for this control.
  public let options: Options

  /// Delegate for events that occur on this instance.
  public weak var delegate: NumberPadDelegate?

  /// Number formatter used for converting values to localized text.
  fileprivate let _localizedNumberFormatter = NumberFormatter()

  // MARK: - Initializers

  public init(frame: CGRect, useDefault: Bool = true, options: Options) {
    self.options = options
    self.isDefault = useDefault

    super.init(frame: frame)

    if isDefault {
      createDefaultControls()
    }

    updateState()
  }

  public required init?(coder aDecoder: NSCoder) {
    self.isDefault = false
    self.options = Options()

    super.init(coder: aDecoder)

    updateState()
  }

  private func createDefaultControls() {
    // Create buttons
    button0 = addButton(text: _localizedNumberFormatter.string(from: 0))
    button1 = addButton(text: _localizedNumberFormatter.string(from: 1))
    button2 = addButton(text: _localizedNumberFormatter.string(from: 2))
    button3 = addButton(text: _localizedNumberFormatter.string(from: 3))
    button4 = addButton(text: _localizedNumberFormatter.string(from: 4))
    button5 = addButton(text: _localizedNumberFormatter.string(from: 5))
    button6 = addButton(text: _localizedNumberFormatter.string(from: 6))
    button7 = addButton(text: _localizedNumberFormatter.string(from: 7))
    button8 = addButton(text: _localizedNumberFormatter.string(from: 8))
    button9 = addButton(text: _localizedNumberFormatter.string(from: 9))
    buttonMinusSign = addButton(
      text: _localizedNumberFormatter.plusSign + "/" + _localizedNumberFormatter.minusSign)
    buttonDecimal = addButton(text: _localizedNumberFormatter.decimalSeparator)
    buttonBackspace = addButton()

    if let image = ImageLoader.loadImage(named: "backspace", forClass: NumberPad.self) {
      buttonBackspace?.setImage(image, for: .normal)
      buttonBackspace?.imageView?.contentMode = .scaleAspectFit
      buttonBackspace?.contentHorizontalAlignment = .fill
      buttonBackspace?.contentVerticalAlignment = .fill
      buttonBackspace?.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
      buttonBackspace?.layer.borderWidth = 0
      buttonBackspace?.sizeToFit()
      buttonBackspace?.tintColor = options.backspaceButtonColor
      buttonBackspace?.backgroundColor = .clear
    }

    // Create text field
    let textField = NumberPadTextField()
    textField.adjustsFontSizeToFitWidth = false
    textField.textAlignment = .natural
    textField.rightViewMode = .always
    textField.delegate = self
    textField.numberPad = self
    textField.inputView = _dummyKeyboardView  // Prevent keyboard from appearing.
    textField.textColor = options.textFieldColor

    if let font = self.font {
      // Use a slightly larger font size for the number.
      textField.font = font.withSize(font.pointSize + 2)
    }

    if #available(iOS 9.0, *) {
      // Prevent shortcut toolbar from appearing at the bottom.
      textField.inputAssistantItem.leadingBarButtonGroups = []
      textField.inputAssistantItem.trailingBarButtonGroups = []
    }

    self.textField = textField
    addSubview(textField)
  }

  // MARK: - Super

  public override func layoutSubviews() {
    super.layoutSubviews()

    // Only run this layout code for the default number pad controls.
    guard isDefault else { return }

    let rows = [
      [textField, buttonBackspace],
      [button1, button2, button3],
      [button4, button5, button6],
      [button7, button8, button9],
      [buttonMinusSign, button0, buttonDecimal]
    ] as [[UIView?]]

    let padding = min(bounds.width, bounds.height) * 0.03  // Use the same spacing for x & y axes
    let numRows = CGFloat(rows.count)
    let rowHeight = (bounds.height - padding * (numRows - 1)) / numRows
    var x: CGFloat = 0
    var y: CGFloat = 0

    for (row, views) in rows.enumerated() {
      x = 0

      if row == 0 {
        // The first row is special in that the text field should use as much space as possible.
        let backspaceWidth = rowHeight
        textField?.frame =
          CGRect(x: x, y: y, width: bounds.width - backspaceWidth - padding, height: rowHeight)
        x += (textField?.bounds.width ?? 0) + padding
        buttonBackspace?.frame = CGRect(x: x, y: y, width: backspaceWidth, height: rowHeight)
      } else {
        // Evenly distribute the buttons across the row.
        let numColumns = CGFloat(views.count)
        let columnWidth = (bounds.width - padding * (numColumns - 1)) / numColumns

        for view in views {
          view?.frame = CGRect(x: x, y: y, width: columnWidth, height: rowHeight)
          x += columnWidth + padding
        }
      }

      y += rowHeight + padding
    }
  }

  // MARK: - Button Configuration

  private func addButton(text: String? = nil) -> UIButton {
    let button = UIButton(type: .roundedRect)
    if let text = text {
      button.setTitle(text, for: .normal)
    }
    button.autoresizingMask = []
    button.addTarget(self, action: #selector(didPressButton(_:)), for: .touchUpInside)
    button.contentMode = .center
    button.layer.borderWidth = 1.0
    button.layer.cornerRadius = options.buttonCornerRadius
    button.titleLabel?.font = self.font
    button.tintColor = options.buttonTextColor
    button.layer.borderColor = options.buttonBorderColor.cgColor
    button.backgroundColor = options.buttonBackgroundColor
    addSubview(button)
    return button
  }

  /**
   Method that is called when the user presses a button.

   - parameter button: The button that triggered the event.
   */
  public func didPressButton(_ button: UIButton) {
    var buttonText: String?
    if button == button0 {
      buttonText = _localizedNumberFormatter.string(from: 0) ?? "0"
    } else if button == button1 {
      buttonText = _localizedNumberFormatter.string(from: 1) ?? "1"
    } else if button == button2 {
      buttonText = _localizedNumberFormatter.string(from: 2) ?? "2"
    } else if button == button3 {
      buttonText = _localizedNumberFormatter.string(from: 3) ?? "3"
    } else if button == button4 {
      buttonText = _localizedNumberFormatter.string(from: 4) ?? "4"
    } else if button == button5 {
      buttonText = _localizedNumberFormatter.string(from: 5) ?? "5"
    } else if button == button6 {
      buttonText = _localizedNumberFormatter.string(from: 6) ?? "6"
    } else if button == button7 {
      buttonText = _localizedNumberFormatter.string(from: 7) ?? "7"
    } else if button == button8 {
      buttonText = _localizedNumberFormatter.string(from: 8) ?? "8"
    } else if button == button9 {
      buttonText = _localizedNumberFormatter.string(from: 9) ?? "9"
    } else if button == buttonMinusSign {
      buttonText = _localizedNumberFormatter.minusSign
    } else if button == buttonDecimal {
      buttonText = _localizedNumberFormatter.decimalSeparator
    } else if button == buttonBackspace {
      buttonText = ""
    }

    if let text = buttonText {
      handleText(text, replacement: false)
    }
  }

  // MARK: - Text Handling

  /**
   Handles the insertion of given text into `textField`.

   - parameter text: The text to insert into the text field. If it is a deletion, then this value
   should be `""`.
   - parameter replacement: `true` if the entire `textField.text` should be replaced. `false` if
   the given text should be inserted at the current cursor position.
   */
  fileprivate func handleText(_ text: String, replacement: Bool) {
    guard let textField = self.textField,
      var currentText = textField.text else {
      return
    }

    guard allowMinusSign || !text.contains(_localizedNumberFormatter.minusSign) else {
      return
    }
    guard allowDecimal || !text.contains(_localizedNumberFormatter.decimalSeparator) else {
      return
    }

    let oldText = currentText

    if text.isEmpty && !currentText.isEmpty {
      // Empty text means the backspace key was pressed. Remove last character.
      textField.deleteBackward()
    } else if text == _localizedNumberFormatter.minusSign {
      // Toggle "-"
      if currentText.contains(text) {
        currentText = currentText.replacingOccurrences(of: text, with: "")
      } else {
        currentText = text + currentText
      }
      textField.text = currentText
    } else if text == _localizedNumberFormatter.plusSign &&
      currentText.contains(_localizedNumberFormatter.minusSign) {
      // "+" button was pressed, remove the "-".
      textField.text = currentText.replacingOccurrences(
        of: _localizedNumberFormatter.minusSign, with: "")
    } else if text == _localizedNumberFormatter.decimalSeparator && !currentText.contains(text) {
      // Add "." since it's not present yet.
      insertText(text)
    } else if text.count == 1 && !replacement {
      // This is the equivalent of a button press (either from the number pad or physical keyboard).
      if _localizedNumberFormatter.number(from: text) != nil {
        // The text entered is a localized digit. Figure out how to insert it into the text field.
        if let zero = _localizedNumberFormatter.string(from: 0),
          _localizedNumberFormatter.number(from: currentText) == 0 &&
          !currentText.contains(_localizedNumberFormatter.decimalSeparator) {
          // Special case where current text is "0" or "-0" (or equivalent for RTL).
          // Replace "0" in the current text with the new number (while preserving the minus sign).
          textField.text = currentText.replacingOccurrences(of: zero, with: text)
        } else {
          // Simply add the number to the text field.
          insertText(text)
        }
      }
    } else if text.count > 1 || replacement {
      // This must be a pasted string. Completely replace the current text if it's a valid number.
      if _localizedNumberFormatter.number(from: text) != nil {
        textField.text = text
      }
    }

    updateState()

    if oldText != textField.text {
      delegate?.numberPad(self, didChangeText: self.text)
    }
  }

  fileprivate func insertText(_ text: String) {
    guard let textField = self.textField,
      let selectedTextRange = textField.selectedTextRange,
      let currentText = textField.text else {
      return
    }

    // Check that inserting the text isn't before the minus sign.
    let offset = textField.offset(from: textField.beginningOfDocument, to: selectedTextRange.start)
    if offset == 0 && currentText.contains(_localizedNumberFormatter.minusSign) {
      // Move the cursor position to the end, so nothing is inserted before the minus sign
      let cursorPosition = textField.endOfDocument
      textField.selectedTextRange = textField.textRange(from: cursorPosition, to: cursorPosition)
    }

    textField.insertText(text)
  }

  // MARK: - State Update

  fileprivate func updateState() {
    let text = textField?.text ?? ""

    buttonBackspace?.isEnabled = !text.isEmpty
    buttonDecimal?.isEnabled = !text.contains(_localizedNumberFormatter.decimalSeparator)
    buttonDecimal?.isHidden = !allowDecimal
    buttonMinusSign?.isHidden = !allowMinusSign
  }
}

// MARK: - UITextFieldDelegate Implementation

extension NumberPad: UITextFieldDelegate {
  public func textField(
    _ textField: UITextField,
    shouldChangeCharactersIn range: NSRange,
    replacementString string: String) -> Bool {
    // Manually handle text insertion/replacement/deletion.
    handleText(string, replacement: false)
    return false
  }

  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    // Remove focus from the text field.
    textField.resignFirstResponder()

    // Notify the delegate.
    delegate?.numberPadDidPressReturnKey(self)

    return true
  }
}

/**
 Specialized text field used for `NumberPad`.
 */
public class NumberPadTextField: UITextField {
  fileprivate weak var numberPad: NumberPad? = nil

  // MARK: - Text Field Rendering

  public override func selectionRects(for range: UITextRange) -> [Any] {
    // Disable selection ranges.
    return []
  }

  // MARK: - Copy/Paste Actions

  public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(copy(_:)) {
      // Only allow copy if there's something to copy.
      return (text?.count ?? 0) > 0
    } else if action == #selector(paste(_:)) {
      // Only allow paste if there's a valid number in the pasteboard.
      if let numberPad = self.numberPad,
        let text = UIPasteboard.general.string, !text.isEmpty {
        return numberPad._localizedNumberFormatter.number(from: text) != nil
      }
    }
    return false
  }

  public override func copy(_ sender: Any?) {
    // Always copy the entire number
    UIPasteboard.general.string = text
  }

  public override func paste(_ sender: Any?) {
    // Paste the text into number pad
    if let text = UIPasteboard.general.string, !text.isEmpty {
      numberPad?.handleText(text, replacement: true)
    }
  }
}
