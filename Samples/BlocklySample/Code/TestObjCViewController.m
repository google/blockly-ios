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

#import "TestObjCViewController.h"

#import <Blockly/Blockly-Swift.h>

/**
 Demo app for using blocks to move a cute little turtle, in Objective-C.
 */
@interface TestObjCViewController ()

/// The parent view for `self.webView`.
@property (weak, nonatomic) IBOutlet UIView *webViewContainer;
/// Text to show generated code.
@property (weak, nonatomic) IBOutlet UILabel *codeText;
/// The parent view for `self.workbenchViewController.view`.
@property (weak, nonatomic) IBOutlet UIView *editorView;

/// The web view that runs the turtle code (this is not an outlet because WKWebView isn't
/// supported by Interface Builder)
@property(nonatomic) WKWebView *webView;
/// The workbench for the blocks.
@property(nonatomic) BKYWorkbenchViewController *workbenchViewController;
/// Code generator service
@property(nonatomic) BKYCodeGeneratorService *codeGeneratorService;
/// The workspace for the blocks.
@property(nonatomic) BKYWorkspace *workspace;
/// Factory that produces block instances from a parsed json file.
@property(nonatomic) BKYBlockFactory *blockFactory;

/// Flag indicating whether highlighting a block is enabled.
@property (nonatomic) Boolean allowBlockHighlighting;
/// Flag indicating whether scrolling a block into view is enabled.
@property (nonatomic) Boolean allowScrollingToBlockView;
/// The UUID of the last block that was highlighted.
@property (nonatomic) NSString *lastHighlightedBlockUUID;

/// Date formatter for timestamping events.
@property (nonatomic) NSDateFormatter *dateFormatter;

@end

@implementation TestObjCViewController

// MARK: - Initializers

- (instancetype)init {
  self = [super init];
  if (self == nil) {
    return self;
  }
  NSError *error;

  // Load blocks into the block factory
  _blockFactory = [[BKYBlockFactory alloc] init];
  [_blockFactory loadFromDefaultFiles:BKYBlockJSONFileAllDefault];
  [_blockFactory loadFromJSONPaths:@[@"Turtle/turtle_blocks.json"] bundle:nil error:&error];
  [self handleError:error];

  // Create the code generator service
  _codeGeneratorService = [[BKYCodeGeneratorService alloc] initWithJsCoreDependencies:@[
    [BKYBundledFile fileWithPath:@"Turtle/blockly_web/blockly_compressed.js"],
    [BKYBundledFile fileWithPath:@"Turtle/blockly_web/blocks_compressed.js"],
    [BKYBundledFile fileWithPath:@"Turtle/blockly_web/msg/js/en.js"]]];

  _dateFormatter = [[NSDateFormatter alloc] init];
  _dateFormatter.dateFormat = @"HH:mm:ss.SSS";

  return self;
}

- (void)dealloc {
  // If the turtle code is currently executing, reset it before deallocating.
  [_webView stopLoading];
  [self resetTurtleCode];
  [_codeGeneratorService cancelAllRequests];
}

// MARK: - Super

- (void)viewDidLoad {
  [super viewDidLoad];
  NSError *error;

  self.edgesForExtendedLayout = UIRectEdgeNone;
  self.navigationItem.title = @"Objective-C Turtle Demo";

  _workbenchViewController =
  [[BKYWorkbenchViewController alloc] initWithStyle:BKYWorkbenchViewControllerStyleDefaultStyle];

  // Create workspace
  _workspace = [[BKYWorkspace alloc] init];
  [_workbenchViewController loadWorkspace:_workspace error:&error];
  [self handleError:error];

  // Load the toolbox
  NSString *toolboxPath = @"Turtle/toolbox.xml";
  NSString *bundlePath = [[NSBundle mainBundle] pathForResource:toolboxPath ofType:nil];
  NSString *xmlString = [NSString stringWithContentsOfFile:bundlePath
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
  [self handleError:error];
  BKYToolbox *toolbox = [BKYToolbox makeToolboxWithXmlString:xmlString
                                                     factory:_blockFactory
                                                       error:&error];
  [self handleError:error];
  [_workbenchViewController loadToolbox:toolbox error:&error];
  [self handleError:error];

  _editorView.autoresizesSubviews = true;
  _workbenchViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  _workbenchViewController.view.frame = self.editorView.bounds;
  [_editorView addSubview:_workbenchViewController.view];
  [self addChildViewController:_workbenchViewController];

  // Programmatically create WKWebView and configure it with a JS callback.
  WKUserContentController *userContentController = [[WKUserContentController alloc] init];
  [userContentController addScriptMessageHandler:self name:@"TurtleViewControllerCallback"];

  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  configuration.userContentController = userContentController;

  _webView = [[WKWebView alloc] initWithFrame:_webViewContainer.bounds configuration:configuration];
  _webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  _webView.translatesAutoresizingMaskIntoConstraints = true;
  _webViewContainer.autoresizesSubviews = true;
  [_webViewContainer addSubview:_webView];

  // Load the turtle JS code.
  NSURL *url = [[NSBundle mainBundle] URLForResource:@"Turtle/turtle" withExtension:@"html"];
  [_webView loadRequest:[NSURLRequest requestWithURL:url]];

  _webView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
  _webView.layer.borderWidth = 1;
  _codeText.superview.layer.borderColor = [[UIColor lightGrayColor] CGColor];
  _codeText.superview.layer.borderWidth = 1;
}

- (void)handleError:(NSError *)error {
  if (error != nil) {
    NSLog(@"ERROR: %@", error.localizedDescription);
  }
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];

  [_codeGeneratorService cancelAllRequests];
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

// MARK: - Internal

- (IBAction)didPressPlayButton:(UIButton *)sender {
  [_codeGeneratorService cancelAllRequests];

  [self resetTurtleCode];

  _codeText.text = @"";
  [self addTimestampedText:@"Generating code..."];

  NSError *error;
  BKYCodeGeneratorServiceRequest *request =
  [[BKYCodeGeneratorServiceRequest alloc]
     initWithWorkspace:_workspace
     jsGeneratorObject:@"Blockly.JavaScript"
     jsBlockGenerators:
     @[[BKYBundledFile fileWithPath:@"Turtle/blockly_web/javascript_compressed.js"],
       [BKYBundledFile fileWithPath:@"Turtle/generators.js"]]
     jsonBlockDefinitions:
     @[[BKYBundledFile fileWithPath:@"Turtle/turtle_blocks.json"]]
     error:&error];
  request.onCompletion = ^(NSString *code) { [self codeGenerationCompletionWithCode:code]; };
  request.onError =  ^(NSString *error) { [self codeGenerationFailedWithError:error]; };
  [self handleError:error];

  [_codeGeneratorService generateCodeForRequest:request];
}

- (void)codeGenerationCompletionWithCode:(NSString *)code {
  [self addTimestampedText:[NSString stringWithFormat:@"Generated code:\n\n====CODE====\n\n%@", code]];

  [self runCode: code];
}

- (void)codeGenerationFailedWithError:(NSString *)error {
  [self addTimestampedText:[NSString stringWithFormat:@"An error occurred:\n\n====ERROR====\n\n%@", error]];
}

- (void)runCode:(NSString *)code {
  _allowBlockHighlighting = YES;
  _allowScrollingToBlockView = YES;

  NSString *escapedString = [self escapedJSString:code];
  void (^onCompletion)(id, NSError *error) =
    ^(id thing, NSError *error) {
      if (error != nil) {
        [self codeGenerationFailedWithError: error.description];
      }
    };
  [_webView evaluateJavaScript:[NSString stringWithFormat:@"Turtle.execute(\"%@\")", escapedString]
             completionHandler: onCompletion];
}

- (void)resetTurtleCode {
  [_webView evaluateJavaScript:@"Turtle.reset()" completionHandler:nil];
}

- (NSString *)escapedJSString:(NSString *)string {
  return [[[[[[string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
                      stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]
                      stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"]
                      stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"]
                      stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]
                      stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
}

- (void)addTimestampedText:(NSString *)text {
  NSString *format = [_codeText.text isEqualToString:@""] ? @"%@%@" : @"%@\n%@";
  _codeText.text = [NSString stringWithFormat:format,
                     _codeText.text,
                     [NSString stringWithFormat:@"[%@] %@",
                       [_dateFormatter stringFromDate:[NSDate date]], text]];
}

// MARK: - WKScriptMessageHandler implementation

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
  NSDictionary<NSString*, NSString*> *dictionary = message.body;
  NSString *method = dictionary[@"method"];

  if ([method isEqualToString:@"highlightBlock"]) {
    NSString *blockID = dictionary[@"blockID"];
    if (blockID != nil) {
      if (_allowBlockHighlighting) {
        [_workbenchViewController highlightBlock:blockID];
        _lastHighlightedBlockUUID = blockID;
      }
      if (_allowScrollingToBlockView) {
        [_workbenchViewController scrollBlockIntoView:blockID animated:true];
        _lastHighlightedBlockUUID = blockID;
      }
    }
  } else if ([method isEqualToString:@"unhighlightLastBlock"]) {
    NSString *blockID = _lastHighlightedBlockUUID;
    if (blockID != nil) {
      [_workbenchViewController unhighlightBlock:blockID];
      _lastHighlightedBlockUUID = blockID;
    }
  } else {
    NSLog(@"Unrecognized method");
  }
}

// MARK: - WorkbenchViewControllerDelegate implementation

- (void)workbenchViewController:(BKYWorkbenchViewController *)workbenchViewController
                 didUpdateState:(BKYUIState *)state {
  // Only allow automatic scrolling if the user tapped the workspace.
  _allowScrollingToBlockView = [state intersectsWith:[BKYUIState didTapWorkspace]];
  // Only allow block highlighting if the user tapped/panned or opened the toolbox or trash can.
  _allowBlockHighlighting = [state intersectsWith:[BKYUIState didTapWorkspace]] ||
                            [state intersectsWith:[BKYUIState didPanWorkspace]] ||
                            [state intersectsWith:[BKYUIState categoryOpen]] ||
                            [state intersectsWith:[BKYUIState trashCanOpen]];
}

@end
