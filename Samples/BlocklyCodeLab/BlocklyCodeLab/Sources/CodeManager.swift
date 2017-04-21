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

import Blockly
import Foundation

/**
 Manages JS code in the app. It generates JS code from workspace XML and saves it in-memory for
 future use.
 */
class CodeManager {
  /// Stores JS code for a unique key (ie. a button ID).
  private var savedCode = [String: String]()

  /// Service used for converting workspace XML into JS code.
  private var codeGeneratorService = CodeGeneratorService(
    jsCoreDependencies: [
      // The JS file containing the Blockly engine
      "blockly_web/blockly_compressed.js",
      // The JS file containing a list of internationalized messages
      "blockly_web/msg/js/en.js"
    ])

  /// Builder for creating code generator service requests.
  private var requestBuilder: CodeGeneratorServiceRequestBuilder = {
    let builder = CodeGeneratorServiceRequestBuilder(
      // This is the name of the JS object that will generate JavaScript code
      jsGeneratorObject: "Blockly.JavaScript")
    builder.addJSBlockGeneratorFiles([
      // Use JavaScript code generators for the default blocks
      "blockly_web/javascript_compressed.js",
      // Use JavaScript code generators for our custom turtle blocks
      "sound_block_generators.js"])
    // Load the block definitions for all default blocks
    builder.addJSONBlockDefinitionFiles(fromDefaultFiles: .allDefault)
    // Load the block definitions for our custom turtle blocks
    builder.addJSONBlockDefinitionFiles(["sound_blocks.json"])

    return builder
  }()

  init() {
    // Assign the request builder to the service and cache it so subsequent code generation
    // runs are immediate.
    codeGeneratorService.setRequestBuilder(self.requestBuilder, shouldCache: true)
  }

  deinit {
    codeGeneratorService.cancelAllRequests()
  }

  /**
   Generates code for a given `key`.
   */
  func generateCode(forKey key: String, workspaceXML: String) {
    do {
      // Clear the code for this key as we generate the new code.
      self.savedCode[key] = nil

      let _ = try codeGeneratorService.generateCode(
        forWorkspaceXML: workspaceXML,
        onCompletion: { requestUUID, code in
          // Code generated successfully. Save it for future use.
          self.savedCode[key] = code
        },
        onError: { requestUUID, error in
          print("An error occurred generating code - \(error)\n" +
            "key: \(key)\n" +
            "workspaceXML: \(workspaceXML)\n")
        })
    } catch let error {
      print("An error occurred generating code - \(error)\n" +
        "key: \(key)\n" +
        "workspaceXML: \(workspaceXML)\n")
    }
  }

  /**
   Retrieves code for a given `key`.
   */
  func code(forKey key: String) -> String? {
    return savedCode[key]
  }
}
