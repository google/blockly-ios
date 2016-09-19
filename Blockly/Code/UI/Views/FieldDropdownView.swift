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

  public required init() {
    super.init(frame: CGRect.zero)

    // Add subviews
    configureSubviews()
  }

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
          fieldDropdownLayout.config.viewUnitFor(LayoutConfig.FieldLineWidth)
        dropDownView.borderCornerRadius =
          fieldDropdownLayout.config.viewUnitFor(LayoutConfig.FieldCornerRadius)
        // TODO:(#27) Standardize this font
        dropDownView.textFont = UIFont.systemFont(ofSize: 14 * fieldDropdownLayout.engine.scale)
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

    let borderWidth = layout.config.viewUnitFor(LayoutConfig.FieldLineWidth)
    let xSpacing = layout.config.viewUnitFor(LayoutConfig.InlineXPadding)
    let ySpacing = layout.config.viewUnitFor(LayoutConfig.InlineYPadding)
    let measureText = (fieldDropdownLayout.selectedOption?.displayName ?? "")
    // TODO:(#27) Standardize this font
    let font = UIFont.systemFont(ofSize: 14 * scale)

    return DropdownView.measureSize(
      text: measureText, dropDownArrowImage: DropdownView.defaultDropDownArrowImage(),
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
    // TODO:(#27) Standardize this font
    viewController.textLabelFont = UIFont.systemFont(ofSize: 18)
    delegate?.fieldView(self,
                        requestedToPresentPopoverViewController: viewController, fromView: self)
  }
}

// MARK: - DropdownOptionsViewControllerDelegate

extension FieldDropdownView: DropdownOptionsViewControllerDelegate {
  public func dropdownOptionsViewController(_ viewController: DropdownOptionsViewController,
    didSelectOptionIndex optionIndex: Int)
  {
    fieldDropdownLayout?.updateSelectedIndex(optionIndex)
    viewController.presentingViewController?.dismiss(animated: true, completion: nil)
  }
}
