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
 A subclass of `UITextField` that allows for setting the padding around the text.
 */
public class InsetTextField: UITextField {
  // MARK: - Properties

  /// The amount of padding that should be added around the text
  public var insetPadding = EdgeInsets() {
    didSet {
      _uiEdgeInsetPadding = bky_UIEdgeInsetsMake(
        insetPadding.top, insetPadding.leading, insetPadding.bottom, insetPadding.trailing)
    }
  }

  /// The amount of padding that should be added around the text, irrespective of layout
  /// direction.
  private var _uiEdgeInsetPadding = UIEdgeInsetsZero

  // MARK: - Super

  public override func textRectForBounds(bounds: CGRect) -> CGRect {
    return UIEdgeInsetsInsetRect(bounds, _uiEdgeInsetPadding)
  }

  public override func editingRectForBounds(bounds: CGRect) -> CGRect {
    return UIEdgeInsetsInsetRect(bounds, _uiEdgeInsetPadding)
  }
}
