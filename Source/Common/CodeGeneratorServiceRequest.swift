//
//  CodeGeneratorRequest.swift
//  Blockly
//
//  Created by Cory Diers on 9/29/16.
//  Copyright © 2016 Google Inc. All rights reserved.
//

import Foundation

/**
 Request object for generating code for a workspace.
 */

@objc(BKYCodeGeneratorServiceRequest)
open class CodeGeneratorServiceRequest: Operation {
  // MARK: - Typealiases
  public typealias CompletionClosure = (_ code: String) -> Void
  public typealias ErrorClosure = (_ error: String) -> Void

  // MARK: - Properties
  /// The workspace XML to use when generating code
  open let workspaceXML: String
  /// The name of the JS object that generates code (e.g. 'Blockly.Python')
  open let jsGeneratorObject: String
  /// List of block generator JS files (e.g. ['python_compressed.js'])
  open let jsBlockGenerators: [BundledFile]
  /// List of JSON files containing block definitions
  open let jsonBlockDefinitions: [BundledFile]
  /// Callback that is executed when code generation completes successfully. This is always
  /// executed on the main thread.
  open var onCompletion: CompletionClosure?
  /// Callback that is executed when code generation fails. This is always executed on the main
  /// thread.
  open var onError: ErrorClosure?
  /// The code generator service used for executing this request.
  public weak var codeGeneratorService: CodeGeneratorService?

  // MARK: - Initializers

  /**
   Initializer for the code generator service.

   - Parameter workspaceXML: The XML to use for generating code.
   - Parameter jsGeneratorObject: The name of the JS object that generates code.
   (e.g. 'Blockly.Python')
   - Parameter jsBlockGenerators: The list of JS files containing block generators.
   - Parameter jsonBlockDefinitions: The list of JSON files containing block definitions.
   */
  public init(workspaceXML: String,
              jsGeneratorObject: String,
              jsBlockGenerators: [BundledFile],
              jsonBlockDefinitions: [BundledFile])
  {
    self.workspaceXML = workspaceXML
    self.jsGeneratorObject = jsGeneratorObject
    self.jsBlockGenerators = jsBlockGenerators
    self.jsonBlockDefinitions = jsonBlockDefinitions
  }

  /**
   Initializer for the code generator service.

   - Parameter workspace: The workspace to use for generating code.
   - Parameter jsGeneratorObject: The name of the JS object that generates code.
   (e.g. 'Blockly.Python')
   - Parameter jsBlockGenerators: The list of JS files containing block generators.
   - Parameter jsonBlockDefinitions: The list of JSON files containing block definitions.
   */
  public convenience init(workspace: Workspace,
                          jsGeneratorObject: String,
                          jsBlockGenerators: [BundledFile],
                          jsonBlockDefinitions: [BundledFile]) throws
  {
    self.init(workspaceXML: try workspace.toXML().xml,
              jsGeneratorObject: jsGeneratorObject, jsBlockGenerators: jsBlockGenerators,
              jsonBlockDefinitions: jsonBlockDefinitions)
  }

  // MARK: - Super

  fileprivate var _executing: Bool = false
  /// `true` if the generator is executing, `false` otherwise.
  open override var isExecuting: Bool {
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
  open override var isFinished: Bool {
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
  open override func start() {
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
  open override func cancel() {
    self.onCompletion = nil
    self.onError = nil
    super.cancel()
  }

  // MARK: - Private

  open func completeRequest(withCode code: String) {
    DispatchQueue.main.async {
      if !self.isCancelled {
        self.onCompletion?(code)
      }
      self.finishOperation()
    }
  }

  open func completeRequest(withError error: String) {
    DispatchQueue.main.async {
      if !self.isCancelled {
        self.onError?(error)
      }
      self.finishOperation()
    }
  }

  open func finishOperation() {
    self.onCompletion = nil
    self.onError = nil
    self.isExecuting = false
    self.isFinished = true
  }
}
