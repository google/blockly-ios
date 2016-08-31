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
public class FieldColorView: FieldView {
  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `FieldColorLayout`
  public var fieldColorLayout: FieldColorLayout? {
    return layout as? FieldColorLayout
  }

  /// The color button to render
  private lazy var button: UIButton = {
    let button = UIButton(type: .Custom)
    button.frame = self.bounds
    button.clipsToBounds = true
    button.layer.borderColor = UIColor.whiteColor().CGColor
    button.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    button.addTarget(self, action: #selector(didTapButton(_:)), forControlEvents: .TouchUpInside)
    return button
  }()

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    addSubview(button)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  public override func refreshView(
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
          fieldColorLayout.config.viewUnitFor(LayoutConfig.FieldColorButtonBorderWidth)
        button.layer.cornerRadius =
          fieldColorLayout.config.viewUnitFor(LayoutConfig.FieldCornerRadius)
        button.backgroundColor = fieldColorLayout.color
      }
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()

    button.backgroundColor = UIColor.clearColor()
  }

  // MARK: - Private

  private dynamic func didTapButton(sender: UIButton) {
    // Show the color picker
    let viewController = FieldColorPickerViewController()
    viewController.color = fieldColorLayout?.color
    viewController.delegate = self
    delegate?.fieldView(self,
                        requestedToPresentPopoverViewController: viewController, fromView: self)
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldColorView: FieldLayoutMeasurer {
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    if !(layout is FieldColorLayout) {
      bky_assertionFailure("`layout` is of type `\(layout.dynamicType)`. " +
        "Expected type `FieldColorLayout`.")
      return CGSizeZero
    }

    return layout.config.viewSizeFor(LayoutConfig.FieldColorButtonSize)
  }
}

// MARK: - FieldColorPickerViewControllerDelegate implementation

extension FieldColorView: FieldColorPickerViewControllerDelegate {
  public func fieldColorPickerViewController(
    viewController: FieldColorPickerViewController, didPickColor color: UIColor)
  {
    fieldColorLayout?.updateColor(color)
    viewController.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
  }
}
