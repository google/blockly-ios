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

import AEXML
import Foundation

/**
 Builder for making `CodeGeneratorServiceRequest` instances.
 */
@objc(BKYCodeGeneratorServiceRequestBuilder)
@objcMembers open class CodeGeneratorServiceRequestBuilder: NSObject {
  // MARK: - Properties

  /// The name of the JS object that should be used for each request (e.g. 'Blockly.Python')
  open let jsGeneratorObject: String
  /// List of block generator JS files that should be used for each request
  /// (e.g. ['python_compressed.js'])
  open private(set) var jsBlockGeneratorFiles = [BundledFile]()
  /// List of JSON files containing block definitions that should be used for each request
  open private(set) var jsonBlockDefinitionFiles = [BundledFile]()

  // MARK: - Initializers

  /**
   Create a builder for making `CodeGeneratorServiceRequest` instances.

   - parameter jsGeneratorObject: The name of the JS object that should be used for each request
   code (e.g. 'Blockly.Python').
   */
  @objc(initWithJSGeneratorObject:)
  public init(jsGeneratorObject: String) {
    self.jsGeneratorObject = jsGeneratorObject
  }

  // MARK: - Public

  /**
   Adds to the list of JS block generator files that should be used for each request.

   - parameter files: Paths to JS block generator files, relative to the main resource bundle.
   */
  public func addJSBlockGeneratorFiles(_ files: [String]) {
    addJSBlockGeneratorFiles(files, bundle: Bundle.main)
  }

  /**
   Adds to the list of JS block generator files that should be used for each request.

   - parameter files: Paths to JS block generator files, relative to the given resource `bundle`.
   - parameter bundle: The resource bundle containing `jsBlockGenerators`.
   */
  public func addJSBlockGeneratorFiles(_ files: [String], bundle: Bundle) {
    let generators = files.map({ (path: $0, bundle: bundle) })
    jsBlockGeneratorFiles.append(contentsOf: generators)
  }

  /**
   Adds to the list of JSON block definition files that should be used for each request.

   - parameter defaultFiles: A list of default block definition files.
   */
  public func addJSONBlockDefinitionFiles(fromDefaultFiles defaultFiles: BlockJSONFile) {
    addJSONBlockDefinitionFiles(defaultFiles.fileLocations,
                                bundle: Bundle(for: CodeGeneratorServiceRequestBuilder.self))
  }

  /**
   Adds to the list of JSON block definition files that should be used for each request.

   - parameter files: Paths to JSON block definition files, relative to the main resource bundle.
   */
  public func addJSONBlockDefinitionFiles(_ files: [String]) {
    addJSONBlockDefinitionFiles(files, bundle: Bundle.main)
  }

  /**
   Adds to the list of JSON block definition files that should be used for each request.

   - parameter files: Paths to JSON block definition files, relative to the given
   resource `bundle`.
   - parameter bundle: The resource bundle containing `jsonBlockDefinitions`.
   */
  public func addJSONBlockDefinitionFiles(_ files: [String], bundle: Bundle) {
    let definitions = files.map({ (path: $0, bundle: bundle) })
    jsonBlockDefinitionFiles.append(contentsOf: definitions)
  }

  /**
   Based on the current state of the builder and given workspace XML, create a
   code generator service request.

   - parameter workspaceXML: The workspace XML to use for the request.
   - returns: A `CodeGeneratorServiceRequest`.
   */
  internal func makeRequest(forWorkspaceXML workspaceXML: String) -> CodeGeneratorServiceRequest {
    return CodeGeneratorServiceRequest(
      workspaceXML: workspaceXML, jsGeneratorObject: jsGeneratorObject,
      jsBlockGeneratorFiles: jsBlockGeneratorFiles,
      jsonBlockDefinitionFiles: jsonBlockDefinitionFiles,
      onCompletion: nil, onError: nil)
  }

  /**
   Based on the current state of the builder and a given workspace, create a
   code generator service reqeust.

   - parameter workspace: The `Workspace` to use for the request.
   - returns: A `CodeGeneratorServiceRequest`.
   */
  internal func makeRequest(forWorkspace workspace: Workspace) throws -> CodeGeneratorServiceRequest {
    return makeRequest(forWorkspaceXML: try workspace.toXML())
  }
}
