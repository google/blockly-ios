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
public class FieldDropdownView: FieldView {
  // MARK: - Properties

  /// The `FieldDropdown` backing this view
  public var fieldDropdown: FieldDropdown? {
    return fieldLayout?.field as? FieldDropdown
  }

  /// The text field to render
  private lazy var dropDownView: DropdownView = {
    let dropDownView = DropdownView(dropDownArrowImage: FieldDropdownView.dropDownArrowImage())
    dropDownView.delegate = self
    dropDownView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    dropDownView.translatesAutoresizingMaskIntoConstraints = true
    return dropDownView
  }()

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    // Add subviews
    addSubview(dropDownView)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  public override func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All) {
    super.refreshView(forFlags: flags)

    guard let layout = self.fieldLayout,
      let fieldDropdown = self.fieldDropdown else
    {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      dropDownView.text = fieldDropdown.selectedOption?.displayName
      dropDownView.borderWidth =
        layout.config.viewUnitFor(LayoutConfig.FieldLineWidth)
      dropDownView.borderCornerRadius =
        layout.config.viewUnitFor(LayoutConfig.FieldCornerRadius)
      // TODO:(#27) Standardize this font
      dropDownView.textFont = UIFont.systemFontOfSize(14 * layout.engine.scale)
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    dropDownView.text = ""
  }

  // MARK: - Private

  private class func dropDownArrowImage() -> UIImage? {
    return ImageLoader.loadImage(named: "arrow_dropdown", forClass: FieldDropdownView.self)
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldDropdownView: FieldLayoutMeasurer {
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldDropdown = layout.field as? FieldDropdown else {
      bky_assertionFailure("`layout.field` is of type `(layout.field.dynamicType)`. " +
        "Expected type `FieldDropdown`.")
      return CGSizeZero
    }

    let borderWidth = layout.config.viewUnitFor(LayoutConfig.FieldLineWidth)
    let xSpacing = layout.config.viewUnitFor(LayoutConfig.InlineXPadding)
    let ySpacing = layout.config.viewUnitFor(LayoutConfig.InlineYPadding)
    let measureText = (fieldDropdown.selectedOption?.displayName ?? "")
    // TODO:(#27) Standardize this font
    let font = UIFont.systemFontOfSize(14 * scale)

    return DropdownView.measureSize(
      text: measureText, dropDownArrowImage: FieldDropdownView.dropDownArrowImage(),
      textFont: font, borderWidth: borderWidth, horizontalSpacing: xSpacing,
      verticalSpacing: ySpacing)
  }
}

// MARK: - DropDownViewDelegate Implementation

extension FieldDropdownView: DropdownViewDelegate {
  public func dropDownDidReceiveTap() {
    guard let field = self.fieldDropdown,
      let parentBlockView = self.parentBlockView else
    {
      return
    }

    let viewController = DropdownOptionsViewController()
    viewController.delegate = self
    viewController.options = field.options
    viewController.selectedIndex = field.selectedIndex
    // TODO:(#27) Standardize this font
    viewController.textLabelFont = UIFont.systemFontOfSize(18)
    parentBlockView.requestToPresentPopoverViewController(viewController, fromView: self)
  }
}

// MARK: - DropdownOptionsViewControllerDelegate

extension FieldDropdownView: DropdownOptionsViewControllerDelegate {
  public func dropdownOptionsViewController(viewController: DropdownOptionsViewController,
    didSelectOptionIndex optionIndex: Int)
  {
    self.fieldDropdown?.selectedIndex = optionIndex
    viewController.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
  }
}
