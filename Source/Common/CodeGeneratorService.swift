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
import AEXML

/**
 Service for generating code from a workspace.

 Internally, this object uses instances of `CodeGenerator` to execute requests. Please see
 `CodeGenerator` for more information.
 */
@objc(BKYCodeGeneratorService)
public final class CodeGeneratorService: NSObject {

  // MARK: - Properties

  /// List of core Blockly JS dependencies
  fileprivate let jsCoreDependencies: [BundledFile]
  /// Current code generator
  fileprivate var codeGenerator: CodeGenerator?
  /// Operation queue of all pending code generation requests
  fileprivate let requestQueue = OperationQueue()

  // MARK: - Initializers

  /**
   Creates a code generator service.

   - Parameter jsCoreDependencies: Paths to core Blockly JS dependencies. These core dependencies
   will be used when an internal `CodeGenerator` instance is created. This list must contain the
   following files:
     - Blockly engine (eg. 'blockly_compressed.js')
     - Blockly default blocks (eg. 'blocks_compressed.js')
     - A default list of messages (eg. 'msg/js/en.js')
   */
  public init(jsCoreDependencies: [BundledFile]) {
    self.jsCoreDependencies = jsCoreDependencies
    super.init()

    // Only allow one request to execute at a time
    requestQueue.maxConcurrentOperationCount = 1
  }

  deinit {
    cancelAllRequests()
  }

  /**
   Sends a request to generate code.

   If the request completes successfully, the request's `onCompletion` block is executed.
   If the request fails, the request's `onError` block is executed.

   - Parameter request: The request
   */
  public func generateCode(forRequest request: CodeGeneratorServiceRequest) {
    request.codeGeneratorService = self
    requestQueue.addOperation(request)
  }

  /**
   Cancels code generation for a given request.
   */
  public func cancelRequest(_ request: CodeGeneratorServiceRequest) {
    request.cancel()
  }

  /**
   Cancels all pending code generation requests.
   */
  public func cancelAllRequests() {
    requestQueue.cancelAllOperations()
  }

  // MARK: - Private

  open func executeRequest(_ request: CodeGeneratorServiceRequest) {
    if let codeGenerator = self.codeGenerator ,
      (compareLists(codeGenerator.jsonBlockDefinitions, request.jsonBlockDefinitions) &&
      compareLists(codeGenerator.jsBlockGenerators, request.jsBlockGenerators) &&
      codeGenerator.jsGeneratorObject == request.jsGeneratorObject)
    {
      // No JS/JSON files have changed since the last request. Use the existing code generator.
      codeGenerator.generateCodeForWorkspaceXML(request.workspaceXML,
        completion: request.completeRequest(withCode:),
        error: request.completeRequest(withError:))
    } else {
      // Use a new code generator (`CodeGenerator` must be instantiated on the main thread)
      DispatchQueue.main.async(execute: {
        self.codeGenerator = CodeGenerator(
          jsCoreDependencies: self.jsCoreDependencies,
          jsGeneratorObject: request.jsGeneratorObject,
          jsBlockGenerators: request.jsBlockGenerators,
          jsonBlockDefinitions: request.jsonBlockDefinitions,
          onLoadCompletion: {
            self.codeGenerator!.generateCodeForWorkspaceXML(request.workspaceXML,
              completion: request.completeRequest(withCode:),
              error: request.completeRequest(withError:))
          }, onLoadFailure: { (error) -> Void in
            self.codeGenerator = nil // Nil out this self.codeGenerator so we don't use it again
            request.completeRequest(withError: error)
          })
      })
    }
  }

  fileprivate func compareLists(
    _ list1: [BundledFile], _ list2: [BundledFile]) -> Bool
  {
    if list1.count != list2.count {
      return false
    }
    var mutableList1 = list1
    for path2 in list2 {
      if let index = mutableList1.index(where:
        { $0.path == path2.path && $0.bundle == path2.bundle })
      {
        mutableList1.remove(at: index)
      } else {
        return false
      }
    }
    return true
  }
}

// MARK: - CodeGeneratorService.Request Class

extension CodeGeneratorService {
}
