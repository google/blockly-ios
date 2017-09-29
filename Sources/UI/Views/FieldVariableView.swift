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
 View for rendering a `FieldVariableLayout`.
 */
@objc(BKYFieldVariableView)
@objcMembers open class FieldVariableView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldVariableLayout`
  open var fieldVariableLayout: FieldVariableLayout? {
    return layout as? FieldVariableLayout
  }

  /// The dropdown to render
  fileprivate lazy var dropDownView: DropdownView = {
    let dropDownView = DropdownView()
    dropDownView.delegate = self
    dropDownView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    return dropDownView
  }()

  // MARK: - Initializers

  /// Initializes the variable field view.
  public required init() {
    super.init(frame: CGRect.zero)

    addSubview(dropDownView)
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

    guard let fieldVariableLayout = self.fieldVariableLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
        let dropDownView = self.dropDownView
        dropDownView.text = fieldVariableLayout.variable
        dropDownView.borderWidth =
          fieldVariableLayout.config.viewUnit(for: LayoutConfig.FieldLineWidth)
        dropDownView.borderCornerRadius =
          fieldVariableLayout.config.viewUnit(for: LayoutConfig.FieldCornerRadius)
        dropDownView.horizontalSpacing =
          fieldVariableLayout.config.viewUnit(for: LayoutConfig.FieldDropdownXSpacing)
        dropDownView.verticalSpacing =
          fieldVariableLayout.config.viewUnit(for: LayoutConfig.FieldDropdownYSpacing)
        dropDownView.textFont = fieldVariableLayout.config.font(for: LayoutConfig.GlobalFont)
        dropDownView.textColor =
          fieldVariableLayout.config.color(for: LayoutConfig.FieldEditableTextColor)
        dropDownView.dropDownArrowTintColor = dropDownView.textColor
        dropDownView.dropDownBackgroundColor =
          fieldVariableLayout.config.color(for: LayoutConfig.FieldDropdownBackgroundColor)
        dropDownView.borderColor =
          fieldVariableLayout.config.color(for: LayoutConfig.FieldDropdownBorderColor)

        let size = DropdownView.defaultDropDownArrowImageSize()
        let scale = fieldVariableLayout.engine.scale
        dropDownView.dropDownArrowImageSize =
          CGSize(width: size.width * scale, height: size.height * scale)
      }
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    dropDownView.text = ""
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldVariableView: FieldLayoutMeasurer {
  public static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldVariableLayout = layout as? FieldVariableLayout else {
      bky_assertionFailure("`layout` is of type `\(type(of: layout))`. " +
        "Expected type `FieldVariableLayout`.")
      return CGSize.zero
    }

    let borderWidth = layout.config.viewUnit(for: LayoutConfig.FieldLineWidth)
    let xSpacing = layout.config.viewUnit(for: LayoutConfig.FieldDropdownXSpacing)
    let ySpacing = layout.config.viewUnit(for: LayoutConfig.FieldDropdownYSpacing)
    let measureText = fieldVariableLayout.variable
    let font = layout.config.font(for: LayoutConfig.GlobalFont)
    let size = DropdownView.defaultDropDownArrowImageSize()
    let scale = fieldVariableLayout.engine.scale
    let dropDownArrowImageSize = CGSize(width: size.width * scale, height: size.height * scale)

    var measureSize = DropdownView.measureSize(
      text: measureText, dropDownArrowImageSize: dropDownArrowImageSize,
      textFont: font, borderWidth: borderWidth, horizontalSpacing: xSpacing,
      verticalSpacing: ySpacing)
    measureSize.height =
      max(measureSize.height, layout.config.viewUnit(for: LayoutConfig.FieldMinimumHeight))
    return measureSize
  }
}

// MARK: - DropDownViewDelegate Implementation

extension FieldVariableView: DropdownViewDelegate {
  public func dropDownDidReceiveTap() {
    guard let fieldVariableLayout = self.fieldVariableLayout else {
      return
    }

    let viewController = DropdownOptionsViewController()
    viewController.delegate = self
    viewController.textLabelColor =
      fieldVariableLayout.config.color(for: LayoutConfig.FieldEditableTextColor)

    if let fontCreator = fieldVariableLayout.config.fontCreator(for: LayoutConfig.GlobalFont) {
      // Use a scaled font, but don't let the scale go less than 1.0
      viewController.textLabelFont = fontCreator(max(fieldVariableLayout.engine.scale, 1.0))
    }

    let renameText = message(forKey: "BKY_RENAME_VARIABLE")
    let deleteText = message(forKey: "BKY_DELETE_VARIABLE")
      .replacingOccurrences(of: "%1", with: fieldVariableLayout.variable)

    // Populate options
    var options = fieldVariableLayout.variables
    options.append((displayName: renameText, value: "rename"))
    options.append((displayName: deleteText, value: "remove"))
    viewController.options = options
    viewController.selectedIndex =
      options.index { $0.value == fieldVariableLayout.variable } ?? -1

    popoverDelegate?.layoutView(self,
                                requestedToPresentPopoverViewController: viewController,
                                fromView: self,
                                presentationDelegate: self)
  }
}

// MARK: - UIPopoverPresentationControllerDelegate

extension FieldVariableView: UIPopoverPresentationControllerDelegate {
  public func prepareForPopoverPresentation(
    _ popoverPresentationController: UIPopoverPresentationController) {
    guard let rtl = self.fieldVariableLayout?.engine.rtl else { return }

    // Prioritize arrow directions so the popover opens in a way more consistent with other field
    // popovers.
    popoverPresentationController.bky_prioritizeArrowDirections([.up, .down, .left], rtl: rtl)
  }
}

// MARK: - DropdownOptionsViewControllerDelegate

extension FieldVariableView: DropdownOptionsViewControllerDelegate {
  public func dropdownOptionsViewController(_ viewController: DropdownOptionsViewController,
                                            didSelectOptionIndex optionIndex: Int)
  {
    guard let fieldVariableLayout = self.fieldVariableLayout else {
      return
    }

    let options = fieldVariableLayout.variables
    let value = viewController.options[optionIndex].value
    popoverDelegate?.layoutView(
      self, requestedToDismissPopoverViewController: viewController, animated: false)
    if (optionIndex == options.count) {
      // Pop up a dialog to rename the variable.
      renameVariable(fieldVariableLayout: fieldVariableLayout)
    } else if (optionIndex == options.count + 1) {
      // Pop up a dialog to remove the variable.
      removeVariable(fieldVariableLayout: fieldVariableLayout)
    } else {
      // Change to a new variable
      EventManager.shared.groupAndFireEvents {
        fieldVariableLayout.changeToExistingVariable(value)
      }
    }
  }

  private func renameVariable(fieldVariableLayout: FieldVariableLayout, error: String = "") {
    let title = message(forKey: "BKY_RENAME_VARIABLE_TITLE")
      .replacingOccurrences(of: "%1", with: fieldVariableLayout.variable)
    let renameView = UIAlertController(title: title, message: error, preferredStyle: .alert)
    renameView.addTextField { textField in
      textField.placeholder = message(forKey: "BKY_IOS_VARIABLES_VARIABLE_NAME")
      textField.text = fieldVariableLayout.variable
      textField.clearButtonMode = .whileEditing
      textField.becomeFirstResponder()
    }
    let cancelText = message(forKey: "BKY_IOS_CANCEL")
    let renameText = message(forKey: "BKY_IOS_VARIABLES_RENAME_BUTTON")
    renameView.addAction(UIAlertAction(title: cancelText, style: .default, handler: nil))
    let renameAlertAction = UIAlertAction(title: renameText, style: .default) {
      [weak renameView, weak self] _ in
      guard let renameView = renameView,
        let variableView = self else {
          return
      }
      guard let textField = renameView.textFields?[0],
        let newName = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
        fieldVariableLayout.isValidName(newName) else
      {
        variableView.renameVariable(fieldVariableLayout: fieldVariableLayout,
                            error: message(forKey: "BKY_IOS_VARIABLES_EMPTY_NAME_ERROR"))
        return
      }

      // We call this to balance out the presentation call, allowing the workspace
      // to perform any necessary state cleanup.
      variableView.popoverDelegate?.layoutView(variableView,
                                               requestedToDismissPopoverViewController: renameView,
                                               animated: false)

      EventManager.shared.groupAndFireEvents {
        fieldVariableLayout.renameVariable(to: newName)
      }
    }
    renameView.addAction(renameAlertAction)

    if #available(iOS 9, *) {
      // When the user presses the return button on the keyboard, it will automatically execute
      // this action
      renameView.preferredAction = renameAlertAction
    }

    popoverDelegate?.layoutView(self, requestedToPresentViewController: renameView)
  }

  private func removeVariable(fieldVariableLayout: FieldVariableLayout) {
    let variableCount = fieldVariableLayout.numberOfVariableReferences()
    if variableCount == 1 {
      EventManager.shared.groupAndFireEvents {
        // If this is the only instance of this variable, remove it.
        fieldVariableLayout.removeVariable()
      }
    } else {
      // Otherwise, verify the user intended to remove all instances of this variable.
      let title = message(forKey: "BKY_DELETE_VARIABLE_CONFIRMATION")
        .replacingOccurrences(of: "%1", with: "\(variableCount)")
        .replacingOccurrences(of: "%2", with: fieldVariableLayout.variable)
      let removeView = UIAlertController(title: title, message: "", preferredStyle: .alert)
      let cancelText = message(forKey: "BKY_IOS_CANCEL")
      let deleteText = message(forKey: "BKY_IOS_VARIABLES_DELETE_BUTTON")
      removeView.addAction(UIAlertAction(title: cancelText, style: .default, handler: nil))
      removeView.addAction(UIAlertAction(title: deleteText, style: .default) { _ in
        EventManager.shared.groupAndFireEvents {
          fieldVariableLayout.removeVariable()
        }
      })

      popoverDelegate?.layoutView(self, requestedToPresentViewController: removeView)
    }
  }
}
