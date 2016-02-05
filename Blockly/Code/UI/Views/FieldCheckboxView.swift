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

  /// Layout object to render
  public var fieldCheckboxLayout: FieldCheckboxLayout? {
    return layout as? FieldCheckboxLayout
  }

  /// The switch button (i.e. the "checkbox")
  private var switchButton: UISwitch!

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    switchButton = UISwitch()
    switchButton.tintColor = BlockLayout.sharedConfig.checkboxSwitchTintColour
    switchButton.onTintColor = BlockLayout.sharedConfig.checkboxSwitchOnTintColour
    switchButton.addTarget(self, action: "switchValueDidChange:", forControlEvents: .ValueChanged)
    addSubview(switchButton)
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func internalRefreshView(forFlags flags: LayoutFlag)
  {
    guard let layout = self.layout as? FieldCheckboxLayout else {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      self.switchButton.on = layout.fieldCheckbox.checked
    }
  }

  public override func internalPrepareForReuse() {
    self.switchButton.on = false
  }

  // MARK: - Private

  private dynamic func switchValueDidChange(sender: UISwitch) {
    guard let field = self.fieldCheckboxLayout?.fieldCheckbox else {
      return
    }

    field.checked = self.switchButton.on
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldCheckboxView: FieldLayoutMeasurer {
  private static var switchButtonSize = CGSizeZero

  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    if !(layout is FieldCheckboxLayout) {
      bky_assertionFailure("Cannot measure layout of type [\(layout.dynamicType.description)]. " +
        "Expected type [FieldCheckboxLayout].")
      return CGSizeZero
    }

    if switchButtonSize == CGSizeZero {
      // UISwitch sizes never change. Measure it once and then never again.
      switchButtonSize = UISwitch().bounds.size
    }
    return switchButtonSize
  }
}
