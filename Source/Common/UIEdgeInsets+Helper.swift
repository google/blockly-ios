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
 Helper method for creating a `UIEdgeInsets` value, based on the `UIUserInterfaceLayoutDirection`
 of the system.

 - parameter top: The top edge inset
 - parameter leading: The leading edge inset. In LTR, this becomes the `left` value. In RTL, this
 becomes the `right` value.
 - parameter bottom: The bottom edge inset
 - parameter trailing: The leading edge inset. In LTR, this becomes the `right` value. In RTL, this
 becomes the `left` value.
 - returns: The `UIEdgeInsets` value
 */
internal func bky_UIEdgeInsetsMake(
  _ top: CGFloat, _ leading: CGFloat, _ bottom: CGFloat, _ trailing: CGFloat) -> UIEdgeInsets {

  if UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
    return UIEdgeInsetsMake(top, trailing, bottom, leading)
  } else {
    return UIEdgeInsetsMake(top, leading, bottom, trailing)
  }
}
