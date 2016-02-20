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

// MARK: - CodeGeneratorCallback Protocol

/**
 Protocol that declares which methods inside `CodeGenerator` should be exposed to JSContext for
 callback purposes.
 */
@objc private protocol CodeGeneratorCallback: JSExport {
  /**
   Callback that should be called when the JS context has finished generating code.
   */
  func codeGenerationFinishedWithValue(code: String)
}

// MARK: - CodeGenerator Class

/**
 Helper for generating code from a workspace.

 This helper is actually a wrapper of a non-UI web version of Blockly, which generates workspace
 code via JavaScript. For more information on how this works, see:
 https://developers.google.com/blockly/installation/code-generators
 */
@objc(BKYCodeGenerator)
public class CodeGenerator: NSObject {

  // MARK: - Static Properties
  /// Internal JS file that is used to communicate between the iOS code and JS code
  private static let CODE_GENERATOR_BRIDGE_JS = "code_generator/code_generator_bridge.js"
  /// The name used to reference this iOS object when executing callbacks from the JS code.
  /// If this value is changed, it should also be changed in the `CODE_GENERATOR_BRIDGE_JS` file.
  private static let JS_CALLBACK_NAME = "CodeGenerator"

  // MARK: - Properties

  /// The webview used for generating code
  private var webView: UIWebView!
  /// The underlying JSContext of `self.webView`
  private var jsContext: JSContext!
  /// The name of the JS object that generates code (e.g. 'Blockly.JavaScript')
  private var jsGeneratorObject: String
  /// The current request being processed
  private var currentRequest: Request?
  /// Semaphore used to process requests ( allows one request to be processed at a time)
  private let requestSemaphore = dispatch_semaphore_create(1)

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
   */
  public init(jsGeneratorObject: String, jsDependencies: [String], bundle: NSBundle? = nil)
  {
    self.webView = UIWebView()
    self.jsContext =
      webView.valueForKeyPath("documentView.webView.mainFrame.javaScriptContext") as! JSContext
    self.jsGeneratorObject = jsGeneratorObject

    super.init()

    // Register this object as the callback object for the JS context
    jsContext.setObject(self, forKeyedSubscript: CodeGenerator.JS_CALLBACK_NAME)
    // Register a handler if an exception is thrown in the JS code
    jsContext.exceptionHandler = { context, exception in
      self.completeRequestWithError("JS Exception: \(exception)")
    }

    // Load our special bridge file
    loadJSFile(CodeGenerator.CODE_GENERATOR_BRIDGE_JS,
      bundle: NSBundle(forClass: CodeGenerator.self))

    // Load dependencies
    for file in jsDependencies {
      loadJSFile(file, bundle: bundle)
    }
  }

  // MARK: - Public

  /**
   Imports block definitions from a given JSON file.

   - Parameter file: The path to the file containing the JSON block definitions.
   - Parameter bundle: The bundle in which to find `file`. If this parameter is nil, the default
   main bundle is used.
   */
  public func importBlockDefinitionsFromFile(file: String, bundle: NSBundle? = nil) -> Bool
  {
    let fromBundle = bundle ?? NSBundle.mainBundle()
    guard let path = fromBundle.pathForResource(file, ofType: nil) else {
      return false
    }

    do {
      let string = try String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
      let method = jsContext.evaluateScript("CodeGeneratorBridge.importBlockDefinitions")
      method.callWithArguments([string])
    } catch let error as NSError {
      bky_print("Error importing block definitions from file '\(file)': \(error)")
    }

    return true
  }

  /**
   Imports custom block generators from a given JavaScript file.

   - Parameter file: The path to the JavaScript file containing the block generators.
   - Parameter bundle: The bundle in which to find `file`. If this parameter is nil, the default
   main bundle is used.
   */
  public func importBlockGeneratorsFromFile(file: String, bundle: NSBundle? = nil) -> Bool
  {
    return loadJSFile(file, bundle: bundle)
  }

  /**
   Asynchronously generates code for a given request.

   - Parameter request: The request
   */
  public func generateCodeForRequest(request: Request) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
      // Wait for a signal
      dispatch_semaphore_wait(self.requestSemaphore, DISPATCH_TIME_FOREVER)

      self.currentRequest = request

      // Generate the code using the main thread (
      let generator = self.jsContext.evaluateScript(self.jsGeneratorObject)
      let method = self.jsContext.evaluateScript("CodeGeneratorBridge.generateCodeForWorkspace")
      method.callWithArguments([self.currentRequest!.workspaceXML, generator])

//        self.completeRequestWithCode(code.toString())
//      } else {
//        self.completeRequestWithError("Could not convert return value into a String")
//      }

//      dispatch_async(dispatch_get_main_queue()) {
//        let generator = self.jsContext.evaluateScript(self.jsGeneratorObject)
//        let method = self.jsContext.evaluateScript("CodeGeneratorBridge.requestCodeForWorkspace")
//        method.callWithArguments([self.currentRequest!.workspaceXML, generator])
//      }
    }
  }

  // MARK: - Private

  private func completeRequestWithCode(code: String) {
    dispatch_async(dispatch_get_main_queue()) {
      self.currentRequest?.onCompletion?(code: code)
      self.currentRequest = nil

      // Signal the semaphore
      dispatch_semaphore_signal(self.requestSemaphore)
    }
  }

  private func completeRequestWithError(error: String) {
    dispatch_async(dispatch_get_main_queue()) {
      self.currentRequest?.onError?(error: error)
      self.currentRequest = nil

      // Signal the semaphore
      dispatch_semaphore_signal(self.requestSemaphore)
    }
  }

  private func loadJSFile(file: String, bundle: NSBundle? = nil) -> Bool {
    let fromBundle = bundle ?? NSBundle.mainBundle()
    if let path = fromBundle.pathForResource(file, ofType: nil) {
      do {
        let string = try String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        jsContext.evaluateScript(string)
        return true
      } catch let error as NSError {
        bky_print("Error loading JS file '\(file)': \(error)")
      }
    }
    return false
  }
}

// MARK: - CodeGeneratorCallback methods

/**
 List of all the callback methods that are executed from the JS code.
 */
extension CodeGenerator: CodeGeneratorCallback {
  @objc public func codeGenerationFinishedWithValue(code: String) {
    completeRequestWithCode(code)
  }
}

// MARK: - CodeGenerator.Request Class

extension CodeGenerator {
  /**
   Request object for generating code for a workspace.
   */
  public class Request {
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
  }
}
