/*
* Copyright 2015 Google Inc. All Rights Reserved.
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
 Returns the sum of two sizes.

 - parameter size1: The first size.
 - parameter size2: The second size.
 - returns: The sum of `size1` and `size2`.
 */
internal func + (size1: CGSize, size2: CGSize) -> CGSize {
  return CGSize(width: size1.width + size2.width, height: size1.height + size2.height)
}

/**
 Returns the difference of one size from another size.

 - parameter size1: The first size.
 - parameter size2: The second size.
 - returns: The difference of `size1` and `size2` (ie. `size1 - size2`).
 */
internal func - (size1: CGSize, size2: CGSize) -> CGSize {
  return CGSize(width: size1.width - size2.width, height: size1.height - size2.height)
}
