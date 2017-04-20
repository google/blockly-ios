/*
* Copyright 2015 Google Inc. All Rights Reserved.
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

import UIKit
import Blockly
import WebKit

/**
 Demo app for using blocks to move a cute little turtle.
 */
class TurtleSwiftViewController: UIViewController, TurtleViewControllerInterface {
  // MARK: - Static Properties
  /// The callback name to access this object from the JS code.
  /// See "turtle/turtle.js" for an example of its usage.
  static let JS_CALLBACK_NAME = "TurtleViewControllerCallback"

  // MARK: - Properties

  /// The view for holding `self.webView`
  @IBOutlet var webViewContainer: UIView!
  /// Text to show generated code
  @IBOutlet var codeText: UILabel!
  /// The view for holding `self.workbenchViewController.view`
  @IBOutlet var editorView: UIView!
  /// The play/cancel button
  @IBOutlet weak var playButton: UIButton!

  /// The web view that runs the turtle code (this is not an outlet because WKWebView isn't
  /// supported by Interface Builder)
  var _webView: WKWebView!
  /// The workbench for the blocks.
  lazy var _workbenchViewController: WorkbenchViewController = {
    // Load the block editor
    var workbenchViewController = WorkbenchViewController(style: .alternate)
    workbenchViewController.delegate = self
    workbenchViewController.toolboxDrawerStaysOpen = true
    return workbenchViewController
  }()

  /// Code generator service
  var _codeGeneratorService: CodeGeneratorService = {
    // Create the code generator service
    let codeGeneratorService = CodeGeneratorService(
      jsCoreDependencies: [
        // The JS file containing the Blockly engine
        "Turtle/blockly_web/blockly_compressed.js",
        // The JS file containing a list of internationalized messages
        "Turtle/blockly_web/msg/js/en.js"
      ])

    // Create builder for creating code generator service requests
    let builder = CodeGeneratorServiceRequestBuilder(
      // This is the name of the JS object that will generate JavaScript code
      jsGeneratorObject: "Blockly.JavaScript")
    builder.addJSBlockGeneratorFiles([
      // Use JavaScript code generators for the default blocks
      "Turtle/blockly_web/javascript_compressed.js",
      // Use JavaScript code generators for our custom turtle blocks
      "Turtle/generators.js"])
    // Load the block definitions for all default blocks
    builder.addJSONBlockDefinitionFiles(fromDefaultFiles: .allDefault)
    // Load the block definitions for our custom turtle blocks
    builder.addJSONBlockDefinitionFiles(["Turtle/turtle_blocks.json"])

    // Set the request builder for the CodeGeneratorService.
    codeGeneratorService.setRequestBuilder(builder, shouldCache: true)

    return codeGeneratorService
  }()

  /// Flag indicating whether the code is currently running.
  var _currentlyRunning: Bool = false
  /// Flag indicating if highlighting a block is enabled.
  var _allowBlockHighlighting: Bool = false
  /// Flag indicating if scrolling a block into view is enabled.
  var _allowScrollingToBlockView: Bool = false
  /// The UUID of the last block that was highlighted.
  var _lastHighlightedBlockUUID: String?
  /// The UUID of the current code generation request.
  var _currentRequestUUID: String? = ""

  /// Date formatter for timestamping events
  let _dateFormatter = DateFormatter()

  // MARK: - Initializers

  public init() {
    // Load from xib file
    super.init(nibName: "TurtleViewController", bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  deinit {
    // If the Turtle code is currently executing, we need to reset it before deallocating this
    // instance.
    if let webView = _webView {
      webView.configuration.userContentController.removeScriptMessageHandler(
        forName: TurtleSwiftViewController.JS_CALLBACK_NAME)
      webView.stopLoading()
    }
    resetTurtleCode()
    _codeGeneratorService.cancelAllRequests()
  }

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    // Don't allow the navigation controller bar cover this view controller
    self.edgesForExtendedLayout = UIRectEdge()
    self.navigationItem.title = "Swift Turtle Demo"

    // Load default blocks into the block factory
    _workbenchViewController.blockFactory.load(fromDefaultFiles: .allDefault)

    // Load custom turtle blocks into the block factory
    do {
      try _workbenchViewController.blockFactory.load(fromJSONPaths: ["Turtle/turtle_blocks.json"])
    } catch let error {
      print("An error occurred loading the turtle blocks: \(error)")
    }

    // Load the toolbox
    do {
      let toolboxPath = "Turtle/toolbox.xml"
      if let bundlePath = Bundle.main.path(forResource: toolboxPath, ofType: nil) {
        let xmlString = try String(contentsOfFile: bundlePath, encoding: String.Encoding.utf8)
        let toolbox = try Toolbox.makeToolbox(xmlString: xmlString,
                                              factory: _workbenchViewController.blockFactory)
        try _workbenchViewController.loadToolbox(toolbox)
      } else {
        print("Could not load toolbox XML from '\(toolboxPath)'")
      }
    } catch let error {
      print("An error occurred loading the toolbox: \(error)")
    }

    addChildViewController(_workbenchViewController)
    editorView.autoresizesSubviews = true
    _workbenchViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    _workbenchViewController.view.frame = editorView.bounds
    editorView.addSubview(_workbenchViewController.view)
    _workbenchViewController.didMove(toParentViewController: self)

    // Programmatically create WKWebView and configure it with a hook so the JS code can callback
    // into the iOS code.
    let userContentController = WKUserContentController()
    userContentController.add(ScriptMessageHandler(self),
                              name: TurtleSwiftViewController.JS_CALLBACK_NAME)

    let configuration = WKWebViewConfiguration()
    configuration.userContentController = userContentController

    _webView = WKWebView(frame: webViewContainer.bounds, configuration: configuration)
    _webView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    _webView.translatesAutoresizingMaskIntoConstraints = true
    webViewContainer.autoresizesSubviews = true
    webViewContainer.addSubview(_webView)

    // Load the turtle executable code
    if let url = Bundle.main.url(forResource: "Turtle/turtle", withExtension: "html") {
      _webView.load(URLRequest(url: url))
    } else {
      print("Couldn't load Turtle/turtle.html")
    }

    // Make things a bit prettier
    _webView.layer.borderColor = UIColor.lightGray.cgColor
    _webView.layer.borderWidth = 1
    codeText.superview?.layer.borderColor = UIColor.lightGray.cgColor
    codeText.superview?.layer.borderWidth = 1
    _dateFormatter.dateFormat = "HH:mm:ss.SSS"
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    _codeGeneratorService.cancelAllRequests()
  }

  override var prefersStatusBarHidden : Bool {
    return true
  }

  // MARK: - Private

  @IBAction internal dynamic func didPressPlay(_ button: UIButton) {
    do {
      if _currentlyRunning {
        if (_currentRequestUUID != "") {
          guard let uuid = _currentRequestUUID else {
            print("Error: The current request UUID is nil.")
            return
          }

          _codeGeneratorService.cancelRequest(uuid: uuid)
        } else {
          _webView.evaluateJavaScript("Turtle.cancel()", completionHandler: nil)
        }
        self.resetRequests()
      } else {
        if let workspace = _workbenchViewController.workspace {
          // Reset the turtle
          resetTurtleCode()

          self.codeText.text = ""
          addTimestampedText("Generating code...")

          // Request code generation for the workspace
          _currentRequestUUID =
            try _codeGeneratorService.generateCode(
              forWorkspace: workspace,
              onCompletion: { requestUUID, code in
                self.codeGenerationCompleted(code: code)
              },
              onError: { requestUUID, error in
                self.codeGenerationFailed(error: error)
              })

          playButton.isEnabled = false
        }
      }
    } catch let error {
      print("An error occurred generating code for the workspace: \(error)")
    }
  }

  fileprivate func codeGenerationCompleted(code: String) {
    addTimestampedText("Generated code:\n\n====CODE====\n\n\(code)")

    _currentRequestUUID = ""
    runCode(code)
  }

  fileprivate func codeGenerationFailed(error: String) {
    addTimestampedText("An error occurred:\n\n====ERROR====\n\n\(error)")

    resetRequests()
  }

  fileprivate func resetRequests() {
    _currentlyRunning = false
    _currentRequestUUID = ""
    playButton.isEnabled = true
    playButton.setImage(UIImage(named: "play_button"), for: .normal)
    playButton.setTitle("Run Code", for: .normal)
  }

  fileprivate func runCode(_ code: String) {
    // Allow block highlighting and scrolling a block into view (it can only be disabled by explicit
    // user interaction)
    _allowBlockHighlighting = true
    _allowScrollingToBlockView = true

    playButton.setImage(UIImage(named: "cancel_button"), for: .normal)
    playButton.setTitle("Stop Turtle", for: .normal)
    playButton.isEnabled = true
    _currentlyRunning = true

    // Run the generated code in the web view by calling `Turtle.execute(<code>)`
    let codeParam = code.bky_escapedJavaScriptParameter()
    _webView.evaluateJavaScript(
      "Turtle.execute(\"\(codeParam)\")",
      completionHandler: { _, error -> Void in
        if let error = error {
          self.codeGenerationFailed(error: "\(error)")
        }
      })
  }

  fileprivate func resetTurtleCode() {
    _webView?.evaluateJavaScript("Turtle.reset();", completionHandler: nil)
  }

  fileprivate func addTimestampedText(_ text: String) {
    // TODO(#268): Replace Turtle with a version that uses JS Interpreter
    var trimmedText = ""
    let lines = text.components(separatedBy: "\n")
    for line in lines {
      if (!line.contains("window.LoopTrap")) {
        // Trim out the loop trap lines that are automatically-generated.
        trimmedText = trimmedText.appending(line + "\n")
      }
    }
    self.codeText.text = (self.codeText.text ?? "") +
      "[\(_dateFormatter.string(from: Date()))] \(trimmedText)\n"
  }
}

/**
 Because WKUserContentController makes a strong retain cycle to its delegate, we create an
 intermediary object here to act as a delegate so we can more easily break a potential retain cycle
 between WKUserContentController and TurtleSwiftViewController.
 */
class ScriptMessageHandler : NSObject, WKScriptMessageHandler {
  weak var delegate : WKScriptMessageHandler?

  init(_ delegate: WKScriptMessageHandler) {
    self.delegate = delegate
    super.init()
  }

  func userContentController(_ userContentController: WKUserContentController,
                             didReceive message: WKScriptMessage)
  {
    // Call "real" delegate (which is TurtleSwiftViewController)
    self.delegate?.userContentController(userContentController, didReceive: message)
  }
}

// MARK: - WKScriptMessageHandler implementation

/**
 Handler responsible for relaying messages back from `self.webView`.
 */
extension TurtleSwiftViewController: WKScriptMessageHandler {
  @objc func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage)
  {
    guard let dictionary = message.body as? [String: AnyObject],
      let method = dictionary["method"] as? String else
    {
      return
    }

    switch method {
      case "highlightBlock":
        if let blockID = dictionary["blockID"] as? String {
          if _allowBlockHighlighting {
            _workbenchViewController.highlightBlock(blockUUID: blockID)
            _lastHighlightedBlockUUID = blockID
          }
          if _allowScrollingToBlockView {
            _workbenchViewController.scrollBlockIntoView(blockUUID: blockID, animated: true)
          }
        }
      case "unhighlightLastBlock":
        if let blockID = _lastHighlightedBlockUUID {
          _workbenchViewController.unhighlightBlock(blockUUID: blockID)
          _lastHighlightedBlockUUID = blockID
        }
      case "finishExecution":
        self.resetRequests()
      default:
        print("Unrecognized method")
    }
  }
}

// MARK: - WorkbenchViewControllerDelegate implementation

extension TurtleSwiftViewController: WorkbenchViewControllerDelegate {
  func workbenchViewController(_ workbenchViewController: WorkbenchViewController,
                               didUpdateState state: WorkbenchViewController.UIState)
  {
    // We need to disable automatic block view scrolling / block highlighting based on the latest
    // user interaction.

    // Only allow automatic scrolling if the user tapped on the workspace.
    _allowScrollingToBlockView = state.isSubset(of: [.didTapWorkspace])

    // Only allow block highlighting if the user tapped/panned the workspace or opened either the
    // toolbox or trash can.
    _allowBlockHighlighting =
      state.isSubset(of: [.didTapWorkspace, .didPanWorkspace, .categoryOpen, .trashCanOpen])
  }
}
