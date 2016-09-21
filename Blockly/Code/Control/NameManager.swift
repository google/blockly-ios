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
 Listener for events that occur on `NameManager`.
 */
@objc(BKYNameManagerListener)
public protocol NameManagerListener {
  /**
   Event that is fired when a `NameManager` instance has added a new name to its list.

   - Parameter nameManager: The `NameManager`
   - Parameter name: The name that was added
   */
  @objc optional func nameManager(_ nameManager: NameManager, didAddName name: String)

  /**
   Event that is fired when a `NameManager` instance has renamed a name to a different name.

   - Parameter nameManager: The `NameManager`
   - Parameter oldName: The old name
   - Parameter newName: The new name
   */
  @objc optional func nameManager(
    _ nameManager: NameManager, didRenameName oldName: String, toName newName: String)

  /**
   Event that is fired during a request to remove a name from a `NameManager` instance. If any
   listener returns `false` from this event, the request to remove the name is ignored.

   - Parameter nameManager: The `NameManager`
   - Parameter name: The name to potentially remove
   - Returns: `true` if the name should be removed, `false` otherwise.
   */
  @objc optional func nameManager(_ nameManager: NameManager, shouldRemoveName name: String) -> Bool

  /**
   Event that is fired when a `NameManager` instance has removed a name from its list.

   - Parameter nameManager: The `NameManager`
   - Parameter name: The name that was removed
   */
  @objc optional func nameManager(_ nameManager: NameManager, didRemoveName name: String)
}

/**
 Manager for handling variable and procedure names.

 Any names added to this manager are done so without case sensitivity.

 eg.
 ```
 let nameManager = NameManager()
 nameManager.addName("foo") // `nameManager.names` is now `["foo"]`
 nameManager.addName("bar") // `nameManager.names` is now `["foo", "bar"]`
 nameManager.addName("FOO") // `nameManager.names` is now `["FOO", "bar"]`
 nameManager.renameName("foo", toName: "newName") // `nameManager.names` is now `["newName", "bar"]`
 ```
 */
@objc(BKYNameManager)
public final class NameManager: NSObject {
  // MARK: - Static Properties

  /// Regular expression pattern with two groups.  The first lazily looks for any sequence of
  /// characters and the second looks for one or more numbers.
  /// e.g. foo2 -> (foo, 2),  f222 -> (f, 222))
  private static let REGULAR_EXPRESSION_PATTERN = "^(.*?)(\\d+)$"

  // MARK: - Properties

  /// Dictionary containing all names that have already been added to the manager. The key is
  /// a lowercase version of the name, while the value is the display name of the name
  /// (eg. ("foo bar", "Foo Bar"))
  private var _names = [String: String]()

  /// A list of all names that have been added to the manager
  public var names: [String] {
    return Array(_names.values)
  }

  /// The number of names that have been used
  public var count: Int {
    return _names.count
  }
  /// Listeners for events that occur on this instance
  public var listeners = WeakSet<NameManagerListener>()
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
   Adds a given name to the list of names. If the same lowercase version of the name already exists
   in the list, the name is updated to match this new given name.

   eg.
   ```
   let nameManager = NameManager()
   nameManager.addName("foo") // `nameManager.names` is now `["foo"]`
   nameManager.addName("FOO") // `nameManager.names` is now `["FOO"]`
   ```

   - Parameter name: The name to add.
   */
  public func addName(_ name: String) {
    let nameKey = keyForName(name)

    if let oldDisplayName = _names[nameKey] {
      // Name already exists in the list
      if oldDisplayName != name {
        // Update the display name for this variable name
        _names[nameKey] = name
        listeners.forEach {
          $0.nameManager?(self, didRenameName: oldDisplayName, toName: name)
        }
      }
    } else {
      _names[nameKey] = name
      listeners.forEach {
        $0.nameManager?(self, didAddName: name)
      }
    }
  }

  /**
   Renames a name within the list.

   If `oldName` does not exist, nothing happens and `false` is returned.
   If `oldName` exists, but `newName` is already in the list, the `newName` is applied to all

   - Parameter oldName: The old name
   - Parameter newName: The new name
   - Returns: `true` if `oldName` existed in the list and was renamed to `newName`. `false`
   otherwise.
   */
  @discardableResult
  public func renameName(_ oldName: String, to newName: String) -> Bool {
    let oldNameKey = keyForName(oldName)
    let newNameKey = keyForName(newName)

    guard let oldNameDisplay = _names[oldNameKey] else {
      return false
    }

    let previousDisplayNameForNewName = _names[newNameKey]
    _names[oldNameKey] = nil
    _names[newNameKey] = newName
    listeners.forEach {
      $0.nameManager?(self, didRenameName: oldNameDisplay, toName: newName)
    }

    if previousDisplayNameForNewName != nil {
      listeners.forEach {
        $0.nameManager?(self, didRenameName: previousDisplayNameForNewName!, toName: newName)
      }
    }

    return true
  }

  /**
   Attempts to remove a name from the list.

   NOTE: Any instance within `self.listeners` may cancel this request by implementing
   `nameManager(:, shouldRemoveName:)` and returning `false`.

   - Parameter name: The name to remove.
   - Returns: `true` if the name was found and removed. `false` otherwise.
   */
  @discardableResult
  public func requestRemovalForName(_ name: String) -> Bool {
    let nameKey = keyForName(name)

    if let displayName = _names[nameKey] {
      // Check from all listeners that this name can be removed
      let shouldRemoveName =
        !listeners.map({ $0.nameManager?(self, shouldRemoveName: displayName) ?? true })
        .contains(false)

      if shouldRemoveName {
        _names[nameKey] = nil
        listeners.forEach({ $0.nameManager?(self, didRemoveName: displayName) })
        return true
      }
    }

    return false
  }

  /**
   Clears the list of names.
   */
  public func clearNames() {
    let allNames = _names

    for (name, displayName) in allNames {
      _names[name] = nil
      listeners.forEach({ $0.nameManager?(self, didRemoveName: displayName) })
    }
  }

  /**
   Returns if a given name has already been added.

   - Parameter name: The `String` to look up.
   - Returns: `true` if a `name`'s has been added. `false` otherwise.
   */
  public func containsName(_ name: String) -> Bool{
    return _names[keyForName(name)] != nil
  }

  /**
   Returns whether two names are considered equal, according to the `NameManager`.

   - Parameter name1: The first name to compare
   - Parameter name2: The second name to compare
   - Returns: `true` if they are equal, `false` otherwise.
   */
  public func namesAreEqual(_ name1: String, _ name2: String) -> Bool {
    return keyForName(name1) == keyForName(name2)
  }

  /**
   Generates a unique name within the scope of `NameManager`, based on a given name.

   If the base name is already unique, its name is returned directly.
   If the base name is not already unique, this method will add a unique number to the end of the
   name or automatically increment the name's number if its suffix is already a number.

   e.g.
   ```
   let manager = NameManager()
   manager.generateUniqueName("foo", addToList: true) // Returns "foo"
   manager.generateUniqueName("foo", addToList: true) // Returns "foo2"
   manager.generateUniqueName("foo", addToList: true) // Returns "foo3"
   manager.generateUniqueName("Bar10", addToList: true) // Returns "Bar10"
   manager.generateUniqueName("Bar10", addToList: true) // Returns "Bar11"
   manager.generateUniqueName("Bar10", addToList: true) // Returns "Bar12"
   ```

   - Parameter name: The name upon which to base the unique name.
   - Parameter addToList: Whether to add the generated name to the used names list.
   - Returns: A unique name.
   */
  public func generateUniqueName(_ name: String, addToList: Bool) -> String {
    var uniqueName = name

    if containsName(uniqueName) {
      // Generate a new unique name
      var baseName = name // This will be the prefix part of the unique name
      var variableCount = 2 // This will be the suffix part of the unique name

      // Figure out if `name` is already made up of a text part and a number part (eg. "foo6")
      if let match = _regex.firstMatch(
        in: name, options: [], range: NSMakeRange(0, name.utf16.count))
        , match.numberOfRanges == 3 &&
          match.rangeAt(1).location != NSNotFound &&
          match.rangeAt(2).location != NSNotFound
      {
        if let textRange = bky_rangeFromNSRange(match.rangeAt(1), forString: name),
          let numberRange = bky_rangeFromNSRange(match.rangeAt(2), forString: name),
          let number = Int(name.substring(with: numberRange))
        {
          // `name` ends in a number. Use that (number + 1) as the variable counter
          baseName = name.substring(with: textRange)
          variableCount = number + 1
        }
      }

      repeat {
        // Continually generate names using the base name and an incremented variable count
        // until a unique one is found
        uniqueName = baseName + String(variableCount)
        variableCount += 1
      } while containsName(uniqueName)
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
  private func keyForName(_ name: String) -> String {
    return name.lowercased()
  }
}
