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
import WebKit

// MARK: - CodeGenerator Class

/**
 Helper for generating code from a workspace.

 This object is essentially a wrapper of a non-UI web version of Blockly, which generates workspace
 code via JavaScript. For more information on how this works, see:

 https://developers.google.com/blockly/installation/code-generators

 - note:
 - This object must be instantiated on the main thread, as it internally instantiates a
 `WKWebView` object (which has to be done on the main thread).
 - This object is not thread-safe.
 - Users should not use this class directly and instead should use `CodeGeneratorService`, which
 handles these problems.
 */
@objc(BKYCodeGenerator)
@objcMembers public final class CodeGenerator: NSObject {

  // MARK: - Static Properties

  /// Internal JS file that is used to communicate between the iOS code and JS code
  fileprivate static let CODE_GENERATOR_BRIDGE_JS = "CodeGenerator/code_generator_bridge.js"
  /// Internal JS file that implements `domToMutation(...)` functions for default blocks
  fileprivate static let CODE_GENERATOR_MUTATORS_JS = "CodeGenerator/code_generator_mutators.js"
  /// The name used to reference this iOS object when executing callbacks from the JS code.
  /// If this value is changed, it should also be changed in the `CODE_GENERATOR_BRIDGE_JS` file.
  fileprivate static let JS_CALLBACK_NAME = "CodeGenerator"

  // MARK: - Constants

  /// Possible states for the code generator
  @objc(BKYCodeGeneratorState)
  public enum State: Int {
    case
      /// Signifies the `CodeGenerator` has been initialized.
      initialized = 0,
      /// Signifies the `CodeGenerator` is currently loading.
      loading,
      /// Signifies the `CodeGenerator` is not loading or generating, and ready to be used.
      readyForUse,
      /// Signifies the `CodeGenerator` is unusable, due to a failure.
      unusable,
      /// Signifies the `CodeGenerator` is currently generating code.
      generatingCode
  }

  // MARK: - Closures

  public typealias LoadCompletionClosure = () -> Void
  public typealias LoadFailureClosure = (_ error: String) -> Void
  public typealias CompletionClosure = (_ code: String) -> Void
  public typealias ErrorClosure = (_ error: String) -> Void

  // MARK: - Properties

  /// List of core Blockly JS dependencies
  public let jsCoreDependencies: [BundledFile]
  /// The name of the JS object that generates code (e.g. 'Blockly.Python')
  public let jsGeneratorObject: String
  /// List of block generator JS files (e.g. ['python_compressed.js'])
  public let jsBlockGeneratorFiles: [BundledFile]
  /// List of JSON files containing block definitions
  public let jsonBlockDefinitionFiles: [BundledFile]
  /// The current state of the code generator
  public fileprivate(set) var state: State = .initialized

  /// The webview used for generating code
  fileprivate var webView: WKWebView!
  /// Handler responsible for interpreting messages from the JS code
  fileprivate var scriptMessageHandler: ScriptMessageHandler!
  /// Object for tracking the webview's initial load event
  fileprivate weak var loadingNavigation: WKNavigation?

  /// Callback that is executed when the web view has finished loading all necessary resources and
  /// the code generator is ready for use
  fileprivate var onLoadCompletion: LoadCompletionClosure?
  /// Callback that is executed when the web view has failed to load all necessary resources
  fileprivate var onLoadFailure: LoadFailureClosure?
  /// Callback that is executed when code generation completes successfully
  fileprivate var onCompletion: CompletionClosure?
  /// Callback that is executed when code generation fails
  fileprivate var onError: ErrorClosure?

  // MARK: - Initializers

  /**
   Creates a code generator, loading all specified JavaScript and JSON resources asynchronously.

   - parameter jsCoreDependencies: Paths to core Blockly JS dependencies. This
   list must contain the following files:
     - Blockly engine (eg. 'blockly_compressed.js')
     - A default list of messages (eg. 'msg/js/en.js')
   - parameter jsGeneratorObject: Name of the JS object that generates code
   (e.g. 'Blockly.Python' for generating Python code)
   - parameter jsBlockGenerators: Paths to JS generator files (e.g. 'python_compressed.js' for
   generating Python code)
   - parameter jsonBlockDefinitions: Paths to JSON files containing block definitions
   - parameter onLoadCompletion: Callback that is executed when all JavaScript and JSON resources
   have been successfully loaded (which indicates that this code generator is ready for use).
   - parameter onLoadFailure: Callback that is executed when there was a failure loading all
   JavaScript and JSON resources. If this callback is executed, this code generator's state is set
   to `.Unusable` and it should be discarded.
   */
  internal init(jsCoreDependencies: [BundledFile], jsGeneratorObject: String,
    jsBlockGeneratorFiles: [BundledFile], jsonBlockDefinitionFiles: [BundledFile],
    onLoadCompletion: LoadCompletionClosure?, onLoadFailure: LoadFailureClosure?)
  {
    self.jsCoreDependencies = jsCoreDependencies
    self.jsGeneratorObject = jsGeneratorObject
    self.jsBlockGeneratorFiles = jsBlockGeneratorFiles
    self.jsonBlockDefinitionFiles = jsonBlockDefinitionFiles
    self.onLoadCompletion = onLoadCompletion
    self.onLoadFailure = onLoadFailure

    super.init()

    // Create the handler for interpreting messages from the JS code
    let userContentController = WKUserContentController()
    self.scriptMessageHandler = ScriptMessageHandler(codeGenerator: self,
      userContentController: userContentController)

    let configuration = WKWebViewConfiguration()
    configuration.userContentController = userContentController

    // Create the web view
    self.webView = WKWebView(frame: CGRect.zero, configuration: configuration)
    self.webView.navigationDelegate = self

    // Set the initial state and load a blank page
    self.state = .loading
    self.loadingNavigation = self.webView.loadHTMLString("", baseURL: URL(string: "about:blank")!)
  }

  deinit {
    self.webView.navigationDelegate = nil
    self.webView.stopLoading()
    self.scriptMessageHandler.cleanUp()
  }

  // MARK: - Internal

  /**
   Generates code for workspace XML.

   - note: Only one request may be made at a time. If another request is still pending, this method
   will immediately execute the `error` block.

   - parameter workspaceXML: The workspace XML
   */
  internal func generateCodeForWorkspaceXML(
    _ workspaceXML: String, completion: @escaping CompletionClosure, error: @escaping ErrorClosure)
  {
    var errorMessage: String?
    switch (self.state) {
    case .generatingCode:
      errorMessage = "Another code generation request is still being processed. " +
        "Please wait until `self.state == .ReadyForUse`."
    case .initialized, .loading:
      errorMessage = "The code generator is not ready for use yet. " +
        "Please wait until `self.state == .ReadyForUse`."
    case .unusable:
      errorMessage = "This code generator is unusable. " +
        "Please check the JS/JSON dependencies used to create this `CodeGenerator`."
    case .readyForUse:
      break
    }

    if  errorMessage != nil {
      error(errorMessage!)
      return
    }

    self.state = .generatingCode
    self.onCompletion = completion
    self.onError = error

    // Remove unnecessary whitespace from the XML
    let trimmedXML = workspaceXML
      .replacingOccurrences(of: "\r", with: "")
      .replacingOccurrences(of: "\n", with: "")
      .replacingOccurrences(of: "\t", with: "")

    let js =
      "CodeGeneratorBridge.generateCodeForWorkspace(" +
        "\"\(trimmedXML.bky_escapedJavaScriptParameter())\", \(self.jsGeneratorObject))"

    DispatchQueue.main.async {
      // As of iOS 11, this call needs to be made from the main thread.
      self.webView.evaluateJavaScript(js, completionHandler: { (_, error) -> Void in
        if let error = error {
          self.codeGenerationFailed("An error occurred generating code: \(error)")
        }
      })
    }
  }

  // MARK: - Private

  /**
   Returns the `String` contents from a given file.

   - parameter bundledFile: The path to the file.
   - returns: The contents of the file.
   - throws:
   `BlocklyError`: Thrown if there was an error loading the file.
   */
  fileprivate func contents(ofBundledFile bundledFile: BundledFile) throws -> String {
    let fromBundle = bundledFile.bundle
    let file = bundledFile.path
    if let path = fromBundle.path(forResource: file, ofType: nil) {
      do {
        let string = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
        return string
      } catch let error {
        throw BlocklyError(.fileNotReadable, "File could not be read ('\(file)'):\n\(error)")
      }
    } else {
      throw BlocklyError(.fileNotFound, "File could not be found ('\(file)').")
    }
  }

  fileprivate func loadCompleted() {
    let onLoadCompletion = self.onLoadCompletion
    self.state = .readyForUse
    self.onLoadCompletion = nil
    self.onLoadFailure = nil
    onLoadCompletion?()
  }

  fileprivate func loadFailed(_ error: String) {
    let onLoadFailure = self.onLoadFailure
    self.state = .unusable
    self.onLoadCompletion = nil
    self.onLoadFailure = nil
    onLoadFailure?(error)
  }

  fileprivate func codeGenerationCompleted(_ code: String) {
    let onCompletion = self.onCompletion
    self.state = .readyForUse
    self.onCompletion = nil
    self.onError = nil
    onCompletion?(code)
  }

  fileprivate func codeGenerationFailed(_ error: String) {
    let onError = self.onError
    self.state = .readyForUse
    self.onCompletion = nil
    self.onError = nil
    onError?(error)
  }
}

// MARK: - WKNavigationDelegate implementation

/**
 Methods that are executed when `self.webView` has finished loading.
 */
extension CodeGenerator: WKNavigationDelegate {
  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    if self.loadingNavigation != navigation {
      return
    }

    self.loadingNavigation = nil

    do {
      // Load the JS/JSON dependencies into the web view.
      // NOTE: These resources aren't loaded using `WKUserScript`s as they don't seem to
      // consistently work (i.e. they don't always run after the web view has finished loading).
      // So instead, we just load all the resources through `webView.evaluateJavaScript(...)`.

      let bundle = Bundle(for: CodeGenerator.self)
      var jsScripts = [String]()

      // Load our special bridge file
      jsScripts.append(try contents(ofBundledFile:
        BundledFile(path: CodeGenerator.CODE_GENERATOR_BRIDGE_JS, bundle: bundle)))

      // Load JS dependencies
      for bundledFile in jsCoreDependencies {
        jsScripts.append(try contents(ofBundledFile: bundledFile))
      }

      // Load block generators
      for bundledFile in jsBlockGeneratorFiles {
        jsScripts.append(try contents(ofBundledFile: bundledFile))
      }

      // Load custom `domToMutation(...)` methods for known mutator blocks
      jsScripts.append(try contents(ofBundledFile:
        BundledFile(path: CodeGenerator.CODE_GENERATOR_MUTATORS_JS, bundle: bundle)))

      // Finally, import all the block definitions
      for bundledFile in jsonBlockDefinitionFiles {
        let fileContents = try contents(ofBundledFile: bundledFile)
        let fileContentsParameter = fileContents.bky_escapedJavaScriptParameter()
        let js = "CodeGeneratorBridge.importBlockDefinitions(\"\(fileContentsParameter)\")"
        jsScripts.append(js)
      }

      // The JS passed into webView.evaluateJavaScript(...) needs to return something that is
      // recognized, or else it will error out (WKErrorDomain = 5). Therefore, we add "0;" to
      // the very end of the scripts, which is what will be returned on completion.
      jsScripts.append("0;")

      let js = jsScripts.joined(separator: "\n")

      self.webView.evaluateJavaScript(js, completionHandler: { (_, error) -> Void in
        if let error = error {
          self.loadFailed("Could not evaluate JavaScript resource files: \(error)")
        } else {
          self.loadCompleted()
        }
      })
    } catch let error {
      self.loadFailed("Could not load resource files: \(error)")
    }
  }

  public func webView(
    _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error)
  {
    loadFailed("Could not load WKWebView: \(error)")
  }
}

// MARK: - CodeGenerator.ScriptMessageHandler class

extension CodeGenerator {
  /**
   Class for handling messages between the CodeGenerator's `webView` and iOS.

   - note: Because `WKUserContentController` keeps a strong reference to its message handlers, it is
   easier to separate message handling out of `CodeGenerator` and into its own class. This way,
   `CodeGenerator` can handle the task of breaking the strong reference cycle between
   `WKUserContentController` and `ScriptMessageHandler`, instead of relying on users of
   `CodeGenerator` to do this.
   */
  @objc(BKYCodeGeneratorScriptMessageHandler)
  fileprivate class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
    /// The code generator that owns this message handler
    fileprivate unowned let codeGenerator: CodeGenerator
    /// The user content controller this message handler attaches itself to
    fileprivate unowned let userContentController: WKUserContentController

    fileprivate init(codeGenerator: CodeGenerator, userContentController: WKUserContentController) {
      self.codeGenerator = codeGenerator
      self.userContentController = userContentController
      super.init()

      // Register self to handle messages from the JS code
      self.userContentController.add(self, name: CodeGenerator.JS_CALLBACK_NAME)
    }

    fileprivate func cleanUp() {
      // Unregister self from handling messages from the JS code
      self.userContentController.removeScriptMessageHandler(forName: CodeGenerator.JS_CALLBACK_NAME)
    }

    @objc func userContentController(_ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage)
    {
      if let dictionary = message.body as? [String: Any]
        , (dictionary["method"] as? String) == "generateCodeForWorkspace"
      {
        if let code = dictionary["code"] as? String {
          codeGenerator.codeGenerationCompleted(code)
        } else {
          let error = (dictionary["error"] as? String) ?? ""
          let message = "A JavaScript error occurred generating code for the workspace: \(error)"
          codeGenerator.codeGenerationFailed(message)
        }
      }
    }
  }
}
