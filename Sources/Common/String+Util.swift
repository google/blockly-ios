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
 Contains generic utility methods for `String`.
 */
extension String {
  /**
   Returns a new string in which all occurrences of characters inside a target set are removed from
   the receiver string.

   - parameter invalidCharacters: The set representing all characters that should be removed.
   - returns: A new string in which all occurrences of characters inside `characterSet` are removed.
   */
  public func bky_removingOccurrences(ofCharacterSet invalidCharacters: CharacterSet) -> String {
    return components(separatedBy: invalidCharacters).joined(separator: "")
  }
}
