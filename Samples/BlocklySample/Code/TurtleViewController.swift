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
import JavaScriptCore
import Blockly

/**
 Demo app for using blocks to move a cute little turtle.
 */
class TurtleViewController: UIViewController {
  // MARK: - Properties

  // TODO:(#15) Replace UIWebView with WKWebView
  /// The web view that runs the turtle code
  @IBOutlet private var webView: UIWebView!
  /// The button for executing the block code
  @IBOutlet private var playButton: UIButton!
  /// Text to show generated code
  @IBOutlet private var codeText: UILabel!
  /// The view for holding `self.workbenchViewController.view`
  @IBOutlet private var editorView: UIView!

  /// JS Context of the web view
  private var _jsContext: JSContext!

  /// The block editor
  private var workbenchViewController: WorkbenchViewController!
  /// Code generator service
  private var _codeGeneratorService: CodeGeneratorService!

  /// Factory that produces block instances from a parsed json file
  private var _blockFactory: BlockFactory!

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
    if let webView = self.webView {
      webView.stopLoading()
      webView.stringByEvaluatingJavaScriptFromString("Turtle.reset();")
    }
    _codeGeneratorService.cancelAllRequests()
  }

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    // Don't allow the navigation controller bar cover this view controller
    self.edgesForExtendedLayout = .None
    self.navigationItem.title = "Turtle Demo"

    // Load the block editor
    self.workbenchViewController = WorkbenchViewController()
    workbenchViewController.enableTrashCan = true

    // Create a workspace
    do {
      let workspace = Workspace()

      // Create a layout for the workspace, which is required for viewing the workspace
      workbenchViewController.workspaceLayout =
        try WorkspaceLayout(workspace: workspace, layoutBuilder: LayoutBuilder())
    } catch let error as NSError {
      print("Couldn't build layout tree for workspace: \(error)")
    }

    // TODO:(#11) Read this toolbox from XML
    do {
      let toolbox = Toolbox()
      toolbox.readOnly = false

      let turtle = toolbox.addCategory("Turtle", colour: UIColor.cyanColor())
      let moveBlock = try addBlock("turtle_move", inputBlockName: "math_number", toCategory: turtle)
      (moveBlock.inputs[0].connectedBlock?.inputs[0].fields[0] as! FieldInput).text = "50"
      let turnBlock = try addBlock("turtle_turn", inputBlockName: "math_number", toCategory: turtle)
      (turnBlock.inputs[0].connectedBlock?.inputs[0].fields[0] as? FieldInput)?.text = "90"
      try addBlock("turtle_pen", toCategory: turtle)
      let widthBlock =
        try addBlock("turtle_width", inputBlockName: "math_number", toCategory: turtle)
      (widthBlock.inputs[0].connectedBlock?.inputs[0].fields[0] as? FieldInput)?.text = "4"

      let colour = toolbox.addCategory("Colour", colour: UIColor.brownColor())
      let colourBlock =
        try addBlock("turtle_colour", inputBlockName: "colour_picker", toCategory: colour)
      (colourBlock.inputs[0].connectedBlock?.inputs[0].fields[0] as? FieldColour)?.colour =
        UIColor.redColor()
      try addBlock("colour_picker", toCategory: colour)
      try addBlock("colour_random", toCategory: colour)

      let loops = toolbox.addCategory("Loops", colour: UIColor.greenColor())
      let repeatBlock =
        try addBlock("controls_repeat_ext", inputBlockName: "math_number", toCategory: loops)
      (repeatBlock.inputs[0].connectedBlock?.inputs[0].fields[0] as? FieldInput)?.text = "10"

      let math = toolbox.addCategory("Math", colour: UIColor.blueColor())
      try addBlock("math_number", toCategory: math)

      workbenchViewController.toolbox = toolbox
    } catch let error as NSError {
      print("An error occurred loading the toolbox: \(error)")
    }

    self.editorView.autoresizesSubviews = true
    workbenchViewController.view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
    workbenchViewController.view.frame = self.editorView.bounds
    self.editorView.addSubview(workbenchViewController.view)
    self.addChildViewController(workbenchViewController)

    // Load the turtle executable code
    if let url = NSBundle.mainBundle().URLForResource("Turtle/turtle", withExtension: "html") {
      webView.loadRequest(NSURLRequest(URL: url))
    } else {
      print("Couldn't load Turtle/turtle.html")
    }

    // Make things a bit prettier
    webView.layer.borderColor = UIColor.lightGrayColor().CGColor
    webView.layer.borderWidth = 1
    codeText.superview?.layer.borderColor = UIColor.lightGrayColor().CGColor
    codeText.superview?.layer.borderWidth = 1

    // Set the jsContext from the webview
    _jsContext = self.webView
      .valueForKeyPath("documentView.webView.mainFrame.javaScriptContext") as! JSContext
    _jsContext.exceptionHandler = { context, exception in
      print("JS Exception: \(exception)")
    }

    // Refresh the view
    workbenchViewController.refreshView()
  }

  override func prefersStatusBarHidden() -> Bool {
    return true
  }

  // MARK: - Private

  @IBAction private dynamic func didPressPlayButton(button: UIButton) {
    do {
      if let workspace = workbenchViewController.workspaceLayout?.workspace {
        // Cancel pending requests
        _codeGeneratorService.cancelAllRequests()

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
    self.codeText.text = "GENERATED CODE:\n\n\(code)"

    dispatch_async(dispatch_get_main_queue()) {
      // Run the generated code in the web view by calling `Turtle.execute(<code>)`
      let method = self._jsContext.evaluateScript("Turtle.execute")
      method.callWithArguments([code])
    }
  }

  private func codeGenerationFailedWithError(error: String) {
    self.codeText.text = "An error occurred generating the code:\n\n\(error)"
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
