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
class TurtleViewController: UIViewController {
  // MARK: - Static Properties
  /// The callback name to access this object from the JS code.
  /// See "turtle/turtle.js" for an example of its usage.
  static let JS_CALLBACK_NAME = "TurtleViewControllerCallback"

  // MARK: - Properties

  /// The view for holding `self.webView`
  @IBOutlet var webViewContainer: UIView!
  /// The button for executing the block code
  @IBOutlet var playButton: UIButton!
  /// Text to show generated code
  @IBOutlet var codeText: UILabel!
  /// The view for holding `self.workbenchViewController.view`
  @IBOutlet var editorView: UIView!

  /// The web view that runs the turtle code (this is not an outlet because WKWebView isn't
  /// supported by Interface Builder)
  var _webView: WKWebView!
  /// The block editor
  var _workbenchViewController: WorkbenchViewController!

  /// Code generator service
  lazy var _codeGeneratorService: CodeGeneratorService = {
    // Create the code generator service
    let codeGeneratorService = CodeGeneratorService(
      jsCoreDependencies: [
        // The JS file containing the Blockly engine
        "Turtle/blockly_web/blockly_compressed.js",
        // The JS file containing a list of internationalized messages
        "Turtle/blockly_web/msg/js/en.js"
      ])
    return codeGeneratorService
  }()

  /// Builder for creating code generator service requests
  lazy var _codeGeneratorServiceRequestBuilder: CodeGeneratorServiceRequestBuilder = {
    let builder = CodeGeneratorServiceRequestBuilder(
      // This is the name of the JS object that will generate JavaScript code
      jsGeneratorObject: "Blockly.JavaScript")
    builder.addJSBlockGeneratorFiles([
      // Use JavaScript code generators for the default blocks
      "Turtle/blockly_web/javascript_compressed.js",
      // Use JavaScript code generators for our custom turtle blocks
      "Turtle/generators.js"])
    // Load the block definitions for all default blocks
    builder.addJSONBlockDefinitionFiles(fromDefaultFiles: .AllDefault)
    // Load the block definitions for our custom turtle blocks
    builder.addJSONBlockDefinitionFiles(["Turtle/turtle_blocks.json"])

    // Note: A single set of request listeners like this is sufficient for most cases, but
    // dynamic completion and error listeners may be created for each call if needed.
    builder.onCompletion = self.codeGenerationCompletedWithCode
    builder.onError = self.codeGenerationFailedWithError

    return builder
  }()

  /// Factory that produces block instances
  lazy var _blockFactory: BlockFactory = {
    let blockFactory = BlockFactory()

    // Load default blocks into the block factory
    blockFactory.load(fromDefaultFiles: [.AllDefault])

    // Load custom turtle blocks into the block factory
    do {
      try blockFactory.load(fromJSONPaths: ["Turtle/turtle_blocks.json"])
    } catch let error as NSError {
      print("An error occurred loading the turtle blocks: \(error)")
    }

    return blockFactory
  }()

  /// Flag indicating if highlighting a block should be enabled
  var _allowBlockHighlighting: Bool = false
  /// Flag indicating if scrolling a block into view should be enabled
  var _allowScrollingToBlockView: Bool = false
  /// The UUID of the last block that was highlighted
  var _lastHighlightedBlockUUID: String?

  /// Date formatter for timestamping events
  let _dateFormatter = DateFormatter()

  // MARK: - Initializers

  init() {
    // Load from xib file
    super.init(nibName: "TurtleViewController", bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  deinit {
    // If the Turtle code is currently executing, we need to reset it before deallocating this
    // instance.
    _webView?.stopLoading()
    resetTurtleCode()
    _codeGeneratorService.cancelAllRequests()
  }

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    // Don't allow the navigation controller bar cover this view controller
    self.edgesForExtendedLayout = UIRectEdge()
    self.navigationItem.title = "Turtle Demo"

    // Load the block editor
    _workbenchViewController = WorkbenchViewController(style: .alternate)
    _workbenchViewController.delegate = self
    _workbenchViewController.toolboxDrawerStaysOpen = true

    // Create a workspace
    do {
      let workspace = Workspace()

      try _workbenchViewController.loadWorkspace(workspace)
    } catch let error as NSError {
      print("Couldn't load the workspace: \(error)")
    }

    // Load the toolbox
    do {
      let toolboxPath = "Turtle/level_1/toolbox.xml"
      if let bundlePath = Bundle.main.path(forResource: toolboxPath, ofType: nil) {
        let xmlString = try String(contentsOfFile: bundlePath, encoding: String.Encoding.utf8)
        let toolbox = try Toolbox.makeToolbox(xmlString: xmlString, factory: _blockFactory)
        try _workbenchViewController.loadToolbox(toolbox)
      } else {
        print("Could not load toolbox XML from '\(toolboxPath)'")
      }
    } catch let error as NSError {
      print("An error occurred loading the toolbox: \(error)")
    }

    self.editorView.autoresizesSubviews = true
    _workbenchViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    _workbenchViewController.view.frame = self.editorView.bounds
    self.editorView.addSubview(_workbenchViewController.view)
    self.addChildViewController(_workbenchViewController)

    // Programmatically create WKWebView, configuring it with a hook so the JS code can callback
    // into the iOS code
    let userContentController = WKUserContentController()
    userContentController.add(self, name: TurtleViewController.JS_CALLBACK_NAME)

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

  @IBAction fileprivate dynamic func didPressPlayButton(_ button: UIButton) {
    do {
      if let workspace = _workbenchViewController.workspace {
        // Cancel pending requests
        _codeGeneratorService.cancelAllRequests()

        // Reset the turtle
        resetTurtleCode()

        self.codeText.text = ""
        addTimestampedText("Generating code...")

        // Request code generation for the workspace
        let request = try _codeGeneratorServiceRequestBuilder.makeRequest(forWorkspace: workspace)
        _codeGeneratorService.generateCode(forRequest: request)
      }
    } catch let error as NSError {
      print("An error occurred generating code for the workspace: \(error)")
    }
  }

  fileprivate func codeGenerationCompletedWithCode(_ code: String) {
    self.addTimestampedText("Generated code:\n\n====CODE====\n\n\(code)")

    runCode(code)
  }

  fileprivate func codeGenerationFailedWithError(_ error: String) {
    self.addTimestampedText("An error occurred:\n\n====ERROR====\n\n\(error)")
  }

  fileprivate func runCode(_ code: String) {
    // Allow block highlighting and scrolling a block into view (it can only be disabled by explicit
    // user interaction)
    _allowBlockHighlighting = true
    _allowScrollingToBlockView = true

    // Run the generated code in the web view by calling `Turtle.execute(<code>)`
    let codeParam = code.bky_escapedJavaScriptParameter()
    _webView.evaluateJavaScript(
      "Turtle.execute(\"\(codeParam)\")",
      completionHandler: { _, error -> Void in
        if error != nil {
          self.codeGenerationFailedWithError("\(error)")
        }
      })
  }

  fileprivate func resetTurtleCode() {
    _webView?.evaluateJavaScript("Turtle.reset();", completionHandler: nil)
  }

  fileprivate func addTimestampedText(_ text: String) {
    self.codeText.text = (self.codeText.text ?? "") +
      "[\(_dateFormatter.string(from: Date()))] \(text)\n"
  }

  /**
   Create a block, with an optional input child block, and add them to a toolbox category.

   - Parameter blockName: The name of the block to create from the block factory.
   - Parameter inputBlockName: (Optional) If specified, the name of a block to create from the
   block factory, which is automatically connected to the first input of the block created via
   `blockName`.
   - Parameter category: The toolbox category to add these blocks to.
   - Returns: The root block that was added to the category.
   */
  fileprivate func addBlock(_ blockName: String,
    inputBlockName: String? = nil, toCategory category: Toolbox.Category) throws -> Block
  {
    let block = try _blockFactory.makeBlock(name: blockName)

    // Connect an input block (if it was specified).
    // Note: We keep a reference to the input block in this scope, so it isn't deallocated before
    // the block tree is added to the category
    let childBlock: Block?

    if let anInputBlockName = inputBlockName,
      let inputBlock = try? _blockFactory.makeBlock(name: anInputBlockName),
      block.inputs.count > 0
    {
      childBlock = inputBlock
      try block.inputs[0].connection?.connectTo(childBlock?.inferiorConnection)
    }

    // Add the block tree to the category
    try category.addBlockTree(block)

    return block
  }
}

// MARK: - WKScriptMessageHandler implementation

/**
 Handler responsible for relaying messages back from `self.webView`.
 */
extension TurtleViewController: WKScriptMessageHandler {
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
      default:
        print("Unrecognized method")
    }
  }
}

// MARK: - WorkbenchViewControllerDelegate implementation

extension TurtleViewController: WorkbenchViewControllerDelegate {
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
