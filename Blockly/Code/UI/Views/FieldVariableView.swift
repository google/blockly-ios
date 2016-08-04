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
public class FieldVariableView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldVariableLayout`
  public var fieldVariableLayout: FieldVariableLayout? {
    return layout as? FieldVariableLayout
  }

  /// The dropdown to render
  private lazy var dropDownView: DropdownView = {
    let dropDownView = DropdownView()
    dropDownView.delegate = self
    return dropDownView
  }()

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    configureSubviews()
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  public override func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All) {
    super.refreshView(forFlags: flags)

    guard let fieldVariableLayout = self.fieldVariableLayout else {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      dropDownView.text = fieldVariableLayout.variable
      dropDownView.borderWidth =
        fieldVariableLayout.config.viewUnitFor(LayoutConfig.FieldLineWidth)
      dropDownView.borderCornerRadius =
        fieldVariableLayout.config.viewUnitFor(LayoutConfig.FieldCornerRadius)
      // TODO:(#27) Standardize this font
      dropDownView.textFont = UIFont.systemFontOfSize(14 * fieldVariableLayout.engine.scale)
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    dropDownView.text = ""
  }

  // MARK: - Private

  private func configureSubviews() {
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
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldVariableLayout = layout as? FieldVariableLayout else {
      bky_assertionFailure("`layout` is of type `\(layout.dynamicType)`. " +
        "Expected type `FieldVariableLayout`.")
      return CGSizeZero
    }

    let borderWidth = layout.config.viewUnitFor(LayoutConfig.FieldLineWidth)
    let xSpacing = layout.config.viewUnitFor(LayoutConfig.InlineXPadding)
    let ySpacing = layout.config.viewUnitFor(LayoutConfig.InlineYPadding)
    let measureText = fieldVariableLayout.variable
    // TODO:(#27) Standardize this font
    let font = UIFont.systemFontOfSize(14 * scale)

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
    // TODO:(#27) Standardize this font
    viewController.textLabelFont = UIFont.systemFontOfSize(18)

    // Populate options
    let options = fieldVariableLayout.variables
    viewController.options = options
    viewController.selectedIndex =
      options.indexOf { $0.value == fieldVariableLayout.variable } ?? -1
    delegate?.fieldView(self,
                        requestedToPresentPopoverViewController: viewController, fromView: self)
  }
}

// MARK: - DropdownOptionsViewControllerDelegate

extension FieldVariableView: DropdownOptionsViewControllerDelegate {
  public func dropdownOptionsViewController(viewController: DropdownOptionsViewController,
                                            didSelectOptionIndex optionIndex: Int)
  {
    // Change to a new variable
    fieldVariableLayout?.changeToVariable(viewController.options[optionIndex].value)
    viewController.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
  }
}
