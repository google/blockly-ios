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
@testable import Blockly
import XCTest

/** Tests for the `TranslationManager` class. */
class TranslationManagerTest: XCTestCase {

  var _translationManager: TranslationManager!
  var _bundle: Bundle!

  // MARK: - Setup

  override func setUp() {
    _translationManager = TranslationManager()
    _bundle = Bundle(for: type(of: self))
  }

  // MARK: - Load Translations

  func testLoadTranslationsFromJSON_simple() {
    BKYAssertDoesNotThrow {
      try _translationManager.loadTranslations(
        withPrefix: "bky_", jsonPath: "i18n_translations1.json", bundle: _bundle)
    }

    // Since the manager was loaded with a prefix, all the original keys in the JSON file should
    // return `nil`
    XCTAssertNil(_translationManager.translation(forKey: "some_value"))
    XCTAssertNil(_translationManager.translation(forKey: "VALUE1"))
    XCTAssertNil(_translationManager.translation(forKey: "@metadata"))

    // Check values with the prefixed keys
    XCTAssertEqual("This is value #1", _translationManager.translation(forKey: "bky_VALUE1"))
    XCTAssertEqual("This is some value", _translationManager.translation(forKey: "bky_some_value"))

    // Metadata is always ignored
    XCTAssertNil(_translationManager.translation(forKey: "bky_@metadata"))
  }

  func testLoadTranslationsFromJSON_badPath() {
    BKYAssertThrow(errorType: BlocklyError.self) {
      try _translationManager.loadTranslations(withPrefix: "", jsonPath: "no_file")
    }
  }

  func testLoadTranslationsFromJSON_overwriteValues() {
    BKYAssertDoesNotThrow {
      try _translationManager.loadTranslations(
        withPrefix: "prefix_", jsonPath: "i18n_translations1.json", bundle: _bundle)
      try _translationManager.loadTranslations(
        withPrefix: "prefix_", jsonPath: "i18n_translations2.json", bundle: _bundle)
    }

    // Check values with the prefixed keys
    XCTAssertEqual(
      "Overwrite value 1", _translationManager.translation(forKey: "prefix_VALUE1"))
    XCTAssertEqual(
      "Overwrite value 2", _translationManager.translation(forKey: "prefix_some_value"))
  }

  func testLoadTranslationsFromMemory_simple() {
    _translationManager.loadTranslations([
      "abc_test": "some translation",
    ])

    XCTAssertEqual("some translation", _translationManager.translation(forKey: "abc_test"))
  }

  func testLoadTranslationsFromMemory_overwriteValues() {
    _translationManager.loadTranslations([
      "": "some translation",
      ])
    _translationManager.loadTranslations([
      "": "overwritten translation",
      ])

    XCTAssertEqual("overwritten translation", _translationManager.translation(forKey: ""))
  }

  // MARK: - Load Synonyms

  func testLoadSynonymsFromFile_simple() {
    BKYAssertDoesNotThrow {
      try _translationManager.loadTranslations(
        withPrefix: "bky_", jsonPath: "i18n_translations1.json", bundle: _bundle)

      try _translationManager.loadSynonyms(
        withPrefix: "bky_", jsonPath: "i18n_synonyms1.json", bundle: _bundle)
    }

    // Since the manager was loaded with a prefix, all the original keys in the JSON file should
    // return `nil`
    XCTAssertNil(_translationManager.translation(forKey: "reference_SOME_vALue"))
    XCTAssertNil(_translationManager.translation(forKey: "reference_VALUE1"))

    // Check values with the prefixed keys
    XCTAssertEqual(
      "This is value #1", _translationManager.translation(forKey: "bky_reference_VALUE1"))
    XCTAssertEqual(
      "This is some value", _translationManager.translation(forKey: "bky_reference_SOME_vALue"))
  }

  func testLoadTranslationsFromFile_badPath() {
    BKYAssertThrow(errorType: BlocklyError.self) {
      try _translationManager.loadSynonyms(withPrefix: "", jsonPath: "no_file")
    }
  }

  func testLoadSynonymsFromFile_overwriteValues() {
    BKYAssertDoesNotThrow {
      try _translationManager.loadTranslations(
        withPrefix: "bky_", jsonPath: "i18n_translations1.json", bundle: _bundle)

      try _translationManager.loadSynonyms(
        withPrefix: "bky_", jsonPath: "i18n_synonyms1.json", bundle: _bundle)
      try _translationManager.loadSynonyms(
        withPrefix: "bky_", jsonPath: "i18n_synonyms2.json", bundle: _bundle)
    }

    // Check values with the prefixed keys
    XCTAssertEqual(
      "This is some value", _translationManager.translation(forKey: "bky_reference_VALUE1"))
    XCTAssertEqual(
      "This is value #1", _translationManager.translation(forKey: "bky_reference_SOME_vALue"))
  }

  func testLoadSynonymsFromFile_differentPrefixes() {
    BKYAssertDoesNotThrow {
      try _translationManager.loadTranslations(
        withPrefix: "\"\"", jsonPath: "i18n_translations1.json", bundle: _bundle)

      try _translationManager.loadSynonyms(
        withPrefix: "\"\"", jsonPath: "i18n_synonyms1.json", bundle: _bundle)

      // Load synonyms with a different prefix. These should have no effect on what's been loaded
      try _translationManager.loadSynonyms(
        withPrefix: "", jsonPath: "i18n_synonyms2.json", bundle: _bundle)
    }

    // Check values with the prefixed keys
    XCTAssertEqual("This is value #1",
                   _translationManager.translation(forKey: "\"\"reference_VALUE1"))
  }

  func testLoadSynonymsFromMemory_simple() {
    _translationManager.loadTranslations([
      "abc_test": "some translation",
      ])
    _translationManager.loadSynonyms([
      "synonym": "abc_test",
      ])

    XCTAssertEqual("some translation", _translationManager.translation(forKey: "synonym"))
  }

  func testLoadSynonymsFromMemory_overwriteValues() {
    _translationManager.loadTranslations([
      "abc_test": "some translation",
      "translation2": "another translation"
      ])
    _translationManager.loadSynonyms([
      "synonym": "abc_test",
      ])
    _translationManager.loadSynonyms([
      "synonym": "translation2",
      ])

    XCTAssertEqual("another translation", _translationManager.translation(forKey: "synonym"))
  }

  // MARK: - Get Translations

  func testTranslation_simple() {
    _translationManager.loadTranslations([
      "KeY": "Translation",
      ])

    XCTAssertEqual("Translation", _translationManager.translation(forKey: "KeY"))
    XCTAssertEqual("Translation", _translationManager.translation(forKey: "key"))
    XCTAssertEqual("Translation", _translationManager.translation(forKey: "KEY"))
    XCTAssertEqual("Translation", _translationManager.translation(forKey: "kEy"))
  }

  func testTranslation_noKey() {
    XCTAssertNil(_translationManager.translation(forKey: "key"))
  }

  func testTranslation_synonym() {
    _translationManager.loadTranslations([
      "somekey": "Some key",
      ])
    _translationManager.loadSynonyms([
      "ref_somekey": "SOMEKEY",
    ])

    XCTAssertEqual("Some key", _translationManager.translation(forKey: "ref_somekey"))
    XCTAssertEqual("Some key", _translationManager.translation(forKey: "REF_SOMEKEY"))
    XCTAssertEqual("Some key", _translationManager.translation(forKey: "ref_SOMEKEY"))
  }

  func testTranslation_synonymWithNoTranslation() {
    _translationManager.loadSynonyms([
      "ref_somekey": "SOMEKEY",
      ])

    // There isn't a "SOMEKEY" translation key, so this should return `nil`
    XCTAssertNil(_translationManager.translation(forKey: "ref_somekey"))
  }

  func testTranslation_synonymRecursion() {
    _translationManager.loadTranslations([
      "mainkey": "Translation",
      ])
    _translationManager.loadSynonyms([
      "ref1": "mainkey",
      "ref2": "ref1"
      ])

    XCTAssertEqual("Translation", _translationManager.translation(forKey: "mainkey"))
    XCTAssertEqual("Translation", _translationManager.translation(forKey: "ref1"))
    // Synonym recursion isn't supported, so this should return `nil`
    XCTAssertNil(_translationManager.translation(forKey: "ref2"))
  }
}
