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
@objcMembers open class FieldCheckboxView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldCheckboxLayout`
  open var fieldCheckboxLayout: FieldCheckboxLayout? {
    return layout as? FieldCheckboxLayout
  }

  /// The switch button (i.e. the "checkbox")
  fileprivate lazy var switchButton: UISwitch = {
    let switchButton = UISwitch()
    switchButton.addTarget(
      self, action: #selector(switchValueDidChange(_:)), for: .valueChanged)
    return switchButton
  }()

  // MARK: - Initializers

  /// Initializes the checkbox field view.
  public required init() {
    super.init(frame: CGRect.zero)

    addSubview(switchButton)
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

    guard let fieldCheckboxLayout = self.fieldCheckboxLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
        let switchButton = self.switchButton
        switchButton.isOn = fieldCheckboxLayout.checked

        let tintColor =
          fieldCheckboxLayout.config.color(for: LayoutConfig.FieldCheckboxSwitchTintColor)
        let onTintColor =
          fieldCheckboxLayout.config.color(for: LayoutConfig.FieldCheckboxSwitchOnTintColor)

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
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    switchButton.isOn = false
  }

  // MARK: - Private

  @objc fileprivate dynamic func switchValueDidChange(_ sender: UISwitch) {
    EventManager.shared.groupAndFireEvents {
      fieldCheckboxLayout?.updateCheckbox(switchButton.isOn)
    }
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldCheckboxView: FieldLayoutMeasurer {
  fileprivate static var switchButtonSize = CGSize.zero

  public static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize {
    if !(layout is FieldCheckboxLayout) {
      bky_assertionFailure("`layout` is of type `\(type(of: layout))`. " +
        "Expected type `FieldCheckboxLayout`.")
      return CGSize.zero
    }

    if switchButtonSize == CGSize.zero {
      // UISwitch sizes never change. Measure it once and then never again.
      switchButtonSize = UISwitch().bounds.size
    }
    return switchButtonSize
  }
}
