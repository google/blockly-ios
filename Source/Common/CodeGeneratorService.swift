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

// MARK: - CodeGeneratorService Class

/**
 Service for generating code from a workspace.

 For details on how to use this class, see:
 https://developers.google.com/blockly/guides/configure/ios/code-generators
 */
@objc(BKYCodeGeneratorService)
public final class CodeGeneratorService: NSObject {
  // MARK: - Typealiases
  public typealias CompletionClosure = (_ code: String) -> Void
  public typealias ErrorClosure = (_ error: String) -> Void

  // MARK: - Properties

  /// List of core Blockly JS dependencies
  fileprivate let jsCoreDependencies: [BundledFile]
  /// Current code generator
  fileprivate var codeGenerator: CodeGenerator?
  /// Operation queue of all pending code generation requests
  fileprivate let requestQueue = OperationQueue()

  /// The code generator service request builder. This must be set before requesting code
  /// generation.
  private var codeGeneratorServiceRequestBuilder: CodeGeneratorServiceRequestBuilder? = nil;

  // MARK: - Initializers

  /**
   Creates a code generator service.

   - parameter jsCoreDependencies: Paths to core Blockly JS dependencies, relative to the main
   resource bundle. These core dependencies will be used when an internal `CodeGenerator`
   instance is created. This list must contain the following files:
     - Blockly engine (eg. 'blockly_compressed.js')
     - A default list of messages (eg. 'msg/js/en.js')
   */
  public convenience init(jsCoreDependencies: [String]) {
    self.init(jsCoreDependencies: jsCoreDependencies, bundle: Bundle.main)
  }

  /**
   Creates a code generator service.

   - parameter jsCoreDependencies: Paths to core Blockly JS dependencies, relative to a given
   resource `bundle`. These core dependencies will be used when an internal `CodeGenerator`
   instance is created. This list must contain the following files:
     - Blockly engine (eg. 'blockly_compressed.js')
     - A default list of messages (eg. 'msg/js/en.js')
   - parameter bundle: The resource bundle containing `jsCoreDependencies`.
   */
  public init(jsCoreDependencies: [String], bundle: Bundle) {
    self.jsCoreDependencies = jsCoreDependencies.map { (path: $0, bundle: bundle) }
    super.init()

    // Only allow one request to execute at a time
    requestQueue.maxConcurrentOperationCount = 1
  }

  deinit {
    cancelAllRequests()
  }

  /**
   Sets the code generator service request builder to be used for code generation.

   - parameter builder: The `CodeGeneratorServiceRequestBuilder` that specifies generators.
   - parameter shouldCache: `true` if the Blockly files should be preloaded, `false` if not.
   */
  public func setCodeGeneratorServiceRequestBuilder(_ builder: CodeGeneratorServiceRequestBuilder,
    shouldCache: Bool)
  {
    self.codeGeneratorServiceRequestBuilder = builder

    if (shouldCache) {
      let request = builder.makeRequest(forWorkspaceXML: "")
      self.codeGenerator = CodeGenerator(
        jsCoreDependencies: self.jsCoreDependencies,
        jsGeneratorObject: request.jsGeneratorObject,
        jsBlockGeneratorFiles: request.jsBlockGeneratorFiles,
        jsonBlockDefinitionFiles: request.jsonBlockDefinitionFiles,
        onLoadCompletion: nil,
        onLoadFailure: nil)
    }
  }

  /**
   Begins code generation for a workspace. The `CodeGeneratorServiceRequestBuilder` must be set
   before calling this function.

   - parameter workspace: The workspace to generate code for.
   - parameter onCompletion: The `CompletionClosure` to be called when the code is generated.
   - parameter onError: The `ErrorClosure` to be called if the code fails to generate.
   */
  public func generateCode(forWorkspace workspace: Workspace,
                           onCompletion: CompletionClosure? = nil,
                           onError: ErrorClosure? = nil) throws -> String {
    return try generateCode(forWorkspaceXML: workspace.toXML(),
                            onCompletion: onCompletion,
                            onError: onError)
  }

  /**
   Begins code generation for a workspace. The `CodeGeneratorServiceRequestBuilder` must be set
   before calling this function.

   - parameter xml: The workspace XML to generate code for.
   - parameter onCompletion: The `CompletionClosure` to be called when the code is generated.
   - parameter onError: The `ErrorClosure` to be called if the code fails to generate.
   */
  public func generateCode(forWorkspaceXML xml: String,
                           onCompletion: CompletionClosure? = nil,
                           onError: ErrorClosure? = nil) -> String {
    guard let builder = self.codeGeneratorServiceRequestBuilder else {
      print("Error: The code generator service request builder has not been set.")
      return ""
    }

    let request = builder.makeRequest(forWorkspaceXML: xml)
    request.uuid = UUID().uuidString
    request.onCompletion = onCompletion
    request.onError = onError
    request.codeGeneratorService = self
    requestQueue.addOperation(request)
    return request.uuid
  }

  /**
   Cancels code generation for a given request.

   - parameter request: The `CodeGeneratorServiceRequest` to cancel.
   */
  public func cancelRequest(uuid: String) {
    for operation in requestQueue.operations {
      guard let request = operation as? CodeGeneratorServiceRequest else {
        continue
      }

      if request.uuid == uuid {
        request.cancel()
        return
      }
    }
  }

  /**
   Cancels all pending code generation requests.
   */
  public func cancelAllRequests() {
    requestQueue.cancelAllOperations()
  }

  // MARK: - Private

  fileprivate func executeRequest(_ request: CodeGeneratorServiceRequest) {
    if let codeGenerator = self.codeGenerator ,
      (compareLists(codeGenerator.jsonBlockDefinitionFiles, request.jsonBlockDefinitionFiles) &&
      compareLists(codeGenerator.jsBlockGeneratorFiles, request.jsBlockGeneratorFiles) &&
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
          jsBlockGeneratorFiles: request.jsBlockGeneratorFiles,
          jsonBlockDefinitionFiles: request.jsonBlockDefinitionFiles,
          onLoadCompletion: {
            self.codeGenerator?.generateCodeForWorkspaceXML(request.workspaceXML,
              completion: request.completeRequest(withCode:),
              error: request.completeRequest(withError:))
          }, onLoadFailure: { (error) -> Void in
            self.codeGenerator = nil // Nil out this self.codeGenerator so we don't use it again
            request.completeRequest(withError: error)
          })
      })
    }
  }

  fileprivate func compareLists(_ list1: [BundledFile], _ list2: [BundledFile]) -> Bool {
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

// MARK: - CodeGeneratorServiceRequest Class

/**
 Request object for generating code for a workspace.

 - note: To create a `CodeGeneratorServiceRequest`, use `CodeGeneratorServiceRequestBuilder`.
 */
internal class CodeGeneratorServiceRequest: Operation {
  // MARK: - Properties
  /// The uuid for this request.
  internal var uuid: String = ""
  /// The workspace XML to use when generating code
  internal let workspaceXML: String
  /// The name of the JS object that generates code (e.g. 'Blockly.Python')
  internal let jsGeneratorObject: String
  /// List of block generator JS files (e.g. ['python_compressed.js'])
  internal let jsBlockGeneratorFiles: [BundledFile]
  /// List of JSON files containing block definitions
  internal let jsonBlockDefinitionFiles: [BundledFile]
  /// Callback that is executed when code generation completes successfully. This is always
  /// executed on the main thread.
  internal var onCompletion: CodeGeneratorService.CompletionClosure?
  /// Callback that is executed when code generation fails. This is always executed on the main
  /// thread.
  internal var onError: CodeGeneratorService.ErrorClosure?
  /// The code generator service used for executing this request.
  fileprivate weak var codeGeneratorService: CodeGeneratorService?

  // MARK: - Initializers

  /**
   Use `CodeGeneratorServiceRequestBuilder` to create a request.
   */
  internal init(workspaceXML: String, jsGeneratorObject: String,
                jsBlockGeneratorFiles: [BundledFile], jsonBlockDefinitionFiles: [BundledFile],
                onCompletion: CodeGeneratorService.CompletionClosure?,
                onError: CodeGeneratorService.ErrorClosure?) {
    self.workspaceXML = workspaceXML
    self.jsGeneratorObject = jsGeneratorObject
    self.jsBlockGeneratorFiles = jsBlockGeneratorFiles
    self.jsonBlockDefinitionFiles = jsonBlockDefinitionFiles
    self.onCompletion = onCompletion
    self.onError = onError
  }

  // MARK: - Super

  fileprivate var _executing: Bool = false
  /// `true` if the generator is executing, `false` otherwise.
  internal override var isExecuting: Bool {
    get { return _executing }
    set {
      if _executing == newValue {
        return
      }
      willChangeValue(forKey: "isExecuting")
      _executing = newValue
      didChangeValue(forKey: "isExecuting")
    }
  }

  fileprivate var _finished: Bool = false
  /// `true` if the generator has finished running, `false` otherwise.
  internal override var isFinished: Bool {
    get { return _finished }
    set {
      if _finished == newValue {
        return
      }
      willChangeValue(forKey: "isFinished")
      _finished = newValue
      didChangeValue(forKey: "isFinished")
    }
  }

  /// Starts the code generator service.
  internal override func start() {
    if self.isCancelled {
      finishOperation()
      return
    }
    self.isExecuting = true

    // Execute the request. The operation will eventually execute:
    // completeRequestWithCode(...) or
    // completeRequestWithError(...)
    codeGeneratorService?.executeRequest(self)
  }

  /// Cancels the code generator service.
  internal override func cancel() {
    self.onCompletion = nil
    self.onError = nil
    super.cancel()
  }

  /// MARK: - Private

  fileprivate func completeRequest(withCode code: String) {
    DispatchQueue.main.async {
      if !self.isCancelled {
        self.onCompletion?(code)
      }
      self.finishOperation()
    }
  }

  fileprivate func completeRequest(withError error: String) {
    DispatchQueue.main.async {
      if !self.isCancelled {
        self.onError?(error)
      }
      self.finishOperation()
    }
  }

  fileprivate func finishOperation() {
    self.onCompletion = nil
    self.onError = nil
    self.isExecuting = false
    self.isFinished = true
  }
}
