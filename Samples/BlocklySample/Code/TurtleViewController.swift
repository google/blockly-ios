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
  // MARK: - Properties

  /// The view for holding `self.webView`
  @IBOutlet private var webViewContainer: UIView!
  /// The button for executing the block code
  @IBOutlet private var playButton: UIButton!
  /// Text to show generated code
  @IBOutlet private var codeText: UILabel!
  /// The view for holding `self.workbenchViewController.view`
  @IBOutlet private var editorView: UIView!

  /// The web view that runs the turtle code (this is not an outlet because WKWebView isn't
  /// supported by Interface Builder)
  private var _webView: WKWebView!
  /// The block editor
  private var _workbenchViewController: WorkbenchViewController!
  /// Code generator service
  private var _codeGeneratorService: CodeGeneratorService!

  /// Factory that produces block instances from a parsed json file
  private var _blockFactory: BlockFactory!

  /// Date formatter for timestamping events
  private var _dateFormatter = NSDateFormatter()

  // MARK: - Initializers

  init() {
    // Load from xib file
    super.init(nibName: "TurtleViewController", bundle: nil)
    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    // Load the block factory
    do {
      _blockFactory = try BlockFactory(jsonPaths: [
        "Turtle/turtle_blocks.json",
        "Blocks/colour_blocks.json",
        "Blocks/math_blocks.json",
        "Blocks/loop_blocks.json"
        ])
    } catch let error as NSError {
      print("An error occurred loading the test blocks: \(error)")
    }

    // Create the code generator service
    _codeGeneratorService = CodeGeneratorService(
      jsCoreDependencies: [
        // The JS file containing the Blockly engine
        (file: "Turtle/blockly_web/blockly_compressed.js", bundle: nil),
        // The JS file containing all Blockly default blocks
        (file: "Turtle/blockly_web/blocks_compressed.js", bundle: nil),
        // The JS file containing a list of internationalized messages
        (file: "Turtle/blockly_web/msg/js/en.js", bundle: nil)
      ])
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
    self.edgesForExtendedLayout = .None
    self.navigationItem.title = "Turtle Demo"

    // Load the block editor
    self._workbenchViewController = WorkbenchViewController(style: .Default)

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
      if let bundlePath = NSBundle.mainBundle().pathForResource(toolboxPath, ofType: nil) {
        let xmlString = try String(contentsOfFile: bundlePath, encoding: NSUTF8StringEncoding)
        let toolbox = try Toolbox.toolboxFromXMLString(xmlString, factory: _blockFactory)
        try _workbenchViewController.loadToolbox(toolbox)
      } else {
        print("Could not load toolbox XML from '\(toolboxPath)'")
      }
    } catch let error as NSError {
      print("An error occurred loading the toolbox: \(error)")
    }

    self.editorView.autoresizesSubviews = true
    _workbenchViewController.view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
    _workbenchViewController.view.frame = self.editorView.bounds
    self.editorView.addSubview(_workbenchViewController.view)
    self.addChildViewController(_workbenchViewController)

    // Programmatically create WKWebView
    _webView = WKWebView(frame: webViewContainer.bounds)
    _webView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    _webView.translatesAutoresizingMaskIntoConstraints = true
    webViewContainer.autoresizesSubviews = true
    webViewContainer.addSubview(_webView)

    // Load the turtle executable code
    if let url = NSBundle.mainBundle().URLForResource("Turtle/turtle", withExtension: "html") {
      _webView.loadRequest(NSURLRequest(URL: url))
    } else {
      print("Couldn't load Turtle/turtle.html")
    }

    // Make things a bit prettier
    _webView.layer.borderColor = UIColor.lightGrayColor().CGColor
    _webView.layer.borderWidth = 1
    codeText.superview?.layer.borderColor = UIColor.lightGrayColor().CGColor
    codeText.superview?.layer.borderWidth = 1
    _dateFormatter.dateFormat = "HH:mm:ss.SSS"
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)

    _codeGeneratorService.cancelAllRequests()
  }

  override func prefersStatusBarHidden() -> Bool {
    return true
  }

  // MARK: - Private

  @IBAction private dynamic func didPressPlayButton(button: UIButton) {
    do {
      if let workspace = _workbenchViewController.workspace {
        // Cancel pending requests
        _codeGeneratorService.cancelAllRequests()

        // Reset the turtle
        resetTurtleCode()

        self.codeText.text = ""
        addTimestampedText("Generating code...")

        // Request code generation.
        let request = try CodeGeneratorService.Request(workspace: workspace,
          jsGeneratorObject: "Blockly.JavaScript",
          jsBlockGenerators: [
            (file: "Turtle/blockly_web/javascript_compressed.js", bundle: nil),
            (file: "Turtle/generators.js", bundle: nil)
          ],
          jsonBlockDefinitions: [(file: "Turtle/turtle_blocks.json", bundle: nil)])

        // Note: A single set of request listeners like this is sufficient for most cases, but
        // dynamic completion and error listeners may be created for each call if needed.
        request.onCompletion = self.codeGenerationCompletedWithCode
        request.onError = self.codeGenerationFailedWithError

        _codeGeneratorService.generateCodeForRequest(request)
      }
    } catch let error as NSError {
      print("An error occurred generating code for the workspace: \(error)")
    }
  }

  private func codeGenerationCompletedWithCode(code: String) {
    self.addTimestampedText("Generated code:\n\n====CODE====\n\n\(code)")

    // Run the generated code in the web view by calling `Turtle.execute(<code>)`
    let codeParam = code.bky_escapedJavaScriptParameter()
    self._webView.evaluateJavaScript("Turtle.execute(\"\(codeParam)\")",
      completionHandler: { _, error -> Void in
        if error != nil {
          self.codeGenerationFailedWithError("\(error)")
        }
      })
  }

  private func codeGenerationFailedWithError(error: String) {
    self.addTimestampedText("An error occurred:\n\n====ERROR====\n\n\(error)")
  }

  private func resetTurtleCode() {
    _webView?.evaluateJavaScript("Turtle.reset();", completionHandler: nil)
  }

  private func addTimestampedText(text: String) {
    self.codeText.text = (self.codeText.text ?? "") +
      "[\(_dateFormatter.stringFromDate(NSDate()))] \(text)\n"
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
  private func addBlock(blockName: String,
    inputBlockName: String? = nil, toCategory category: Toolbox.Category) throws -> Block
  {
    let block = try _blockFactory.buildBlock(blockName) as Block!

    // Connect an input block (if it was specified).
    // Note: We keep a reference to the input block in this scope, so it isn't deallocated before
    // the block tree is added to the category
    var inputBlock: Block?

    if inputBlockName != nil {
      inputBlock = try _blockFactory.buildBlock(inputBlockName!)
      let inputConnection = block.inputs[0].connection

      if inputBlock != nil && inputConnection != nil {
        try inputBlock!.connectToSuperiorConnection(inputConnection!)
      }
    }

    // Add the block tree to the category
    try category.addBlockTree(block)

    return block
  }
}
