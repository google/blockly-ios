/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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
 Object responsible for managing message strings within Blockly.

 `MessageManager` stores messages that are accessible by a unique key.
 It also allows the ability to store "synonym" keys, that map back to an existing message key,
 as another way to access an existing message.

 Here is an example of `MessageManager` in use:
 ```
 let manager = MessageManager.shared
 
 // Add a message for "LISTS_INLIST"
 manager.loadMessages(["LISTS_INLIST": "in list"])

 // Set synonyms of "LISTS_INLIST"
 manager.loadSynonyms(["LISTS_GET_INDEX_INPUT_IN_LIST": "LISTS_INLIST"])
 manager.loadSynonyms(["LISTS_SET_INDEX_INPUT_IN_LIST": "LISTS_INLIST"])

 manager.message(forKey: "LISTS_INLIST")                    // Returns "in list"
 manager.message(forKey: "LISTS_GET_INDEX_INPUT_IN_LIST")   // Returns "in list"
 manager.message(forKey: "LISTS_SET_INDEX_INPUT_IN_LIST")   // Returns "in list"
 ```

 This class is designed as a singleton instance, accessible via `MessageManager.shared`.
 */
@objc(BKYMessageManager)
public class MessageManager: NSObject {
  // MARK: - Properties

  /// Shared instance.
  public static var shared: MessageManager = {
    let manager = MessageManager()
    let bundle = Bundle(for: MessageManager.self)

    // Load default files, and prefix all values with "bky_"
    do {
      try manager.loadMessages(
        withPrefix: "bky_", jsonPath: "bky_constants.json", bundle: bundle)
      try manager.loadMessages(
        withPrefix: "bky_", jsonPath: "bky_messages.json", bundle: bundle)
      try manager.loadSynonyms(withPrefix: "bky_", jsonPath: "bky_synonyms.json", bundle: bundle)
    } catch let error {
      bky_debugPrint("Could not load default files for MessageManager: \(error)")
    }

    return manager
  }()

  /// Dictionary of message keys mapped to message values.
  fileprivate var _messages = [String: String]()

  /// Dictionary of synonym keys mapped to message keys.
  fileprivate var _synonyms = [String: String]()

  // MARK: - Initializers

  /**
   A singleton instance for this class is accessible via `MessageManager.shared.`
   */
  internal override init() {
  }

  // MARK: - Loading Data

  /**
   Loads messages from a file containing a JSON object, where each object value is a
   message key mapped to a message value. When a message is stored, each key is
   automatically prefixed with the `prefix` parameter passed into the method.

   For example, assume a `messages.json` file that contains the following data:
   ```
   {
     "GREETING": "Welcome",
     "TODAY": "Today"
   }
   ```

   Here's how this file would be loaded and accessed in the manager:
   ```
   let manager = MessageManager.shared
   try manager.loadMessages(withPrefix: "PREFIX_", jsonPath: "messages.json")

   manager.message(forKey: "PREFIX_GREETING")  // Returns "Welcome"
   manager.message(forKey: "GREETING")         // Returns `nil` since there is no prefix
   ```

   - note: Message keys are case-insensitive. Any existing message is overwritten by
   any message in the given file with a duplicate key.
   - parameter prefix: The prefix to automatically add to every message key.
   - parameter jsonPath: Path to file containing a JSON object of message keys mapped to message
   values.
   - parameter bundle: [Optional] If specified, the bundle to use when locating `jsonPath`.
   If `nil` is specified (the default value), `Bundle.main` is used.
   */
  public func loadMessages(
    withPrefix prefix: String, jsonPath: String, bundle: Bundle? = nil) throws {

    let aBundle = bundle ?? Bundle.main
    guard let path = aBundle.path(forResource: jsonPath, ofType: nil) else {
      throw BlocklyError(.fileNotFound, "Could not find \"\(jsonPath)\" in bundle [\(aBundle)].")
    }

    let jsonString = try String(contentsOfFile: path, encoding: String.Encoding.utf8)

    let json = try JSONHelper.makeJSONDictionary(string: jsonString)

    for (key, value) in json {
      if key == "@metadata" {
        // Skip this value.
      } else if let stringValue = value as? String {
        // Store the message, but keyed with the given prefix
        _messages[(prefix + key).lookupKey()] = stringValue
      } else {
        bky_debugPrint("Unrecognized value type ('\(type(of: value))') for key ('\(key)').")
      }
    }
  }

  /**
   Loads messages from a given dictionary, where each pair is a message key mapped
   to a message value.

   - note: Message keys are case-insensitive. Any existing message is overwritten by
   any message in the given dictionary with a duplicate key.
   - parameter messages: Dictionary of message keys mapped to message values.
   */
  public func loadMessages(_ messages: [String: String]) {
    // Overwrite existing messages
    for (key, value) in messages {
      _messages[key.lookupKey()] = value
    }
  }

  /**
   Loads synonyms from a file containing a JSON object, where each object value is a synonym key
   mapped to a message key. When a synonym is stored, both the synonym key and message
   key are automatically prefixed with the `prefix` parameter passed into the method.

   For example, assume a `synonyms.json` file that contains the following data:
   ```
   {
     "MAIN_SCREEN_TITLE": "MAIN_TITLE",
     "ALTERNATE_SCREEN_TITLE": "MAIN_TITLE"
   }
   ```

   And also a `messages.json` file that contains the following data:
   ```
   {
     "MAIN_TITLE": "Welcome",
   }
   ```

   Here's how these files would be loaded and accessed in the manager:
   ```
   let manager = MessageManager.shared
   try manager.loadMessages(withPrefix: "PREFIX_", jsonPath: "messages.json")
   try manager.loadSynonyms(withPrefix: "PREFIX_", jsonPath: "synonyms.json")

   // All of these calls return "Welcome"
   manager.message(forKey: "PREFIX_MAIN_SCREEN_TITLE")
   manager.message(forKey: "PREFIX_ALTERNATE_SCREEN_TITLE")
   manager.message(forKey: "PREFIX_TITLE")

   // All of these calls return `nil`
   manager.message(forKey: "MAIN_SCREEN_TITLE")
   manager.message(forKey: "ALTERNATE_SCREEN_TITLE")
   manager.message(forKey: "TITLE")
   ```

   - note: Synonym keys are case-insensitive. Any existing synonym is overwritten by
   any synonym in the given file with a duplicate key.
   - parameter prefix: The prefix to automatically add to every synonym key and message key.
   - parameter jsonPath: Path to file containing a JSON object of synonym keys mapped to
   message keys.
   - parameter bundle: [Optional] If specified, the bundle to use when locating `jsonPath`.
   If `nil` is specified (the default value), `Bundle.main` is used.
   */
  public func loadSynonyms(
    withPrefix prefix: String, jsonPath: String, bundle: Bundle? = nil) throws {

    let aBundle = bundle ?? Bundle.main
    guard let path = aBundle.path(forResource: jsonPath, ofType: nil) else {
      throw BlocklyError(.fileNotFound, "Could not find \"\(jsonPath)\" in bundle [\(aBundle)].")
    }

    let jsonString = try String(contentsOfFile: path, encoding: String.Encoding.utf8)

    let json = try JSONHelper.makeJSONDictionary(string: jsonString)

    for (key, value) in json {
      if let stringValue = value as? String {
        // Store the synonym with the given prefix
        _synonyms[(prefix + key).lookupKey()] = (prefix + stringValue).lookupKey()
      } else {
        bky_debugPrint("Unrecognized value type ('\(type(of: value))') for key ('\(key)').")
      }
    }
  }

  /**
   Loads synonyms from a given dictionary, where each pair is a synonym key mapped to a message
   key.

   - note: Synonym keys are case-insensitive. Any existing synonym is overwritten by
   any synonym in the given file with a duplicate key.
   - parameter synonyms: Dictionary of synonym keys mapped to message keys.
   */
  public func loadSynonyms(_ synonyms: [String: String]) {
    // Overwrite existing synonym values
    for (key, value) in synonyms {
      _synonyms[key.lookupKey()] = value.lookupKey()
    }
  }

  // MARK: - Message Retrieval

  /**
   Returns a message value for a given message key or synonym key. Lookup prioritizes
   finding the key in the message table first, before looking in the synonym table.
   If no value could be found for the key from either the message table or synonym table,
   then `nil` is returned.

   - note: Key lookups are case-insensitive.
   - parameter key: A message key or synonym key.
   - returns: The message for the given `key`, if it exists in the message table or synonym table.
   If the `key` could not be found, then `nil` is returned.
   */
  public func message(forKey key: String) -> String? {
    let lookupKey = key.lookupKey()

    if let value = _messages[lookupKey] {
      return value
    } else if let synonym = _synonyms[lookupKey],
      let value = _messages[synonym] {
      return value
    }
    return nil
  }
}

fileprivate extension String {
  func lookupKey() -> String {
    // Simply lookup by lowercasing all keys
    return self.lowercased()
  }
}
