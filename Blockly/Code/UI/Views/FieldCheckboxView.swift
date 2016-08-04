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
 View for rendering a `FieldCheckboxLayout`.
 
 Because there is no native checkbox on iOS, this is implemented using a `UISwitch`.
 */
@objc(BKYFieldCheckboxView)
public class FieldCheckboxView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldCheckboxLayout`
  public var fieldCheckboxLayout: FieldCheckboxLayout? {
    return layout as? FieldCheckboxLayout
  }

  /// The switch button (i.e. the "checkbox")
  private lazy var switchButton: UISwitch = {
    let switchButton = UISwitch()
    switchButton.addTarget(
      self, action: #selector(switchValueDidChange(_:)), forControlEvents: .ValueChanged)
    return switchButton
  }()

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    addSubview(switchButton)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  public override func refreshView(forFlags flags: LayoutFlag = LayoutFlag.All) {
    super.refreshView(forFlags: flags)

    guard let fieldCheckboxLayout = self.fieldCheckboxLayout else {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      switchButton.on = fieldCheckboxLayout.checked

      let tintColor = fieldCheckboxLayout.config.colorFor(LayoutConfig.FieldCheckboxSwitchTintColor)
      let onTintColor =
        fieldCheckboxLayout.config.colorFor(LayoutConfig.FieldCheckboxSwitchOnTintColor)

      if switchButton.tintColor != tintColor {
        // Whenever `tintColor` is set, it messes up the switch's transition animation.
        // Therefore, it's only set if the value changes.
        switchButton.tintColor = tintColor
      }
      if switchButton.onTintColor != onTintColor {
        // Whenever `onTintColor` is set, it messes up the switch's transition animation.
        // Therefore, it's only set if the value changes.
        switchButton.onTintColor = onTintColor
      }
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    switchButton.on = false
  }

  // MARK: - Private

  private dynamic func switchValueDidChange(sender: UISwitch) {
    fieldCheckboxLayout?.updateCheckbox(switchButton.on)
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldCheckboxView: FieldLayoutMeasurer {
  private static var switchButtonSize = CGSizeZero

  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    if !(layout is FieldCheckboxLayout) {
      bky_assertionFailure("`layout` is of type `\(layout.dynamicType)`. " +
        "Expected type `FieldCheckboxLayout`.")
      return CGSizeZero
    }

    if switchButtonSize == CGSizeZero {
      // UISwitch sizes never change. Measure it once and then never again.
      switchButtonSize = UISwitch().bounds.size
    }
    return switchButtonSize
  }
}
