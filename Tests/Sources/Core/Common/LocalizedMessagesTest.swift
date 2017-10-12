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

/** Tests all localized messages within Blockly. */
class LocalizedMessagesTest: XCTestCase {
  // MARK: - Individual Locale Message Tests

  func testLocalizedMessages_ar() throws {
    try runLocalizedMessageTest(forLocale: "ar")
  }

  func testLocalizedMessages_az() throws {
    try runLocalizedMessageTest(forLocale: "az")
  }

  func testLocalizedMessages_be() throws {
    try runLocalizedMessageTest(forLocale: "be")
  }

  func testLocalizedMessages_bg() throws {
    try runLocalizedMessageTest(forLocale: "bg")
  }

  func testLocalizedMessages_bn() throws {
    try runLocalizedMessageTest(forLocale: "bn")
  }

  func testLocalizedMessages_br() throws {
    try runLocalizedMessageTest(forLocale: "br")
  }

  func testLocalizedMessages_ca() throws {
    try runLocalizedMessageTest(forLocale: "ca")
  }

  func testLocalizedMessages_cs() throws {
    try runLocalizedMessageTest(forLocale: "cs")
  }

  func testLocalizedMessages_da() throws {
    try runLocalizedMessageTest(forLocale: "da")
  }

  func testLocalizedMessages_de() throws {
    try runLocalizedMessageTest(forLocale: "de")
  }

  func testLocalizedMessages_el() throws {
    try runLocalizedMessageTest(forLocale: "el")
  }

  func testLocalizedMessages_en_gb() throws {
    try runLocalizedMessageTest(forLocale: "en-GB")
  }

  func testLocalizedMessages_en() throws {
    try runLocalizedMessageTest(forLocale: "en")
  }

  func testLocalizedMessages_eo() throws {
    try runLocalizedMessageTest(forLocale: "eo")
  }

  func testLocalizedMessages_es() throws {
    try runLocalizedMessageTest(forLocale: "es")
  }

  func testLocalizedMessages_et() throws {
    try runLocalizedMessageTest(forLocale: "et")
  }

  func testLocalizedMessages_fa() throws {
    try runLocalizedMessageTest(forLocale: "fa")
  }

  func testLocalizedMessages_fi() throws {
    try runLocalizedMessageTest(forLocale: "fi")
  }

  func testLocalizedMessages_fr() throws {
    try runLocalizedMessageTest(forLocale: "fr")
  }

  func testLocalizedMessages_he() throws {
    try runLocalizedMessageTest(forLocale: "he")
  }

  func testLocalizedMessages_hi() throws {
    try runLocalizedMessageTest(forLocale: "hi")
  }

  func testLocalizedMessages_hu() throws {
    try runLocalizedMessageTest(forLocale: "hu")
  }

  func testLocalizedMessages_id() throws {
    try runLocalizedMessageTest(forLocale: "id")
  }

  func testLocalizedMessages_is() throws {
    try runLocalizedMessageTest(forLocale: "is")
  }

  func testLocalizedMessages_it() throws {
    try runLocalizedMessageTest(forLocale: "it")
  }

  func testLocalizedMessages_ja() throws {
    try runLocalizedMessageTest(forLocale: "ja")
  }

  func testLocalizedMessages_kab() throws {
    try runLocalizedMessageTest(forLocale: "kab")
  }

  func testLocalizedMessages_ko() throws {
    try runLocalizedMessageTest(forLocale: "ko")
  }

  func testLocalizedMessages_lb() throws {
    try runLocalizedMessageTest(forLocale: "lb")
  }

  func testLocalizedMessages_lrc() throws {
    try runLocalizedMessageTest(forLocale: "lrc")
  }

  func testLocalizedMessages_lt() throws {
    try runLocalizedMessageTest(forLocale: "lt")
  }

  func testLocalizedMessages_lv() throws {
    try runLocalizedMessageTest(forLocale: "lv")
  }

  func testLocalizedMessages_mk() throws {
    try runLocalizedMessageTest(forLocale: "mk")
  }

  func testLocalizedMessages_ms() throws {
    try runLocalizedMessageTest(forLocale: "ms")
  }

  func testLocalizedMessages_nb() throws {
    try runLocalizedMessageTest(forLocale: "nb")
  }

  func testLocalizedMessages_nl() throws {
    try runLocalizedMessageTest(forLocale: "nl")
  }

  func testLocalizedMessages_pl() throws {
    try runLocalizedMessageTest(forLocale: "pl")
  }

  func testLocalizedMessages_pt_br() throws {
    try runLocalizedMessageTest(forLocale: "pt-BR")
  }

  func testLocalizedMessages_pt() throws {
    try runLocalizedMessageTest(forLocale: "pt")
  }

  func testLocalizedMessages_ro() throws {
    try runLocalizedMessageTest(forLocale: "ro")
  }

  func testLocalizedMessages_ru() throws {
    try runLocalizedMessageTest(forLocale: "ru")
  }

  func testLocalizedMessages_sk() throws {
    try runLocalizedMessageTest(forLocale: "sk")
  }

  func testLocalizedMessages_sl() throws {
    try runLocalizedMessageTest(forLocale: "sl")
  }

  func testLocalizedMessages_sq() throws {
    try runLocalizedMessageTest(forLocale: "sq")
  }

  func testLocalizedMessages_sr() throws {
    try runLocalizedMessageTest(forLocale: "sr")
  }

  func testLocalizedMessages_sv() throws {
    try runLocalizedMessageTest(forLocale: "sv")
  }

  func testLocalizedMessages_ta() throws {
    try runLocalizedMessageTest(forLocale: "ta")
  }

  func testLocalizedMessages_th() throws {
    try runLocalizedMessageTest(forLocale: "th")
  }

  func testLocalizedMessages_tr() throws {
    try runLocalizedMessageTest(forLocale: "tr")
  }

  func testLocalizedMessages_uk() throws {
    try runLocalizedMessageTest(forLocale: "uk")
  }

  func testLocalizedMessages_vi() throws {
    try runLocalizedMessageTest(forLocale: "vi")
  }

  func testLocalizedMessages_zh_hans() throws {
    try runLocalizedMessageTest(forLocale: "zh-Hans")
  }

  func testLocalizedMessages_zh_hant() throws {
    try runLocalizedMessageTest(forLocale: "zh-Hant")
  }

  // MARK: - Helper Methods

  private func runLocalizedMessageTest(forLocale locale: String) throws {
    // Get the test and individual locale bundle
    let testBundle = Bundle(for: type(of: self))
    guard let path = testBundle.path(forResource: locale, ofType: "lproj") else {
      throw TestError("Test bundle for locale \"\(locale)\" could not be found.")
    }
    let localBundle = Bundle(path: path)

    // Load constants and synonyms from the test bundle (these don't change), and messages from
    // its locale bundle.
    let manager = MessageManager.shared
    manager._clear()
    try manager.loadMessages(withPrefix: "bky_", jsonPath: "bky_constants.json", bundle: testBundle)
    try manager.loadMessages(withPrefix: "bky_", jsonPath: "bky_messages.json", bundle: localBundle)
    try manager.loadSynonyms(withPrefix: "bky_", jsonPath: "bky_synonyms.json", bundle: testBundle)

    // Load a block factory with all the default blocks. This will use all messages stored in
    // `MessageManager.shared`. If this load succeeds, it means all messages are valid for this
    // locale.
    let blockFactoryBundle = Bundle(for: BlockFactory.self)
    let blockFactory = BlockFactory()
    let defaultFiles = BlockJSONFile.allDefault
    blockFactory.updateMutators(defaultFiles.mutators)
    blockFactory.updateBlockExtensions(defaultFiles.blockExtensions)
    try blockFactory.load(fromJSONPaths: defaultFiles.fileLocations, bundle: blockFactoryBundle)
  }
}

