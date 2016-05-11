/*
 * Copyright 2016 Google Inc. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License")
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
 Listener protocol for events that occur on `NameManager`.
 */
@objc(BKYNameManagerListener)
public protocol NameManagerListener {
  /**
   Event that is fired if a given `NameManager`'s `usedNames` list has changed.

   - Parameter nameManager: The `NameManager` that has changed.
   */
  func nameManagerDidChangeUsedNames(nameManager: NameManager)
}

/**
 Manager for handling variable and procedure names.
 */
@objc(BKYNameManager)
public final class NameManager: NSObject {
  // MARK: - Static Properties

  /// Regular expression pattern with two groups.  The first lazily looks for any sequence of
  /// characters and the second looks for one or more numbers.
  /// e.g. foo2 -> (foo, 2),  f222 -> (f, 222))
  private static let REGULAR_EXPRESSION_PATTERN = "^(.*?)(\\d+)$"

  // MARK: - Properties

  /// Set containing all names that have already been used
  public private(set) var usedNames = Set<String>()
  /// The number of names that have been used
  public var count: Int {
    return usedNames.count
  }
  /// Listeners for events that occur on this instance
  public let listeners = WeakSet<NameManagerListener>()
  /// Regular expression used for generating unique names
  private let _regex: NSRegularExpression

  // MARK: - Initializers

  public override init() {
    let pattern = NameManager.REGULAR_EXPRESSION_PATTERN
    do {
      _regex = try NSRegularExpression(pattern: pattern, options: [])
    } catch let error as NSError {
      fatalError("Could not initialize regular expression [`\(pattern)`]: \(error)")
    }
    super.init()
  }

  // MARK: - Public

  /**
   Adds a lowercase version of a given name to the list of used names.

   - Parameter name: The name to add.
   */
  public func addName(name: String) {
    let variableName = keyForName(name)
    if !usedNames.contains(variableName) {
      usedNames.insert(variableName)
      sendDidChangeUsedNamesEvent()
    }
  }

  /**
   Remove a single name from the list of used names.

   - Parameter name: The name to remove.
   - Returns: True if the name was found. False, otherwise.
   */
  public func removeName(name: String) -> Bool {
    if usedNames.remove(keyForName(name)) != nil {
      sendDidChangeUsedNamesEvent()
      return true
    }
    return false
  }

  /**
   Clears the list of used names.
   */
  public func clearNames() {
    if usedNames.count > 0 {
      usedNames.removeAll()
      sendDidChangeUsedNamesEvent()
    }
  }

  /**
   Returns if a given name has already been used.

   - Parameter name: The `String` to look up.
   - Returns: True if `name`'s lowercase equivalent has been used. False, otherwise.
   */
  public func containsName(name: String) -> Bool{
    return usedNames.contains(keyForName(name))
  }

  /**
   Generates a unique, lowercase name within the scope of `NameManager`, based on a given
   name.

   If the base name is already unique, its lowercase name is returned directly.
   If the base name is not already unique, this method will add a unique number to the end of the
   name or automatically increment the name's number if its suffix is already a number.

   e.g.
   ```
   let manager = NameManager()
   manager.generateUniqueName("foo", addToList: true) // Returns "foo"
   manager.generateUniqueName("foo", addToList: true) // Returns "foo2"
   manager.generateUniqueName("foo", addToList: true) // Returns "foo3"
   manager.generateUniqueName("bar10", addToList: true) // Returns "bar10"
   manager.generateUniqueName("bar10", addToList: true) // Returns "bar11"
   manager.generateUniqueName("bar10", addToList: true) // Returns "bar12"
   ```

   - Parameter name: The name upon which to base the unique name.
   - Parameter addToList: Whether to add the generated name to the used names list.
   - Returns: A unique name.
   */
  public func generateUniqueName(name: String, addToList: Bool) -> String {
    var uniqueName = keyForName(name)

    if usedNames.contains(uniqueName) {
      // Generate a new unique name
      var baseName = uniqueName // This will be the prefix part of the unique name
      var variableCount = 2 // This will be the suffix part of the unique name

      // Figure out if `uniqueName` is already made up of a text part and a number part (eg. "foo6")
      if let match = _regex.firstMatchInString(
        uniqueName, options: [], range: NSMakeRange(0, uniqueName.utf16.count))
        where match.numberOfRanges == 3 &&
          match.rangeAtIndex(1).location != NSNotFound &&
          match.rangeAtIndex(2).location != NSNotFound
      {
        if let textRange = bky_rangeFromNSRange(match.rangeAtIndex(1), forString: uniqueName),
          numberRange = bky_rangeFromNSRange(match.rangeAtIndex(2), forString: uniqueName),
          number = Int(uniqueName.substringWithRange(numberRange))
        {
          // `uniqueName` ends in a number. Use that (number + 1) as the variable counter
          baseName = uniqueName.substringWithRange(textRange)
          variableCount = number + 1
        }
      }

      repeat {
        // Continually generate names using the base name and an incremented variable count
        // until a unique one is found
        uniqueName = baseName + String(variableCount)
        variableCount += 1
      } while usedNames.contains(uniqueName)
    }

    if addToList {
      addName(uniqueName)
    }

    return uniqueName
  }

  // MARK: - Private

  /**
   Returns a lowercase key for a given name.
   */
  private func keyForName(name: String) -> String {
    return name.lowercaseString
  }

  /**
   Calls `nameManagerDidChangeUsedNames(:)` on all `self.listeners`.
   */
  private func sendDidChangeUsedNamesEvent() {
    listeners.forEach {
      $0.nameManagerDidChangeUsedNames(self)
    }
  }
}
