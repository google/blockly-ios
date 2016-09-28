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

/**
 Defines inset distances for views/layouts, that allows for both LTR and RTL layouts.

 - Note: To determine whether the current device is in LTR or RTL, this class uses
 `UIApplication.shared.userInterfaceLayoutDirection`.
 */
public typealias EdgeInsets = BKYEdgeInsets

extension EdgeInsets {
  /// The inset distance for the left edge.
  /// In LTR layouts, this value is equal to `self.leading`.
  /// In RTL layouts, this value is equal to `self.trailing`.
  public var left: CGFloat {
    return UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ?
      trailing : leading
  }

  /// The inset distance for the right edge.
  /// In LTR layouts, this value is equal to `self.trailing`.
  /// In RTL layouts, this value is equal to `self.leading`.
  public var right: CGFloat {
    return UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ?
      leading : trailing
  }

  /**
   Creates edge insets, with each inset value set to zero.
   */
  public init() {
    self.init(0, 0, 0, 0)
  }

  /**
   Creates edge insets, with given values for each edge.

   - Parameter top: Top edge inset
   - Parameter leading: Leading edge inset
   - Parameter bottom: Bottom edge inset
   - Parameter trailing: Trailing edge inset
   - Returns: A `BKYEdgeInsets`.
   */
  public init(_ top: CGFloat, _ leading: CGFloat, _ bottom: CGFloat, _ trailing: CGFloat) {
    self.top = top
    self.leading = leading
    self.bottom = bottom
    self.trailing = trailing
  }
}
