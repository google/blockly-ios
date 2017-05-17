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
 View for rendering a `FieldDropdownLayout`.
 */
@objc(BKYFieldDropdownView)
open class FieldDropdownView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldDropdownLayout`
  open var fieldDropdownLayout: FieldDropdownLayout? {
    return layout as? FieldDropdownLayout
  }

  /// The dropdown to render
  fileprivate lazy var dropDownView: DropdownView = {
    let dropDownView = DropdownView()
    dropDownView.delegate = self
    return dropDownView
  }()

  // MARK: - Initializers

  /// Initializes the dropdown field view.
  public required init() {
    super.init(frame: CGRect.zero)

    // Add subviews
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

    guard let fieldDropdownLayout = self.fieldDropdownLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
        let dropDownView = self.dropDownView
        dropDownView.text = fieldDropdownLayout.selectedOption?.displayName
        dropDownView.borderWidth =
          fieldDropdownLayout.config.viewUnit(for: LayoutConfig.FieldLineWidth)
        dropDownView.borderCornerRadius =
          fieldDropdownLayout.config.viewUnit(for: LayoutConfig.FieldCornerRadius)
        dropDownView.horizontalSpacing =
          fieldDropdownLayout.config.viewUnit(for: LayoutConfig.InlineXPadding)
        dropDownView.verticalSpacing =
          fieldDropdownLayout.config.viewUnit(for: LayoutConfig.InlineYPadding)
        dropDownView.textFont = fieldDropdownLayout.config.font(for: LayoutConfig.GlobalFont)
        dropDownView.textColor =
          fieldDropdownLayout.config.color(for: LayoutConfig.FieldEditableTextColor)

        let size = DropdownView.defaultDropDownArrowImage()?.size ?? CGSize.zero
        let scale = fieldDropdownLayout.engine.scale
        dropDownView.dropDownArrowImageSize = CGSize(width: size.width * scale, height: size.height * scale)
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

extension FieldDropdownView: FieldLayoutMeasurer {
  public static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldDropdownLayout = layout as? FieldDropdownLayout else {
      bky_assertionFailure("`layout` is of type `\(type(of: layout))`. " +
        "Expected type `FieldDropdownLayout`.")
      return CGSize.zero
    }

    let borderWidth = layout.config.viewUnit(for: LayoutConfig.FieldLineWidth)
    let xSpacing = layout.config.viewUnit(for: LayoutConfig.InlineXPadding)
    let ySpacing = layout.config.viewUnit(for: LayoutConfig.InlineYPadding)
    let measureText = (fieldDropdownLayout.selectedOption?.displayName ?? "")
    let font = layout.config.font(for: LayoutConfig.GlobalFont)
    let size = DropdownView.defaultDropDownArrowImage()?.size ?? CGSize.zero
    let scale = fieldDropdownLayout.engine.scale
    let dropDownArrowImageSize = CGSize(width: size.width * scale, height: size.height * scale)

    return DropdownView.measureSize(
      text: measureText, dropDownArrowImageSize: dropDownArrowImageSize,
      textFont: font, borderWidth: borderWidth, horizontalSpacing: xSpacing,
      verticalSpacing: ySpacing)
  }
}

// MARK: - DropDownViewDelegate Implementation

extension FieldDropdownView: DropdownViewDelegate {
  public func dropDownDidReceiveTap() {
    guard let fieldDropdownLayout = self.fieldDropdownLayout else {
      return
    }

    let viewController = DropdownOptionsViewController()
    viewController.delegate = self
    viewController.options = fieldDropdownLayout.options
    viewController.selectedIndex = fieldDropdownLayout.selectedIndex
    viewController.textLabelColor =
      fieldDropdownLayout.config.color(for: LayoutConfig.FieldEditableTextColor)

    if let fontCreator = fieldDropdownLayout.config.fontCreator(for: LayoutConfig.GlobalFont) {
      // Use a scaled font, but don't let the scale go less than 1.0
      viewController.textLabelFont = fontCreator(max(fieldDropdownLayout.engine.scale, 1.0))
    }

    popoverDelegate?
      .layoutView(self, requestedToPresentPopoverViewController: viewController, fromView: self)
  }
}

// MARK: - DropdownOptionsViewControllerDelegate

extension FieldDropdownView: DropdownOptionsViewControllerDelegate {
  public func dropdownOptionsViewController(
    _ viewController: DropdownOptionsViewController, didSelectOptionIndex optionIndex: Int)
  {
    EventManager.shared.groupAndFireEvents {
      fieldDropdownLayout?.updateSelectedIndex(optionIndex)
      popoverDelegate?.layoutView(
        self, requestedToDismissPopoverViewController: viewController, animated: true)
    }
  }
}
