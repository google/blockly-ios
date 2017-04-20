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

#import "TurtleObjCViewController.h"

#import <Blockly/Blockly.h>
#import <Blockly/Blockly-Swift.h>


// MARK: - ScriptMessageHandler Class

/**
 Because WKUserContentController makes a strong retain cycle to its delegate, we create an
 intermediary object here to act as a delegate so we can more easily break a potential retain cycle
 between WKUserContentController and TurtleObjCViewController.
 */
@interface ScriptMessageHandler : NSObject <WKScriptMessageHandler>

@property(nonatomic, weak) id<WKScriptMessageHandler> delegate;

- (id)initWithDelegate:(id<WKScriptMessageHandler>)delegate;

@end


@implementation ScriptMessageHandler

- (id)initWithDelegate:(id<WKScriptMessageHandler>)delegate {
  self = [super init];
  if (self) {
    self.delegate = delegate;
  }
  return self;
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
  // Call "real" delegate (which is TurtleObjCViewController)
  [self.delegate userContentController:userContentController didReceiveScriptMessage:message];
}

@end

// MARK: - TurtleObjCViewController Class

/// The callback name to access this object from the JS code.
/// See "turtle/turtle.js" for an example of its usage.
NSString *const TurtleObjCViewController_JSCallbackName = @"TurtleViewControllerCallback";

/**
 Demo app for using blocks to move a cute little turtle, in Objective-C.
 */
@interface TurtleObjCViewController () <BKYWorkbenchViewControllerDelegate,
                                        WKScriptMessageHandler>

/// The web view that runs the turtle code (this is not an outlet because WKWebView isn't
/// supported by Interface Builder)
@property(nonatomic) WKWebView *webView;
/// The workbench for the blocks.
@property(nonatomic) BKYWorkbenchViewController *workbenchViewController;
/// Code generator service
@property(nonatomic) BKYCodeGeneratorService *codeGeneratorService;

/// Flag indicating whether the code is currently running.
@property (nonatomic) Boolean currentlyRunning;
/// Flag indicating whether highlighting a block is enabled.
@property (nonatomic) Boolean allowBlockHighlighting;
/// Flag indicating whether scrolling a block into view is enabled.
@property (nonatomic) Boolean allowScrollingToBlockView;
/// The UUID of the last block that was highlighted.
@property (nonatomic) NSString *lastHighlightedBlockUUID;
/// The UUID of the current code generation request.
@property (nonatomic) NSString *currentRequestUUID;

/// Date formatter for timestamping events.
@property (nonatomic) NSDateFormatter *dateFormatter;

@end

@implementation TurtleObjCViewController

// MARK: - Initializers

- (instancetype)init {
  self = [super initWithNibName:@"TurtleViewController" bundle:nil];
  if (!self) {
    return self;
  }

  // Create the code generator service
  _codeGeneratorService = [[BKYCodeGeneratorService alloc] initWithJsCoreDependencies:@[
    @"Turtle/blockly_web/blockly_compressed.js",
    @"Turtle/blockly_web/msg/js/en.js"]];

  // Create the builder for creating code generator service requests
  BKYCodeGeneratorServiceRequestBuilder *requestBuilder =
    [[BKYCodeGeneratorServiceRequestBuilder alloc] initWithJSGeneratorObject:@"Blockly.JavaScript"];
  [requestBuilder addJSBlockGeneratorFiles:@[@"Turtle/blockly_web/javascript_compressed.js",
                                              @"Turtle/generators.js"]];
  [requestBuilder addJSONBlockDefinitionFilesFromDefaultFiles:BKYBlockJSONFileAllDefault];
  [requestBuilder addJSONBlockDefinitionFiles:@[@"Turtle/turtle_blocks.json"]];

  // Set the request builder for the CodeGeneratorService.
  [_codeGeneratorService setRequestBuilder:requestBuilder shouldCache:YES];

  _dateFormatter = [[NSDateFormatter alloc] init];
  _dateFormatter.dateFormat = @"HH:mm:ss.SSS";

  return self;
}

- (void)dealloc {
  // If the turtle code is currently executing, reset it before deallocating.
  [_webView stopLoading];
  [_webView.configuration.userContentController
    removeScriptMessageHandlerForName:TurtleObjCViewController_JSCallbackName];
  [self resetTurtleCode];
  [_codeGeneratorService cancelAllRequests];
}

// MARK: - Super

- (void)viewDidLoad {
  [super viewDidLoad];

  NSError *error;

  // Don't allow the navigation controller bar cover this view controller
  self.edgesForExtendedLayout = UIRectEdgeNone;
  self.navigationItem.title = @"Objective-C Turtle Demo";

  // Load the block editor
  _workbenchViewController =
    [[BKYWorkbenchViewController alloc] initWithStyle:BKYWorkbenchViewControllerStyleAlternate];
  _workbenchViewController.delegate = self;
  _workbenchViewController.toolboxDrawerStaysOpen = YES;

  // Load blocks into the block factory
  [_workbenchViewController.blockFactory loadFromDefaultFiles:BKYBlockJSONFileAllDefault];
  [_workbenchViewController.blockFactory loadFromJSONPaths:@[@"Turtle/turtle_blocks.json"]
                                                    bundle:nil
                                                     error:&error];

  if ([self handleError:error]) {
    return;
  }

  // Load the toolbox
  NSString *toolboxPath = @"Turtle/toolbox.xml";
  NSString *bundlePath = [[NSBundle mainBundle] pathForResource:toolboxPath ofType:nil];
  NSString *xmlString = [NSString stringWithContentsOfFile:bundlePath
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];

  if ([self handleError:error]) {
    return;
  }

  BKYToolbox *toolbox =
    [BKYToolbox makeToolboxWithXmlString:xmlString
                                 factory:self.workbenchViewController.blockFactory
                                   error:&error];

  if ([self handleError:error]) {
    return;
  }

  [_workbenchViewController loadToolbox:toolbox error:&error];

  if ([self handleError:error]) {
    return;
  }

  [self addChildViewController:_workbenchViewController];
  self.editorView.autoresizesSubviews = true;
  _workbenchViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight |
                                                   UIViewAutoresizingFlexibleWidth;
  _workbenchViewController.view.frame = self.editorView.bounds;
  [self.editorView addSubview:_workbenchViewController.view];
  [_workbenchViewController didMoveToParentViewController:self];

  // Programmatically create WKWebView and configure it with a hook so the JS code can callback
  // into the iOS code.
  ScriptMessageHandler *handler = [[ScriptMessageHandler alloc] initWithDelegate: self];
  WKUserContentController *userContentController = [[WKUserContentController alloc] init];
  [userContentController addScriptMessageHandler:handler
                                            name:TurtleObjCViewController_JSCallbackName];

  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  configuration.userContentController = userContentController;

  _webView = [[WKWebView alloc] initWithFrame:self.webViewContainer.bounds
                                configuration:configuration];
  _webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  _webView.translatesAutoresizingMaskIntoConstraints = true;
  self.webViewContainer.autoresizesSubviews = true;
  [self.webViewContainer addSubview:_webView];

  // Load the turtle JS code.
  NSURL *url = [[NSBundle mainBundle] URLForResource:@"Turtle/turtle" withExtension:@"html"];
  [_webView loadRequest:[NSURLRequest requestWithURL:url]];

  // Make things a bit prettier
  _webView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
  _webView.layer.borderWidth = 1;
  self.codeText.superview.layer.borderColor = [[UIColor lightGrayColor] CGColor];
  self.codeText.superview.layer.borderWidth = 1;
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];

  [_codeGeneratorService cancelAllRequests];
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

// MARK: - Private

- (BOOL)handleError:(NSError *)error {
  if (error != nil) {
    NSLog(@"ERROR: %@", error.localizedDescription);
    return YES;
  }

  return NO;
}

- (IBAction)didPressPlayButton:(UIButton *)sender {
  if (self.currentlyRunning) {
    if (_currentRequestUUID == nil) {
      NSLog(@"Error: The current request UUID is nil.");
      return;
    }
    if (![_currentRequestUUID isEqualToString:@""]) {
      [_codeGeneratorService cancelRequestWithUuid:_currentRequestUUID];
    } else {
      [_webView evaluateJavaScript:@"Turtle.cancel()" completionHandler:nil];
    }
    [self resetRequests];
  } else {
    // Reset the turtle
    [self resetTurtleCode];

    self.codeText.text = @"";
    [self addTimestampedText:@"Generating code..."];

    // Request code generation for the workspace
    NSError *error;
    __weak __typeof(self) weakSelf = self;
    void (^onCompletion)(NSString* uuid, NSString *code) = ^(NSString* uuid, NSString *code) {
      [weakSelf codeGenerationCompletionWithCode:code];
    };
    void (^onError)(NSString* uuid, NSString *error) =  ^(NSString* uuid, NSString *error) {
      [weakSelf codeGenerationFailedWithError:error];
    };
    BKYWorkspace* workspace = _workbenchViewController.workspace;
    _currentRequestUUID = [_codeGeneratorService generateCodeForWorkspace:workspace
                                                                    error:&error
                                                             onCompletion:onCompletion
                                                                  onError:onError];
    if ([self handleError:error]) {
      return;
    }

    [self.playButton setImage:[UIImage imageNamed:@"cancel_button"] forState:UIControlStateNormal];
    self.currentlyRunning = YES;
    self.playButton.enabled = NO;
  }
}

- (void)codeGenerationCompletionWithCode:(NSString *)code {
  [self addTimestampedText:
    [NSString stringWithFormat:@"Generated code:\n\n====CODE====\n\n%@", code]];

  _currentRequestUUID = @"";
  [self runCode: code];
}

- (void)codeGenerationFailedWithError:(NSString *)error {
  [self addTimestampedText:
    [NSString stringWithFormat:@"An error occurred:\n\n====ERROR====\n\n%@", error]];

  [self resetRequests];
}

- (void)resetRequests {
  self.currentlyRunning = NO;
  self.currentRequestUUID = @"";
  self.playButton.enabled = YES;
  [self.playButton setImage:[UIImage imageNamed:@"play_button"] forState:UIControlStateNormal];
  [self.playButton setTitle:@"Run Code" forState:UIControlStateNormal];
}

- (void)runCode:(NSString *)code {
  // Allow block highlighting and scrolling a block into view (it can only be disabled by explicit
  // user interaction)
  _allowBlockHighlighting = YES;
  _allowScrollingToBlockView = YES;

  // Re-enable the play button, and set the icon to "cancel."
  self.currentlyRunning = true;
  self.playButton.enabled = YES;
  [self.playButton setImage:[UIImage imageNamed:@"cancel_button"] forState:UIControlStateNormal];
  [self.playButton setTitle:@"Stop Turtle" forState:UIControlStateNormal];

  // Run the generated code in the web view by calling `Turtle.execute(<code>)`
  NSString *escapedString = [self escapedJSString:code];
  __weak TurtleObjCViewController *weakSelf = self;
  void (^onCompletion)(id, NSError *error) =
    ^(id thing, NSError *error) {
      if (error != nil) {
        [weakSelf codeGenerationFailedWithError: error.description];
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
  NSString *format = [self.codeText.text isEqualToString:@""] ? @"%@%@" : @"%@\n%@";
  self.codeText.text = [NSString stringWithFormat:format,
    self.codeText.text,
    [NSString stringWithFormat:@"[%@] %@", [_dateFormatter stringFromDate:[NSDate date]], text]];
}

// MARK: - WKScriptMessageHandler implementation

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
  NSDictionary<NSString*, NSString*> *dictionary = message.body;
  NSString *method = dictionary[@"method"];

  if ([method isEqualToString:@"highlightBlock"]) {
    NSString *blockID = dictionary[@"blockID"];
    if (blockID != nil) {
      if (_allowBlockHighlighting) {
        [_workbenchViewController highlightBlockWithBlockUUID:blockID];
        _lastHighlightedBlockUUID = blockID;
      }
      if (_allowScrollingToBlockView) {
        [_workbenchViewController scrollBlockIntoViewWithBlockUUID:blockID animated:true];
        _lastHighlightedBlockUUID = blockID;
      }
    }
  } else if ([method isEqualToString:@"unhighlightLastBlock"]) {
    NSString *blockID = _lastHighlightedBlockUUID;
    if (blockID != nil) {
      [_workbenchViewController unhighlightBlockWithBlockUUID:blockID];
      _lastHighlightedBlockUUID = blockID;
    }
  } else if ([method isEqualToString:@"finishExecution"]) {
    [self resetRequests];
  } else {
    NSLog(@"Unrecognized method");
  }
}

// MARK: - WorkbenchViewControllerDelegate implementation

- (void)workbenchViewController:(BKYWorkbenchViewController *)workbenchViewController
                 didUpdateState:(BKYWorkbenchViewControllerUIState)state {
  // Only allow automatic scrolling if the user tapped the workspace.
  _allowScrollingToBlockView = (state & ~BKYWorkbenchViewControllerUIStateDidTapWorkspace) == 0;
  // Only allow block highlighting if the user tapped/panned or opened the toolbox or trash can.
  _allowBlockHighlighting = (state & ~(BKYWorkbenchViewControllerUIStateDidTapWorkspace |
                                       BKYWorkbenchViewControllerUIStateDidPanWorkspace |
                                       BKYWorkbenchViewControllerUIStateCategoryOpen |
                                       BKYWorkbenchViewControllerUIStateTrashCanOpen)) == 0;
}

@end
