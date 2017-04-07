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

/** Tests for the `MessageManager` class. */
class MessageManagerTest: XCTestCase {

  var _messageManager: MessageManager!
  var _bundle: Bundle!

  // MARK: - Setup

  override func setUp() {
    _messageManager = MessageManager()
    _bundle = Bundle(for: type(of: self))
  }

  // MARK: - Load Messages

  func testLoadMessagesFromJSON_simple() {
    BKYAssertDoesNotThrow {
      try _messageManager.loadMessages(
        withPrefix: "bky_", jsonPath: "i18n_messages1.json", bundle: _bundle)
    }

    // Since the manager was loaded with a prefix, all the original keys in the JSON file should
    // return `nil`
    XCTAssertNil(_messageManager.message(forKey: "some_value"))
    XCTAssertNil(_messageManager.message(forKey: "VALUE1"))
    XCTAssertNil(_messageManager.message(forKey: "@metadata"))

    // Check values with the prefixed keys
    XCTAssertEqual("This is value #1", _messageManager.message(forKey: "bky_VALUE1"))
    XCTAssertEqual("This is some value", _messageManager.message(forKey: "bky_some_value"))

    // Metadata is always ignored
    XCTAssertNil(_messageManager.message(forKey: "bky_@metadata"))
  }

  func testLoadMessagesFromJSON_badPath() {
    BKYAssertThrow(errorType: BlocklyError.self) {
      try _messageManager.loadMessages(withPrefix: "", jsonPath: "no_file")
    }
  }

  func testLoadMessagesFromJSON_overwriteValues() {
    BKYAssertDoesNotThrow {
      try _messageManager.loadMessages(
        withPrefix: "prefix_", jsonPath: "i18n_messages1.json", bundle: _bundle)
      try _messageManager.loadMessages(
        withPrefix: "prefix_", jsonPath: "i18n_messages2.json", bundle: _bundle)
    }

    // Check values with the prefixed keys
    XCTAssertEqual(
      "Overwrite value 1", _messageManager.message(forKey: "prefix_VALUE1"))
    XCTAssertEqual(
      "Overwrite value 2", _messageManager.message(forKey: "prefix_some_value"))
  }

  func testLoadMessagesFromMemory_simple() {
    _messageManager.loadMessages([
      "abc_test": "some translation",
    ])

    XCTAssertEqual("some translation", _messageManager.message(forKey: "abc_test"))
  }

  func testLoadMessagesFromMemory_overwriteValues() {
    _messageManager.loadMessages([
      "": "some translation",
      ])
    _messageManager.loadMessages([
      "": "overwritten translation",
      ])

    XCTAssertEqual("overwritten translation", _messageManager.message(forKey: ""))
  }

  // MARK: - Load Synonyms

  func testLoadSynonymsFromFile_simple() {
    BKYAssertDoesNotThrow {
      try _messageManager.loadMessages(
        withPrefix: "bky_", jsonPath: "i18n_messages1.json", bundle: _bundle)

      try _messageManager.loadSynonyms(
        withPrefix: "bky_", jsonPath: "i18n_synonyms1.json", bundle: _bundle)
    }

    // Since the manager was loaded with a prefix, all the original keys in the JSON file should
    // return `nil`
    XCTAssertNil(_messageManager.message(forKey: "reference_SOME_vALue"))
    XCTAssertNil(_messageManager.message(forKey: "reference_VALUE1"))

    // Check values with the prefixed keys
    XCTAssertEqual(
      "This is value #1", _messageManager.message(forKey: "bky_reference_VALUE1"))
    XCTAssertEqual(
      "This is some value", _messageManager.message(forKey: "bky_reference_SOME_vALue"))
  }

  func testLoadMessagesFromFile_badPath() {
    BKYAssertThrow(errorType: BlocklyError.self) {
      try _messageManager.loadSynonyms(withPrefix: "", jsonPath: "no_file")
    }
  }

  func testLoadSynonymsFromFile_overwriteValues() {
    BKYAssertDoesNotThrow {
      try _messageManager.loadMessages(
        withPrefix: "bky_", jsonPath: "i18n_messages1.json", bundle: _bundle)

      try _messageManager.loadSynonyms(
        withPrefix: "bky_", jsonPath: "i18n_synonyms1.json", bundle: _bundle)
      try _messageManager.loadSynonyms(
        withPrefix: "bky_", jsonPath: "i18n_synonyms2.json", bundle: _bundle)
    }

    // Check values with the prefixed keys
    XCTAssertEqual(
      "This is some value", _messageManager.message(forKey: "bky_reference_VALUE1"))
    XCTAssertEqual(
      "This is value #1", _messageManager.message(forKey: "bky_reference_SOME_vALue"))
  }

  func testLoadSynonymsFromFile_differentPrefixes() {
    BKYAssertDoesNotThrow {
      try _messageManager.loadMessages(
        withPrefix: "\"\"", jsonPath: "i18n_messages1.json", bundle: _bundle)

      try _messageManager.loadSynonyms(
        withPrefix: "\"\"", jsonPath: "i18n_synonyms1.json", bundle: _bundle)

      // Load synonyms with a different prefix. These should have no effect on what's been loaded
      try _messageManager.loadSynonyms(
        withPrefix: "", jsonPath: "i18n_synonyms2.json", bundle: _bundle)
    }

    // Check values with the prefixed keys
    XCTAssertEqual("This is value #1",
                   _messageManager.message(forKey: "\"\"reference_VALUE1"))
  }

  func testLoadSynonymsFromMemory_simple() {
    _messageManager.loadMessages([
      "abc_test": "some translation",
      ])
    _messageManager.loadSynonyms([
      "synonym": "abc_test",
      ])

    XCTAssertEqual("some translation", _messageManager.message(forKey: "synonym"))
  }

  func testLoadSynonymsFromMemory_overwriteValues() {
    _messageManager.loadMessages([
      "abc_test": "some translation",
      "translation2": "another translation"
      ])
    _messageManager.loadSynonyms([
      "synonym": "abc_test",
      ])
    _messageManager.loadSynonyms([
      "synonym": "translation2",
      ])

    XCTAssertEqual("another translation", _messageManager.message(forKey: "synonym"))
  }

  // MARK: - Message Retrieval

  func testMessageRetrieval_simple() {
    _messageManager.loadMessages([
      "KeY": "Translation",
      ])

    XCTAssertEqual("Translation", _messageManager.message(forKey: "KeY"))
    XCTAssertEqual("Translation", _messageManager.message(forKey: "key"))
    XCTAssertEqual("Translation", _messageManager.message(forKey: "KEY"))
    XCTAssertEqual("Translation", _messageManager.message(forKey: "kEy"))
  }

  func testMessageRetrieval_noKey() {
    XCTAssertNil(_messageManager.message(forKey: "key"))
  }

  func testMessageRetrieval_synonym() {
    _messageManager.loadMessages([
      "somekey": "Some key",
      ])
    _messageManager.loadSynonyms([
      "ref_somekey": "SOMEKEY",
    ])

    XCTAssertEqual("Some key", _messageManager.message(forKey: "ref_somekey"))
    XCTAssertEqual("Some key", _messageManager.message(forKey: "REF_SOMEKEY"))
    XCTAssertEqual("Some key", _messageManager.message(forKey: "ref_SOMEKEY"))
  }

  func testMessageRetrieval_synonymWithNoTranslation() {
    _messageManager.loadSynonyms([
      "ref_somekey": "SOMEKEY",
      ])

    // There isn't a "SOMEKEY" translation key, so this should return `nil`
    XCTAssertNil(_messageManager.message(forKey: "ref_somekey"))
  }

  func testMessageRetrieval_synonymRecursion() {
    _messageManager.loadMessages([
      "mainkey": "Translation",
      ])
    _messageManager.loadSynonyms([
      "ref1": "mainkey",
      "ref2": "ref1"
      ])

    XCTAssertEqual("Translation", _messageManager.message(forKey: "mainkey"))
    XCTAssertEqual("Translation", _messageManager.message(forKey: "ref1"))
    // Synonym recursion isn't supported, so this should return `nil`
    XCTAssertNil(_messageManager.message(forKey: "ref2"))
  }

  // MARK: - String Decoding

  func testDecodedString_emptyMessage() {
    let string = _messageManager.decodedString("")
    XCTAssertEqual("", string)
  }

  func testDecodedString_simpleMessage() {
    _messageManager.loadMessages([
      "bky_simple": "Simple"
      ])
    let string = _messageManager.decodedString("%{bky_simple}")
    XCTAssertEqual("Simple", string)
  }

  func testDecodedString_twoSimpleKeys() {
    _messageManager.loadMessages([
      "bky_key1": "Key1",
      "bky_key2": "Key2"
      ])
    let string = _messageManager.decodedString("%{bky_key1} %{bky_key2}")
    XCTAssertEqual("Key1 Key2", string)
  }

  func testDecodedString_conjoinedKeys() {
    _messageManager.loadMessages([
      "bky_key1": "Key1",
      "bky_key2": "Key2"
      ])
    let string = _messageManager.decodedString("%{bky_key1}%{bky_key2}")
    XCTAssertEqual("Key1Key2", string)
  }


  func testDecodedString_recursiveLookup() {
    _messageManager.loadMessages([
      "name": "Taylor",
      "greeting": "Hello, my name is %{name}.",
      "introduction": "%{greeting} NICE TO MEET YOU!"
      ])
    let string = _messageManager.decodedString("%{introduction}")
    XCTAssertEqual("Hello, my name is Taylor. NICE TO MEET YOU!", string)
  }

  func testDecodedString_nonExistentKey() {
    let string = _messageManager.decodedString("%{no_key_found}")
    XCTAssertEqual("%{no_key_found}", string)
  }


  func testDecodedString_keyInsideWord() {
    _messageManager.loadMessages([
      "key": "key",
      ])
    let string = _messageManager.decodedString("mon%{key}brains")
    XCTAssertEqual("monkeybrains", string)
  }

  func testDecodedString_escapedKey() {
    _messageManager.loadMessages([
      "donttranslatethis": "This shouldn't be translated.",
      ])
    let string = _messageManager.decodedString("%%{donttranslatethis}")
    XCTAssertEqual("%%{donttranslatethis}", string)
  }
}
