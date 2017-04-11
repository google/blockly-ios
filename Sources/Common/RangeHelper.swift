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
 Convenience method for getting a `Range` object from a `NSRange` belonging to a given `String`.

 - parameter nsRange: The `NSRange` belonging to the `string`
 - parameter string: The `String`
 - returns: The corresponding `Range` for `string`, or nil if `nsRange` specified an invalid range.
 */
func bky_rangeFromNSRange(_ nsRange: NSRange, forString string: String) -> Range<String.Index>? {
  // Get the start/end indices within `string` based on `nsRange`
  if let fromUTF16 = string.utf16.index(string.utf16.startIndex,
                                     offsetBy: nsRange.location, limitedBy: string.utf16.endIndex),
    let toUTF16 = string.utf16.index(fromUTF16,
                                     offsetBy: nsRange.length, limitedBy: string.utf16.endIndex),
    let from = String.Index(fromUTF16, within: string),
    let to = String.Index(toUTF16, within: string)
  {
    return from ..< to
  }

  return nil
}
