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
 Object responsible for managing translation strings within Blockly.

 `TranslationManager` stores translation messages that are accessible by a unique key.
 It also allows the ability to store "synonym" keys, that map back to an existing translation key,
 as another way to access an existing translation.

 Here is an example of `TranslationManager` in use:
 ```
 let manager = TranslationManager.shared
 
 // Add a translation for "LISTS_INLIST"
 manager.loadTranslations(["LISTS_INLIST": "in list"])

 // Set synonyms of "LISTS_INLIST"
 manager.loadSynonyms(["LISTS_GET_INDEX_INPUT_IN_LIST": "LISTS_INLIST"])
 manager.loadSynonyms(["LISTS_SET_INDEX_INPUT_IN_LIST": "LISTS_INLIST"])

 manager.translation(forKey: "LISTS_INLIST")                    // Returns "in list"
 manager.translation(forKey: "LISTS_GET_INDEX_INPUT_IN_LIST")   // Returns "in list"
 manager.translation(forKey: "LISTS_SET_INDEX_INPUT_IN_LIST")   // Returns "in list"
 ```

 This class is designed as a singleton instance, accessible via `TranslationManager.shared`.
 */
@objc(BKYTranslationManager)
public class TranslationManager: NSObject {
  // MARK: - Properties

  /// Shared instance.
  public static var shared: TranslationManager = {
    let manager = TranslationManager()
    let bundle = Bundle(for: TranslationManager.self)

    // Load default files, and prefix all values with "bky_"
    do {
      try manager.loadTranslations(
        withPrefix: "bky_", jsonPath: "bky_constants.json", bundle: bundle)
      try manager.loadTranslations(
        withPrefix: "bky_", jsonPath: "bky_messages.json", bundle: bundle)
      try manager.loadSynonyms(withPrefix: "bky_", jsonPath: "bky_synonyms.json", bundle: bundle)
    } catch let error {
      bky_debugPrint("Could not load default files for TranslationManager: \(error)")
    }

    return manager
  }()

  /// Dictionary of translation keys mapped to translation values.
  fileprivate var _translations = [String: String]()

  /// Dictionary of synonym keys mapped to message keys.
  fileprivate var _synonyms = [String: String]()

  // MARK: - Initializers

  /**
   A singleton instance for this class is accessible via `TranslationManager.shared.`
   */
  internal override init() {
  }

  // MARK: - Loading Data

  /**
   Loads translation messages from a file containing a JSON object, where each object value is a
   translation key mapped to a translation message. When a translation is stored, each key is
   automatically prefixed with the `prefix` parameter passed into the method.

   For example, assume a `translations.json` file that contains the following data:
   ```
   {
     "GREETING": "Welcome",
     "TODAY": "Today"
   }
   ```

   Here's how these translations would be loaded and accessed in the manager:
   ```
   let manager = TranslationManager.shared
   try manager.loadTranslations(withPrefix: "PREFIX_", jsonPath: "translations.json")

   manager.translation(forKey: "PREFIX_GREETING")  // Returns "Welcome"
   manager.translation(forKey: "GREETING")         // Returns `nil` since there is no prefix
   ```

   - note: Translation keys are case-insensitive. Any existing translation is overwritten by
   any translation in the given file with a duplicate key.
   - parameter prefix: The prefix to automatically add to every translation key.
   - parameter jsonPath: Path to file containing a JSON object of translation messages mapped to
   unique keys.
   - parameter bundle: [Optional] If specified, the bundle to use when locating `jsonPath`.
   If `nil` is specified, it defaults to using `Bundle.main`.
   */
  public func loadTranslations(
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
        // Store the translation, but keyed with the given prefix
        _translations[(prefix + key).lookupKey()] = stringValue
      } else {
        bky_debugPrint("Unrecognized value type ('\(type(of: value))') for key ('\(key)').")
      }
    }
  }

  /**
   Loads translation messages from a given dictionary, where each pair is a translation key mapped
   to a translation message.

   - note: Translation keys are case-insensitive. Any existing translation is overwritten by
   any translation in the given dictionary with a duplicate key.
   - parameter translations: Dictionary of translation keys mapped to translation messages.
   */
  public func loadTranslations(_ translations: [String: String]) {
    // Overwrite existing translations
    for (key, value) in translations {
      _translations[key.lookupKey()] = value
    }
  }

  /**
   Loads synonyms from a file containing a JSON object, where each object value is a synonym key
   mapped to a translation key. When a synonym is stored, both the synonym key and translation
   key are automatically prefixed with the `prefix` parameter passed into the method.

   For example, assume a `synonyms.json` file that contains the following data:
   ```
   {
     "MAIN_SCREEN_TITLE": "MAIN_TITLE",
     "ALTERNATE_SCREEN_TITLE": "MAIN_TITLE"
   }
   ```

   And also a `translations.json` file that contains the following data:
   ```
   {
     "MAIN_TITLE": "Welcome",
   }
   ```

   Here's how these synonyms would be loaded and accessed in the manager:
   ```
   let manager = TranslationManager.shared
   try manager.loadTranslations(withPrefix: "PREFIX_", jsonPath: "translations.json")
   try manager.loadSynonyms(withPrefix: "PREFIX_", jsonPath: "synonyms.json")

   // All of these calls return "Welcome"
   manager.translation(forKey: "PREFIX_MAIN_SCREEN_TITLE")
   manager.translation(forKey: "PREFIX_ALTERNATE_SCREEN_TITLE")
   manager.translation(forKey: "PREFIX_TITLE")

   // All of these calls return `nil`
   manager.translation(forKey: "MAIN_SCREEN_TITLE")
   manager.translation(forKey: "ALTERNATE_SCREEN_TITLE")
   manager.translation(forKey: "TITLE")
   ```

   - note: Synonym keys are case-insensitive. Any existing synonym is overwritten by
   any synonym in the given file with a duplicate key.
   - parameter prefix: The prefix to automatically add to every synonym and translation key pair.
   - parameter jsonPath: Path to file containing a JSON object of synonym keys mapped to
   translation keys.
   - parameter bundle: [Optional] If specified, the bundle to use when locating `jsonPath`.
   If `nil` is specified, it defaults to using `Bundle.main`.
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
   Loads synonyms from a given dictionary, where each pair is a synonym key mapped to a translation
   key.

   - note: Synonym keys are case-insensitive. Any existing synonym is overwritten by
   any synonym in the given file with a duplicate key.
   - parameter synonyms: Dictionary of synonym keys mapped to translation keys.
   */
  public func loadSynonyms(_ synonyms: [String: String]) {
    // Overwrite existing synonym values
    for (key, value) in synonyms {
      _synonyms[key.lookupKey()] = value.lookupKey()
    }
  }

  // MARK: - Translation

  /**
   Returns a message translation for a given translation or synonym key. Lookup prioritizes
   finding the key in the translation table first, before looking in the synonyms table.
   If no message could be found for the key from either the translation or synonym tables,
   then `nil` is returned.

   - note: Key lookups are case-insensitive.
   - parameter key: A translation or synonym key.
   - returns: The message for the given `key`, if it exists in the translation or synonym tables.
   If the `key` could not be found, then `nil` is returned.
  */
  public func translation(forKey key: String) -> String? {
    let lookupKey = key.lookupKey()

    if let value = _translations[lookupKey] {
      return value
    } else if let synonym = _synonyms[lookupKey],
      let value = _translations[synonym] {
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
