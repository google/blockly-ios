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
 View for rendering a `FieldColourLayout`.
 */
@objc(BKYFieldColourView)
public class FieldColourView: FieldView {
  // MARK: - Properties

  /// The `FieldColour` backing this view
  public var fieldColour: FieldColour? {
    return fieldLayout?.field as? FieldColour
  }

  /// The colour button to render
  private var button: UIButton!

  // MARK: - Initializers

  public required init() {
    self.button = UIButton(type: .Custom)
    super.init(frame: CGRectZero)

    button.frame = self.bounds
    button.clipsToBounds = true
    button.layer.borderColor = UIColor.whiteColor().CGColor
    button.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    button.addTarget(self, action: "didTapButton:", forControlEvents: .TouchUpInside)
    addSubview(button)
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func internalRefreshView(forFlags flags: LayoutFlag)
  {
    guard let layout = self.fieldLayout where layout.field is FieldColour else {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      self.button.layer.borderWidth =
        layout.config.viewUnitFor(LayoutConfig.FieldColourButtonBorderWidth)
      self.button.layer.cornerRadius = layout.config.viewUnitFor(LayoutConfig.FieldCornerRadius)
      self.button.backgroundColor = self.fieldColour?.colour
    }
  }

  public override func internalPrepareForReuse() {
    self.button.backgroundColor = UIColor.clearColor()
  }

  // MARK: - Private

  private dynamic func didTapButton(sender: UIButton) {
    guard let parentBlockView = self.parentBlockView else {
      return
    }

    // Show the colour picker
    let viewController = FieldColourPickerViewController()
    viewController.fieldColour = self.fieldColour
    viewController.delegate = self
    parentBlockView.requestToPresentPopoverViewController(viewController, fromView: self)
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldColourView: FieldLayoutMeasurer {
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    if !(layout.field is FieldColour) {
      bky_assertionFailure("`layout.field` is of type `(layout.field.dynamicType)`. " +
        "Expected type `FieldColour`.")
      return CGSizeZero
    }

    return layout.config.viewSizeFor(LayoutConfig.FieldColourButtonSize)
  }
}

// MARK: - FieldColourPickerViewControllerDelegate implementation

extension FieldColourView: FieldColourPickerViewControllerDelegate {
  public func fieldColourPickerViewController(
    viewController: FieldColourPickerViewController, didPickColour colour: UIColor)
  {
    self.fieldColour?.colour = colour
    viewController.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
  }
}
