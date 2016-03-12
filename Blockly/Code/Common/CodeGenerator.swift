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

 This object is essentially a wrapper of a non-UI web version of Blockly, which generates workspace
 code via JavaScript. For more information on how this works, see:
 https://developers.google.com/blockly/installation/code-generators

 Users should not use this class directly and instead should use `CodeGeneratorService`.

 - Note: This object must be instantiated on the main thread, as it internally instantiates a
`UIWebView` object (which has to be done on the main thread).
 */
@objc(BKYCodeGenerator)
public class CodeGenerator: NSObject {

  // MARK: - Typealiases
  public typealias CompletionClosure = (code: String) -> Void
  public typealias ErrorClosure = (error: String) -> Void
  /**
   Tuple defining where to find a local file.

   - Parameter file: The path to a local file
   - Parameter bundle: The bundle in which to find `file`. If nil is specified, the main bundle
   should be used.
  */
  public typealias BundledFile = (file: String, bundle: NSBundle?)

  // MARK: - Static Properties
  /// Internal JS file that is used to communicate between the iOS code and JS code
  private static let CODE_GENERATOR_BRIDGE_JS = "code_generator/code_generator_bridge.js"

  // MARK: - Properties

  /// List of core Blockly JS dependencies
  public let jsCoreDependencies: [BundledFile]
  /// The name of the JS object that generates code (e.g. 'Blockly.Python')
  public let jsGeneratorObject: String
  /// List of block generator JS files (e.g. ['python_compressed.js'])
  public let jsBlockGenerators: [BundledFile]
  /// List of JSON files containing block definitions
  public let jsonBlockDefinitions: [BundledFile]

  // TODO:(#15) Replace UIWebView with WKWebView
  /// The webview used for generating code
  private var webView: UIWebView!
  /// The underlying JSContext of `self.webView`
  private var jsContext: JSContext!

  /// Current workspaceXML being processed
  private var currentWorkspaceXML: String?
  /// Callback that is executed when code generation completes successfully
  private var onCompletion: CompletionClosure?
  /// Callback that is executed when code generation fails
  private var onError: ErrorClosure?

  // MARK: - Initializers

  /**
   Initializer for a code generator.

   - Parameter jsCoreDependencies: Paths to core Blockly JS dependencies. This
   list must contain the following files:
     - Blockly engine (eg. 'blockly_compressed.js')
     - Blockly default blocks (eg. 'blocks_compressed.js')
     - A default list of messages (eg. 'msg/js/en.js')
   - Parameter jsGeneratorObject: Name of the JS object that generates code
   (e.g. 'Blockly.Python' for generating Python code)
   - Parameter jsBlockGenerators: Paths to JS generator files (e.g. 'python_compressed.js' for
   generating Python code)
   - Parameter jsonBlockDefinitions: Paths to JSON files containing block definitions
   - Throws:
   `BlocklyError`: Thrown if any JS/JSON resource could not be loaded.
   */
  public init(jsCoreDependencies: [BundledFile], jsGeneratorObject: String,
    jsBlockGenerators: [BundledFile], jsonBlockDefinitions: [BundledFile]) throws
  {
    self.webView = UIWebView()
    self.webView.loadHTMLString("", baseURL: NSURL(string: "about:blank")!)
    self.jsContext =
      webView.valueForKeyPath("documentView.webView.mainFrame.javaScriptContext") as! JSContext
    self.jsCoreDependencies = jsCoreDependencies
    self.jsGeneratorObject = jsGeneratorObject
    self.jsBlockGenerators = jsBlockGenerators
    self.jsonBlockDefinitions = jsonBlockDefinitions

    super.init()

    // Register a handler if an exception is thrown in the JS code
    jsContext.exceptionHandler = { context, exception in
      let onError = self.onError
      self.reset()
      onError?(error: "JS Exception occurred: \(exception)")
    }

    // Load our special bridge file
    try loadJSFile((file: CodeGenerator.CODE_GENERATOR_BRIDGE_JS,
      bundle: NSBundle(forClass: CodeGenerator.self)))

    // Load JS dependencies
    for bundledFile in jsCoreDependencies {
      try loadJSFile(bundledFile)
    }

    // Load block generators
    for bundledFile in jsBlockGenerators {
      try loadJSFile(bundledFile)
    }

    // Load block definitions
    for bundledFile in jsonBlockDefinitions {
      try importBlockDefinitionsFromFile(bundledFile)
    }
  }

  deinit {
    self.webView.stopLoading()
  }

  // MARK: - Public

  /**
   Generates code for workspace XML.
   
   - Note: Only one request may be made at a time. If another request is still pending, this method
   will immediately execute the `error` block.

   - Parameter workspaceXML: The workspace XML
   */
  public func generateCodeForWorkspaceXML(
    workspaceXML: String, completion: CompletionClosure, error: ErrorClosure)
  {
    // Generate the code.
    // Note: If this request is called on a background thread, it can sometimes cause an
    // EXC_BAD_ACCESS to be thrown on a WebCore thread. Therefore, we have chosen to execute this
    // on the main thread as it doesn't seem to crash out. Luckily, generating code for a workspace
    // is a fast operation, so this *shouldn't* be a big performance hit.
    // TODO:(#14) Investigate the performance of this on a large workspace and look into using
    // Web Workers in the JS code instead.
    dispatch_async(dispatch_get_main_queue()) {
      if self.currentWorkspaceXML != nil {
        error(error: "Another code generation request is still being processed. " +
          "Maybe you should try using `CodeGeneratorService` instead.")
        return
      }

      self.currentWorkspaceXML = workspaceXML
      self.onCompletion = completion
      self.onError = error
      
      let generator = self.jsContext.evaluateScript(self.jsGeneratorObject)
      let method = self.jsContext.evaluateScript("CodeGeneratorBridge.generateCodeForWorkspace")
      let returnValue = method.callWithArguments([workspaceXML, generator])

      if let code = returnValue.toString() {
        // Success!
        let onCompletion = self.onCompletion
        self.reset()
        onCompletion?(code: code)
      } else {
        // Fail :(
        let onError = self.onError
        self.reset()
        onError?(error: "Could not convert return value into a String.")
      }
    }
  }

  // MARK: - Private

  private func reset() {
    self.currentWorkspaceXML = nil
    self.onCompletion = nil
    self.onError = nil
  }

  /**
   Imports block definitions from a given JSON file.

   - Parameter bundledFile: The path to the JSON file.
   - Throws:
   `BlocklyError`: Thrown if there was an error loading the JSON file.
   */
  private func importBlockDefinitionsFromFile(bundledFile: BundledFile) throws {
    let fromBundle = bundledFile.bundle ?? NSBundle.mainBundle()
    let file = bundledFile.file
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
   Loads a JS file into `self.webView`.

   - Parameter bundledFile: The path to the JS file.
   - Throws:
   `BlocklyError`: Thrown if there was an error loading the JS file.
   */
  private func loadJSFile(bundledFile: BundledFile) throws {
    let fromBundle = bundledFile.bundle ?? NSBundle.mainBundle()
    let file = bundledFile.file
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
