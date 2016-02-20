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
import JavaScriptCore

// MARK: - CodeGenerator Class

/**
 Helper for generating code from a workspace.

 This helper is actually a wrapper of a non-UI web version of Blockly, which generates workspace
 code via JavaScript. For more information on how this works, see:
 https://developers.google.com/blockly/installation/code-generators

 - Note: This object must be instantiated on the main thread, as it internally instantiates a
`UIWebView` object (which has to be done on the main thread).
 */
@objc(BKYCodeGenerator)
public class CodeGenerator: NSObject {

  // MARK: - Static Properties
  /// Internal JS file that is used to communicate between the iOS code and JS code
  private static let CODE_GENERATOR_BRIDGE_JS = "code_generator/code_generator_bridge.js"

  // MARK: - Properties

  /// The webview used for generating code
  private var webView: UIWebView!
  /// The underlying JSContext of `self.webView`
  private var jsContext: JSContext!
  /// The name of the JS object that generates code (e.g. 'Blockly.JavaScript')
  private var jsGeneratorObject: String
  /// The current request being processed
  private var currentRequest: Request?
  /// Operation queue of all pending code generation requests
  private let requestQueue = NSOperationQueue()

  // MARK: - Initializers

  /**
   Initializer for a code generator.

   - Parameter jsGeneratorObject: Name of the JS object that generates code
   (e.g. 'Blockly.Python' for generating Python code)
   - Parameter jsDependencies: Paths to all of the JS dependencies required to generate code. This
   list must contain the following files:
     - Blockly engine (eg. 'blockly_compressed.js')
     - Blockly default blocks (eg. 'blocks_compressed.js')
     - A default list of messages (eg. 'msg/js/en.js')
     - The code generator for the `jsGeneratorObject` (eg. 'python_compressed.js' for generating
     Python code)
   - Parameter bundle: The bundle in which to find the files in `jsDependencies`. If this parameter
   is `nil`, the default main bundle is used.
  - Throws:
  `BlocklyError`: Thrown if one or more dependencies could not be loaded.
   */
  public init(jsGeneratorObject: String, jsDependencies: [String], bundle: NSBundle? = nil) throws
  {
    self.webView = UIWebView()
    self.webView.loadHTMLString("", baseURL: NSURL(string: "about:blank")!)
    self.jsContext =
      webView.valueForKeyPath("documentView.webView.mainFrame.javaScriptContext") as! JSContext
    self.jsGeneratorObject = jsGeneratorObject

    super.init()

    // Only allow one request to execute at a time
    requestQueue.maxConcurrentOperationCount = 1

    // Register a handler if an exception is thrown in the JS code
    jsContext.exceptionHandler = { context, exception in
      let request = self.currentRequest
      self.currentRequest = nil
      request?.completeRequestWithError("JS Exception: \(exception)")
    }

    // Load our special bridge file
    try loadJSFile(CodeGenerator.CODE_GENERATOR_BRIDGE_JS,
      bundle: NSBundle(forClass: CodeGenerator.self))

    // Load dependencies
    for file in jsDependencies {
      try loadJSFile(file, bundle: bundle)
    }
  }

  deinit {
    cancelAllRequests()
  }

  // MARK: - Public

  /**
   Imports block definitions from a given JSON file.

   - Parameter file: The path to the file containing the JSON block definitions.
   - Parameter bundle: The bundle in which to find `file`. If this parameter is nil, the default
   main bundle is used.
   - Throws:
   `BlocklyError`: Thrown if there was an error loading the JSON file.
   */
  public func importBlockDefinitionsFromFile(file: String, bundle: NSBundle? = nil) throws {
    let fromBundle = bundle ?? NSBundle.mainBundle()
    guard let path = fromBundle.pathForResource(file, ofType: nil) else {
      throw BlocklyError(.FileNotFound, "JSON file could not be found ('\(file)').")
    }

    do {
      let string = try String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
      let method = jsContext.evaluateScript("CodeGeneratorBridge.importBlockDefinitions")
      method.callWithArguments([string])
    } catch let error as NSError {
      throw BlocklyError(.FileNotReadable, "JSON file could not be read ('\(file)'):\n\(error)")
    }
  }

  /**
   Imports custom block generators from a given JavaScript file.

   - Parameter file: The path to the JavaScript file containing the block generators.
   - Parameter bundle: The bundle in which to find `file`. If this parameter is nil, the default
   main bundle is used.
   - Throws:
   `BlocklyError`: Thrown if there was an error importing the JavaScript file.
   */
  public func importBlockGeneratorsFromFile(file: String, bundle: NSBundle? = nil) throws {
    try loadJSFile(file, bundle: bundle)
  }

  /**
   Sends a request to generate code.

   If the request completes successfully, the request's `onCompletion` block is executed.
   If the request fails, the request's `onError` block is executed.

   - Parameter request: The request
   */
  public func generateCodeForRequest(request: Request) {
    request.codeGenerator = self
    requestQueue.addOperation(request)
  }

  /**
   Cancels code generation for a given request.
   */
  public func cancelRequest(request: Request) {
    request.cancel()
  }

  /**
   Cancels all pending code generation requests.
   */
  public func cancelAllRequests() {
    requestQueue.cancelAllOperations()
  }

  // MARK: - Private

  /**
   Generates code for a given request.

   - Parameter request: The request
   */
  private func executeCodeGenerationForRequest(request: Request) {
    self.currentRequest = request

    // Generate the code.
    // Note: If this request is called on a background thread, it can sometimes cause an
    // EXC_BAD_ACCESS to be thrown on a WebCore thread. Therefore, we have chosen to execute this
    // on the main thread as it doesn't seem to crash out. Luckily, generating code for a workspace
    // is a fast operation, so this *shouldn't* be a big performance hit.
    // TODO:(#14) Investigate the performance of this on a large workspace.
    dispatch_async(dispatch_get_main_queue()) {
      let generator = self.jsContext.evaluateScript(self.jsGeneratorObject)
      let method = self.jsContext.evaluateScript("CodeGeneratorBridge.generateCodeForWorkspace")
      let returnValue = method.callWithArguments([self.currentRequest!.workspaceXML, generator])

      if let code = returnValue.toString() {
        // Success!
        let request = self.currentRequest
        self.currentRequest = nil
        request?.completeRequestWithCode(code)
      } else {
        // Fail :(
        let request = self.currentRequest
        self.currentRequest = nil
        request?.completeRequestWithError("Could not convert return value into a String.")
      }
    }
  }

  private func loadJSFile(file: String, bundle: NSBundle? = nil) throws {
    let fromBundle = bundle ?? NSBundle.mainBundle()
    if let path = fromBundle.pathForResource(file, ofType: nil) {
      do {
        let string = try String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        jsContext.evaluateScript(string)
      } catch let error as NSError {
        throw BlocklyError(.FileNotReadable, "JS file could not be read ('\(file)'):\n\(error)")
      }
    } else {
      throw BlocklyError(.FileNotFound, "JS file could not be found ('\(file)').")
    }
  }
}

// MARK: - CodeGenerator.Request Class

extension CodeGenerator {
  /**
   Request object for generating code for a workspace.
   */
  public class Request: NSOperation {
    /// MARK: - Type Aliases
    public typealias CompletionClosure = (code: String) -> Void
    public typealias ErrorClosure = (error: String) -> Void

    // MARK: - Properties
    /// The workspace XML to use when generating code
    public let workspaceXML: String
    /// Callback that is executed when code generation completes successfully
    public var onCompletion: CompletionClosure?
    /// Callback that is executed when code generation fails
    public var onError: ErrorClosure?
    /// The code generator used for executing this request.
    private weak var codeGenerator: CodeGenerator?

    // MARK: - Initializers

    public init(
      workspaceXML: String, completion: CompletionClosure? = nil, error: ErrorClosure? = nil)
    {
      self.workspaceXML = workspaceXML
      self.onCompletion = completion
      self.onError = error
    }

    public convenience init(
      workspace: Workspace, completion: CompletionClosure? = nil, error: ErrorClosure? = nil) throws
    {
      self.init(workspaceXML: try workspace.toXML().xmlString, completion: completion, error: error)
    }

    // MARK: - Super

    private var _executing: Bool = false
    public override var executing: Bool {
      get { return _executing }
      set {
        if _executing == newValue {
          return
        }
        willChangeValueForKey("isExecuting")
        _executing = newValue
        didChangeValueForKey("isExecuting")
      }
    }

    private var _finished: Bool = false;
    public override var finished: Bool {
      get { return _finished }
      set {
        if _finished == newValue {
          return
        }
        willChangeValueForKey("isFinished")
        _finished = newValue
        didChangeValueForKey("isFinished")
      }
    }

    public override func start() {
      if self.cancelled {
        return
      }

      self.executing = true

      codeGenerator?.executeCodeGenerationForRequest(self)
    }

    public override func cancel() {
      self.onCompletion = nil
      self.onError = nil
      super.cancel()
    }

    // MARK: - Private

    /**
     Called by `CodeGenerator` if the code generation was completely successfully.

     - Parameter code: The code that was generated
     */
    private func completeRequestWithCode(code: String) {
      if self.cancelled {
        return
      }

      dispatch_async(dispatch_get_main_queue()) {
        self.onCompletion?(code: code)
      }
      self.finished = true
    }

    /**
     Called by `CodeGenerator` if the code generation failed.

     - Parameter error: An error describing why the code generation failed
     */
    private func completeRequestWithError(error: String) {
      if self.cancelled {
        return
      }

      dispatch_async(dispatch_get_main_queue()) {
        self.onError?(error: error)
      }
      self.finished = true
    }
  }
}
