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
open class FieldVariableView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldVariableLayout`
  open var fieldVariableLayout: FieldVariableLayout? {
    return layout as? FieldVariableLayout
  }

  /// The dropdown to render
  fileprivate lazy var dropDownView: DropdownView = {
    let dropDownView = DropdownView()
    dropDownView.delegate = self
    return dropDownView
  }()

  // MARK: - Initializers

  /// Initializes the variable field view.
  public required init() {
    super.init(frame: CGRect.zero)

    configureSubviews()
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
        dropDownView.textFont = fieldVariableLayout.config.font(for: LayoutConfig.GlobalFont)
      }
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    dropDownView.text = ""
  }

  // MARK: - Private

  fileprivate func configureSubviews() {
    let views: [String: UIView] = ["dropDownView": dropDownView]
    let constraints = [
      "H:|[dropDownView]|",
      "V:|[dropDownView]|",
      ]
    bky_addSubviews(Array(views.values))
    bky_addVisualFormatConstraints(constraints, metrics: nil, views: views)
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
    let xSpacing = layout.config.viewUnit(for: LayoutConfig.InlineXPadding)
    let ySpacing = layout.config.viewUnit(for: LayoutConfig.InlineYPadding)
    let measureText = fieldVariableLayout.variable
    let font = layout.config.font(for: LayoutConfig.GlobalFont)

    return DropdownView.measureSize(
      text: measureText, dropDownArrowImage: DropdownView.defaultDropDownArrowImage(),
      textFont: font, borderWidth: borderWidth, horizontalSpacing: xSpacing,
      verticalSpacing: ySpacing)
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

    if let fontCreator = fieldVariableLayout.config.fontCreator(for: LayoutConfig.GlobalFont) {
      // Use a scaled font, but don't let the scale go less than 1.0
      viewController.textLabelFont = fontCreator(max(fieldVariableLayout.engine.scale, 1.0))
    }

    // Populate options
    var options = fieldVariableLayout.variables
    options.append((displayName: "Rename Variable", value: "rename"))
    options.append((displayName: "Remove Variable", value: "remove"))
    viewController.options = options
    viewController.selectedIndex =
      options.index { $0.value == fieldVariableLayout.variable } ?? -1
    delegate?.fieldView(self,
                        requestedToPresentPopoverViewController: viewController, fromView: self)
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
    if (optionIndex == options.count) {
      let viewController = VariableNameViewController()
      viewController.delegate = self
      delegate?.fieldView(self,
                          requestedToPresentPopoverViewController: viewController, fromView: self)
    } else if (optionIndex == options.count + 1) {
      fieldVariableLayout.removeVariable()
    } else {
      // Change to a new variable
      fieldVariableLayout.changeToExistingVariable(value)
    }
    viewController.presentingViewController?.dismiss(animated: true, completion: nil)
  }
}

// MARK: - VariableNameViewControllerDelegate Implementation

extension FieldVariableView: VariableNameViewControllerDelegate {
  public func variableNameViewController(_ viewController: VariableNameViewController,
                                         didChangeName name: String?) {
    guard let newName = name,
      let layout = fieldVariableLayout,
      layout.isValidName(newName) else
    {
      return
    }

    layout.renameVariable(to: newName)
  }
}
