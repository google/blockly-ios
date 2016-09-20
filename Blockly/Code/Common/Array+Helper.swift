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
Helper extension methods for an `Array` holding `AnyObject` instances.
*/
extension Array where Element: AnyObject {
  // MARK: - Public

  /**
  Removes all occurrences of a given element in the array.

  - Parameter element: The element to remove
  */
  public mutating func bky_removeAllOccurrences(of element: Element) {
    self = self.filter({ $0 !== element })
  }

  /**
   Removes the first occurrence of a given object in the array, starting from index 0.

   - Parameter object: The object to remove
   - Returns: True if the element was found and removed. False if the element was not found.
   */
  public mutating func bky_removeFirstOccurrence(of element: Element) -> Bool {
    for i in 0 ..< self.count {
      if self[i] === element {
        remove(at: i)
        return true
      }
    }

    return false
  }
}
