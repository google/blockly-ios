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
  /// The default version of Blockly that is bundled with this framework
  private static let DEFAULT_WEB_BLOCKLY_JS = [
    "code_generator/blockly_web/blockly_compressed.js",
    "code_generator/blockly_web/blocks_compressed.js",
    "code_generator/blockly_web/msg/js/en.js",
  ]
  /// The default DART generator that is bundled with this framework
  private static let DEFAULT_DART_GENERATOR_JS = "code_generator/blockly_web/dart_compressed.js"
  /// The default JavaScript generator that is bundled with this framework
  private static let DEFAULT_JAVASCRIPT_GENERATOR_JS =
    "code_generator/blockly_web/javascript_compressed.js"
  /// The default PHP generator that is bundled with this framework
  private static let DEFAULT_PHP_GENERATOR_JS = "code_generator/blockly_web/php_compressed.js"
  /// The default Python generator that is bundled with this framework
  private static let DEFAULT_PYTHON_GENERATOR_JS = "code_generator/blockly_web/python_compressed.js"

  // MARK: - Properties

  /// The webview used for generating code
  private var webView: UIWebView!
  /// The underlying JSContext of `self.webView`
  private var jsContext: JSContext!
  /// The name of the JS object that generates code (e.g. 'Blockly.JavaScript')
  private var jsGeneratorObject: String
  /// The list of code generation requests to process
  private var requestQueue = [Request]()
  /// The current request being processed
  private var currentRequest: Request?

  // MARK: - Initializers

  /**
   Initializer for a code generator.
  
   - Parameter jsGeneratorObject: Name of the JS object that generates code
   (e.g. 'Blockly.JavaScript')
   - Parameter jsDependencies: Paths to all of the JS dependencies required to generate code. This
   list must contain the following files:
     - Blockly engine (eg. 'blockly_compressed.js')
     - Blockly default blocks (eg. 'blocks_compressed.js')
     - A default list of messages (eg. 'msg/js/en.js')
     - The code generator for the `jsGeneratorObject` (eg. 'javascript_compressed.js')
   - Parameter bundle: The bundle in which to find the files in `jsDependencies`. If this parameter
   is `nil`, the default main bundle is used.
   */
  public init(jsGeneratorObject: String, jsDependencies: [String], inBundle bundle: NSBundle? = nil)
  {
    self.webView = UIWebView()
    self.jsContext =
      webView.valueForKeyPath("documentView.webView.mainFrame.javaScriptContext") as! JSContext
    self.jsGeneratorObject = jsGeneratorObject

    super.init()

    // Register this object as the callback object for the JS context
    jsContext.setObject(self, forKeyedSubscript: CodeGenerator.JS_CALLBACK_NAME)
    jsContext.exceptionHandler = { context, exception in
      self.completeRequestWithError("JS Exception: \(exception)")
    }

    // Load our special bridge file
    loadJSFile(CodeGenerator.CODE_GENERATOR_BRIDGE_JS,
      inBundle: NSBundle(forClass: CodeGenerator.self))

    // Load dependencies
    for file in jsDependencies {
      loadJSFile(file, inBundle: bundle)
    }
  }

  /**
   Creates a DART code generator (using files bundled in this framework).
   */
  public class func dartCodeGenerator() -> CodeGenerator {
    return CodeGenerator(jsGeneratorObject: "Blockly.Dart",
      jsDependencies: DEFAULT_WEB_BLOCKLY_JS + [DEFAULT_DART_GENERATOR_JS],
      inBundle: NSBundle(forClass: CodeGenerator.self))
  }

  /**
   Creates a JavaScript code generator (using files bundled in this framework).
   */
  public class func javascriptCodeGenerator() -> CodeGenerator {
    return CodeGenerator(jsGeneratorObject: "Blockly.JavaScript",
      jsDependencies: DEFAULT_WEB_BLOCKLY_JS + [DEFAULT_JAVASCRIPT_GENERATOR_JS],
      inBundle: NSBundle(forClass: CodeGenerator.self))
  }

  /**
   Creates a Python code generator (using files bundled in this framework).
   */
  public class func pythonCodeGenerator() -> CodeGenerator {
    return CodeGenerator(jsGeneratorObject: "Blockly.Python",
      jsDependencies: DEFAULT_WEB_BLOCKLY_JS + [DEFAULT_PYTHON_GENERATOR_JS],
      inBundle: NSBundle(forClass: CodeGenerator.self))
  }

  /**
   Creates a PHP code generator (using files bundled in this framework).
   */
  public class func phpCodeGenerator() -> CodeGenerator {
    return CodeGenerator(jsGeneratorObject: "Blockly.PHP",
      jsDependencies: DEFAULT_WEB_BLOCKLY_JS + [DEFAULT_PHP_GENERATOR_JS],
      inBundle: NSBundle(forClass: CodeGenerator.self))
  }

  // MARK: - Public

  /**
   Imports block definitions from a given file.
  
   - Parameter file: The path to the file containing the block definitions.
   - Parameter bundle: The bundle in which to find `file`. If this parameter is nil, the default
   main bundle is used.
   */
  public func importBlockDefinitionsFromFile(file: String, inBundle bundle: NSBundle? = nil) -> Bool
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
   Imports custom block generators from a given file.

   - Parameter file: The path to the file containing the block generators.
   - Parameter bundle: The bundle in which to find `file`. If this parameter is nil, the default
   main bundle is used.
   */
  public func importBlockGeneratorsFromFile(file: String, inBundle bundle: NSBundle? = nil) -> Bool
  {
    return loadJSFile(file, inBundle: bundle)
  }

  /**
   Asynchronously generates code for a given request.
   
   - Parameter request: The request
   */
  public func generateCodeForRequest(request: Request) {
    requestQueue.append(request)
    processNextRequest()
  }

  // MARK: - Private

  private func processNextRequest() {
    dispatch_async(dispatch_get_main_queue()) { () -> Void in
      if self.requestQueue.isEmpty || self.currentRequest != nil {
        // There are no more requests or another request is already being processed. Do nothing.
        return
      }

      self.currentRequest = self.requestQueue.removeFirst()
      let generator = self.jsContext.evaluateScript(self.jsGeneratorObject)
      let method = self.jsContext.evaluateScript("CodeGeneratorBridge.generateCodeForWorkspace")
      method.callWithArguments([self.currentRequest!.workspaceXML, generator])
    }
  }

  private func completeRequestWithCode(code: String) {
    dispatch_async(dispatch_get_main_queue(), {
      self.currentRequest?.onCompletion?(code: code)
      self.currentRequest = nil
      self.processNextRequest()
    })
  }

  private func completeRequestWithError(error: String) {
    dispatch_async(dispatch_get_main_queue(), {
      self.currentRequest?.onError?(error: error)
      self.currentRequest = nil
      self.processNextRequest()
    })
  }

  private func loadJSFile(file: String, inBundle bundle: NSBundle? = nil) -> Bool {
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
