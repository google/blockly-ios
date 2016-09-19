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
 */
public struct EdgeInsets {
  public var top: CGFloat
  public var leading: CGFloat
  public var bottom: CGFloat
  public var trailing: CGFloat

  public var left: CGFloat {
    return UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ?
      trailing : leading
  }

  public var right: CGFloat {
    return UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ?
      leading : trailing
  }

  public init() {
    self.init(0, 0, 0, 0)
  }

  public init(_ top: CGFloat, _ leading: CGFloat, _ bottom: CGFloat, _ trailing: CGFloat) {
    self.top = top
    self.leading = leading
    self.bottom = bottom
    self.trailing = trailing
  }
}
