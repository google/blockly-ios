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

 Users should not use this class directly and instead should use `CodeGeneratorService`.

 - Note: This object must be instantiated on the main thread, as it internally instantiates a
 `WKWebView` object (which has to be done on the main thread).
 */
@objc(BKYCodeGenerator)
public class CodeGenerator: NSObject {

  // MARK: - Typealiases
  public typealias LoadCompletionClosure = (Void) -> Void
  public typealias LoadFailureClosure = (error: String) -> Void
  public typealias CompletionClosure = (code: String) -> Void
  public typealias ErrorClosure = (error: String) -> Void
  /**
   Tuple defining where to find a local file.

   - Parameter file: The path to a local file
   - Parameter bundle: The bundle in which to find `file`. If nil is specified, the main bundle
   should be used.
  */
  public typealias BundledFile = (file: String, bundle: NSBundle?)

  // MARK: - Enum - State
  public enum State {
    case Initialized, Loading, ReadyForUse, Unusable, GeneratingCode
  }

  // MARK: - Static Properties
  /// Internal JS file that is used to communicate between the iOS code and JS code
  private static let CODE_GENERATOR_BRIDGE_JS = "code_generator/code_generator_bridge.js"
  /// The name used to reference this iOS object when executing callbacks from the JS code.
  /// If this value is changed, it should also be changed in the `CODE_GENERATOR_BRIDGE_JS` file.
  private static let JS_CALLBACK_NAME = "CodeGenerator"

  // MARK: - Properties

  /// List of core Blockly JS dependencies
  public let jsCoreDependencies: [BundledFile]
  /// The name of the JS object that generates code (e.g. 'Blockly.Python')
  public let jsGeneratorObject: String
  /// List of block generator JS files (e.g. ['python_compressed.js'])
  public let jsBlockGenerators: [BundledFile]
  /// List of JSON files containing block definitions
  public let jsonBlockDefinitions: [BundledFile]
  /// The current state of the code generator
  public private(set) var state: State = .Initialized

  /// The webview used for generating code
  private var webView: WKWebView!
  /// Handler responsible for interpreting messages from the JS code
  private var scriptMessageHandler: ScriptMessageHandler!
  /// Object for tracking the webview's initial load event
  private weak var loadingNavigation: WKNavigation?

  /// Callback that is executed when the web view has finished loading all necessary resources and
  /// the code generator is ready for use
  private var onLoadCompletion: LoadCompletionClosure?
  /// Callback that is executed when the web view has failed to load all necessary resources
  private var onLoadFailure: LoadFailureClosure?
  /// Callback that is executed when code generation completes successfully
  private var onCompletion: CompletionClosure?
  /// Callback that is executed when code generation fails
  private var onError: ErrorClosure?

  // MARK: - Initializers

  /**
   Creates a code generator, loading all specified JavaScript and JSON resources asynchronously.

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
   - Parameter onLoadCompletion: Callback that is executed when all JavaScript and JSON resources
   have been successfully loaded (which indicates that this code generator is ready for use).
   - Parameter onLoadFailure: Callback that is executed when there was a failure loading all
   JavaScript and JSON resources. If this callback is executed, this code generator's state is set
   to `.Unusable` and it should be discarded.
   */
  public init(jsCoreDependencies: [BundledFile], jsGeneratorObject: String,
    jsBlockGenerators: [BundledFile], jsonBlockDefinitions: [BundledFile],
    onLoadCompletion: LoadCompletionClosure?, onLoadFailure: LoadFailureClosure?)
  {
    self.jsCoreDependencies = jsCoreDependencies
    self.jsGeneratorObject = jsGeneratorObject
    self.jsBlockGenerators = jsBlockGenerators
    self.jsonBlockDefinitions = jsonBlockDefinitions
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
    self.webView = WKWebView(frame: CGRectZero, configuration: configuration)
    self.webView.navigationDelegate = self

    // Set the initial state and load a blank page
    self.state = .Loading
    self.loadingNavigation = self.webView.loadHTMLString("", baseURL: NSURL(string: "about:blank")!)
  }

  deinit {
    self.webView.navigationDelegate = nil
    self.webView.stopLoading()
    self.scriptMessageHandler.cleanUp()
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
    var errorMessage: String?
    switch (self.state) {
    case .GeneratingCode:
      errorMessage = "Another code generation request is still being processed. " +
        "Please wait until `self.state == .ReadyForUse`."
    case .Initialized, .Loading:
      errorMessage = "The code generator is not ready for use yet. " +
        "Please wait until `self.state == .ReadyForUse`."
    case .Unusable:
      errorMessage = "This code generator is unusable. " +
        "Please check the JS/JSON dependencies used to create this `CodeGenerator`."
    case .ReadyForUse:
      break
    }

    if  errorMessage != nil {
      error(error: errorMessage!)
      return
    }

    self.state = .GeneratingCode
    self.onCompletion = completion
    self.onError = error

    // Remove unnecessary whitespace from the XML
    let trimmedXML = workspaceXML
      .stringByReplacingOccurrencesOfString("\r", withString: "")
      .stringByReplacingOccurrencesOfString("\n", withString: "")
      .stringByReplacingOccurrencesOfString("\t", withString: "")

    let js =
      "CodeGeneratorBridge.generateCodeForWorkspace(" +
        "\"\(trimmedXML.bky_escapedJavaScriptParameter())\", \(self.jsGeneratorObject))"

    self.webView.evaluateJavaScript(js, completionHandler: { _, error -> Void in
      if error != nil {
        self.codeGenerationFailed("An error occurred generating code: \(error)")
      }
    })
  }

  // MARK: - Private

  /**
  Returns the `String` contents from a given file.

  - Parameter bundledFile: The path to the file.
  - Returns: The contents of the file.
  - Throws:
  `BlocklyError`: Thrown if there was an error loading the file.
  */
  private func contentsOfFile(bundledFile: BundledFile) throws -> String {
    let fromBundle = bundledFile.bundle ?? NSBundle.mainBundle()
    let file = bundledFile.file
    if let path = fromBundle.pathForResource(file, ofType: nil) {
      do {
        let string = try String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        return string
      } catch let error as NSError {
        throw BlocklyError(.FileNotReadable, "File could not be read ('\(file)'):\n\(error)")
      }
    } else {
      throw BlocklyError(.FileNotFound, "File could not be found ('\(file)').")
    }
  }

  private func loadCompleted() {
    let onLoadCompletion = self.onLoadCompletion
    self.state = .ReadyForUse
    self.onLoadCompletion = nil
    self.onLoadFailure = nil
    onLoadCompletion?()
  }

  private func loadFailed(error: String) {
    let onLoadFailure = self.onLoadFailure
    self.state = .Unusable
    self.onLoadCompletion = nil
    self.onLoadFailure = nil
    onLoadFailure?(error: error)
  }

  private func codeGenerationCompleted(code: String) {
    let onCompletion = self.onCompletion
    self.state = .ReadyForUse
    self.onCompletion = nil
    self.onError = nil
    onCompletion?(code: code)
  }

  private func codeGenerationFailed(error: String) {
    let onError = self.onError
    self.state = .ReadyForUse
    self.onCompletion = nil
    self.onError = nil
    onError?(error: error)
  }
}

// MARK: - WKNavigationDelegate implementation

/**
 Methods that are executed when `self.webView` has finished loading.
 */
extension CodeGenerator: WKNavigationDelegate {
  public func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
    if self.loadingNavigation != navigation {
      return
    }

    self.loadingNavigation = nil

    do {
      // Load the JS/JSON dependencies into the web view.
      // NOTE: These resources aren't loaded using `WKUserScript`s as they don't seem to
      // consistently work (i.e. they don't always run after the web view has finished loading).
      // So instead, we just load all the resources through `webView.evaluateJavaScript(...)`.

      var jsScripts = [String]()

      // Load our special bridge file
      jsScripts.append(try contentsOfFile((file: CodeGenerator.CODE_GENERATOR_BRIDGE_JS,
        bundle: NSBundle(forClass: CodeGenerator.self))))

      // Load JS dependencies
      for bundledFile in jsCoreDependencies {
        jsScripts.append(try contentsOfFile(bundledFile))
      }

      // Load block generators
      for bundledFile in jsBlockGenerators {
        jsScripts.append(try contentsOfFile(bundledFile))
      }

      // Finally, import all the block definitions
      for bundledFile in jsonBlockDefinitions {
        let fileContents = try contentsOfFile(bundledFile)
        let fileContentsParameter = fileContents.bky_escapedJavaScriptParameter()
        let js = "CodeGeneratorBridge.importBlockDefinitions(\"\(fileContentsParameter)\")"
        jsScripts.append(js)
      }

      let js = jsScripts.joinWithSeparator("\n")

      self.webView.evaluateJavaScript(js, completionHandler: { (_, error) -> Void in
        if error != nil {
          self.loadFailed("Could not evaluate JavaScript resource files: \(error)")
        } else {
          self.loadCompleted()
        }
      })
    } catch let error as NSError {
      self.loadFailed("Could not load resource files: \(error)")
    }
  }

  public func webView(
    webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError)
  {
    loadFailed("Could not load WKWebView: \(error)")
  }
}

// MARK: - CodeGenerator.ScriptMessageHandler class

extension CodeGenerator {
  /**
   Class for handling messages between the CodeGenerator's `webView` and iOS.

   - Note: Because `WKUserContentController` keeps a strong reference to its message handlers, it is
   easier to separate message handling out of `CodeGenerator` and into its own class. This way,
   `CodeGenerator` can handle the task of breaking the strong reference cycle between
   `WKUserContentController` and `ScriptMessageHandler`, instead of relying on users of
   `CodeGenerator` to do this.
   */
  @objc(BKYCodeGeneratorScriptMessageHandler)
  private class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
    /// The code generator that owns this message handler
    private unowned let codeGenerator: CodeGenerator
    /// The user content controller this message handler attaches itself to
    private unowned let userContentController: WKUserContentController

    private init(codeGenerator: CodeGenerator, userContentController: WKUserContentController) {
      self.codeGenerator = codeGenerator
      self.userContentController = userContentController
      super.init()

      // Register self to handle messages from the JS code
      self.userContentController.addScriptMessageHandler(self, name: CodeGenerator.JS_CALLBACK_NAME)
    }

    private func cleanUp() {
      // Unregister self from handling messages from the JS code
      self.userContentController.removeScriptMessageHandlerForName(CodeGenerator.JS_CALLBACK_NAME)
    }

    @objc func userContentController(userContentController: WKUserContentController,
      didReceiveScriptMessage message: WKScriptMessage)
    {
      if let dictionary = message.body as? [String: AnyObject]
        where (dictionary["method"] as? String) == "generateCodeForWorkspace"
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
