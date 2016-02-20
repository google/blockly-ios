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
  /// Code generator
  private var _codeGenerator: CodeGenerator!

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
      _blockFactory = BlockFactory()
      try _blockFactory.loadFromJSONPath("Turtle/turtle_blocks.json")
      try _blockFactory.loadFromJSONPath("Blocks/math_blocks.json")
      try _blockFactory.loadFromJSONPath("Blocks/loop_blocks.json")
    } catch let error as NSError {
      print("An error occurred loading the test blocks: \(error)")
    }

    // Create the code generator
    _codeGenerator = CodeGenerator(jsGeneratorObject: "Blockly.JavaScript",
      jsDependencies: [
      /// The JS file containing the Blockly engine
      "Turtle/blockly_web/blockly_compressed.js",
      /// The JS file containing all Blockly default blocks
      "Turtle/blockly_web/blocks_compressed.js",
      /// The JS file containing methods used for generating JavaScript code
      "Turtle/blockly_web/javascript_compressed.js",
      /// The JS file containing a list of internationalized messages
      "Turtle/blockly_web/msg/js/en.js",
      ])
    _codeGenerator.importBlockGeneratorsFromFile("Turtle/generators.js")
    _codeGenerator.importBlockDefinitionsFromFile("Turtle/definitions.json")
  }

  deinit {
    // If the Turtle code is currently executing, we need to reset it before deallocating this
    // instance.
    if let webView = self.webView {
      webView.stringByEvaluatingJavaScriptFromString("Turtle.reset();")
    }
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

      let turtle = toolbox.addCategory("Turtle", colour: UIColor.redColor())
      try addBlock("turtle_move", toCategory: turtle)
      try addBlock("turtle_turn", toCategory: turtle)

      let loops = toolbox.addCategory("Loops", colour: UIColor.greenColor())
      try addBlock("controls_repeat_ext", toCategory: loops)

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
      // TODO:(#12) Pressing the run button quickly and repeatedly eventually results in a
      // EXC_BAD_ACCESS on a WebThread.
      if let workspace = workbenchViewController.workspaceLayout?.workspace {
        let request = try CodeGenerator.Request(workspace: workspace)
        request.onCompletion = { (code) -> Void in
          self.codeText.text = "GENERATED CODE:\n\n\(code)"

          dispatch_async(dispatch_get_main_queue()) {
            let method = self._jsContext.evaluateScript("Turtle.execute")
            method.callWithArguments([code])
          }
        }
        request.onError = { (error) -> Void in
          self.codeText.text = "An error occurred generating the code:\n\n\(error)"
        }

        _codeGenerator.generateCodeForRequest(request)
      }
    } catch let error as NSError {
      print("An error occurred generating code for the workspace: \(error)")
    }
  }

  private func addBlock(blockName: String, toCategory category: Toolbox.Category) throws {
    if let block = try _blockFactory.buildBlock(blockName) {
      try category.addBlockTree(block)
    }
  }
}
