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
 View for rendering a `FieldColorLayout`.
 */
@objc(BKYFieldColorView)
@objcMembers open class FieldColorView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldColorLayout`
  open var fieldColorLayout: FieldColorLayout? {
    return layout as? FieldColorLayout
  }

  /// The color button to render
  fileprivate lazy var button: UIButton = {
    let button = UIButton(type: .custom)
    button.frame = self.bounds
    button.clipsToBounds = true
    button.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    button.addTarget(self, action: #selector(didTapButton(_:)), for: .touchUpInside)
    return button
  }()

  // MARK: - Initializers

  /// Initializes the color field view.
  public required init() {
    super.init(frame: CGRect.zero)

    addSubview(button)
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
  
    guard let fieldColorLayout = self.fieldColorLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
        let button = self.button
        button.layer.borderWidth =
          fieldColorLayout.config.viewUnit(for: LayoutConfig.FieldColorButtonBorderWidth)
        button.layer.cornerRadius =
          fieldColorLayout.config.viewUnit(for: LayoutConfig.FieldCornerRadius)
        button.backgroundColor = fieldColorLayout.color
        button.layer.borderColor =
          fieldColorLayout.config.color(for: LayoutConfig.FieldColorButtonBorderColor)?.cgColor
      }
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    button.backgroundColor = UIColor.clear
  }

  // MARK: - Private

  @objc fileprivate dynamic func didTapButton(_ sender: UIButton) {
    // Show the color picker
    let viewController = FieldColorPickerViewController()
    viewController.color = fieldColorLayout?.color
    viewController.delegate = self
    popoverDelegate?.layoutView(self,
                                requestedToPresentPopoverViewController: viewController,
                                fromView: self,
                                presentationDelegate: nil)
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldColorView: FieldLayoutMeasurer {
  public static func measureLayout(_ layout: FieldLayout, scale: CGFloat) -> CGSize {
    if !(layout is FieldColorLayout) {
      bky_assertionFailure("`layout` is of type `\(type(of: layout))`. " +
        "Expected type `FieldColorLayout`.")
      return CGSize.zero
    }

    var size = layout.config.viewSize(for: LayoutConfig.FieldColorButtonSize)
    size.height = max(size.height, layout.config.viewUnit(for: LayoutConfig.FieldMinimumHeight))
    return size
  }
}

// MARK: - FieldColorPickerViewControllerDelegate implementation

extension FieldColorView: FieldColorPickerViewControllerDelegate {
  public func fieldColorPickerViewController(
    _ viewController: FieldColorPickerViewController, didPickColor color: UIColor)
  {
    EventManager.shared.groupAndFireEvents {
      fieldColorLayout?.updateColor(color)
      popoverDelegate?.layoutView(
        self, requestedToDismissPopoverViewController: viewController, animated: true)
    }
  }
}
