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
#import <Blockly/Blockly.h>
#import <Blockly/Blockly-Swift.h>

@interface TestObjCViewController ()

@property(nonatomic) BKYCodeGeneratorService *codeGeneratorService;
@property(nonatomic) BKYCodeGeneratorServiceRequestBuilder *requestBuilder;
@property(nonatomic) BKYWorkspace *workspace;

@end


/// TODO (#40) - Create Obj-C sample project.
@implementation TestObjCViewController
// MARK: - Super

- (void)viewDidLoad {
  [super viewDidLoad];

  self.edgesForExtendedLayout = UIRectEdgeNone;
  self.navigationItem.title = @"Objective-C Demo";

  // Create a block builder
  BKYBlockBuilder *blockBuilder = [[BKYBlockBuilder alloc] initWithName:@"test"];
  [blockBuilder setPreviousConnectionWithEnabled:YES typeChecks:nil error:nil];

  BKYInputBuilder *inputBuilder =
    [[BKYInputBuilder alloc] initWithType: BKYInputTypeDummy name:@""];
  BKYFieldLabel *field = [[BKYFieldLabel alloc] initWithName:@"Text" text:@"TEXT"];
  [inputBuilder appendField:field];

  NSMutableArray *inputBuilders = [[NSMutableArray alloc] init];
  [inputBuilders addObject:inputBuilder];
  blockBuilder.inputBuilders = inputBuilders;

  // Create workspace
  _workspace = [[BKYWorkspace alloc] init];

  // Create toolbox with some blocks in it
  BKYBlockFactory *blockFactory = [[BKYBlockFactory alloc] init];
  [blockFactory loadFromJSONPaths:@[@"Blocks/test_blocks.json"] bundle:nil error:nil];
  [blockFactory loadFromDefaultFiles:BKYBlockJSONFileAllDefault];
  BKYBlock *statementBlock = [blockFactory makeBlockWithName:@"statement_no_input" error:nil];
  BKYBlock *mathNumberBlock = [blockFactory makeBlockWithName:@"math_number" error:nil];

  BKYToolbox *toolbox = [[BKYToolbox alloc] init];
  BKYToolboxCategory *category =
    [toolbox addCategoryWithName:@"Test" color:[UIColor blueColor] icon:nil];
  [category addBlockTree:statementBlock error:nil];
  [category addBlockTree:mathNumberBlock error:nil];

  // Load workbench with workspace and toolbox
  BKYWorkbenchViewController *viewController =
    [[BKYWorkbenchViewController alloc] initWithStyle:BKYWorkbenchViewControllerStyleDefaultStyle];
  [viewController loadWorkspace:_workspace error:nil];
  [viewController loadToolbox:toolbox error:nil];

  _codeGeneratorService =
    [[BKYCodeGeneratorService alloc] initWithJsCoreDependencies: @[
      @"Turtle/blockly_web/blockly_compressed.js",
      @"Turtle/blockly_web/msg/js/en.js"]];

  self.requestBuilder =
    [[BKYCodeGeneratorServiceRequestBuilder alloc] initWithJSGeneratorObject:@"Blockly.JavaScript"];
  [_requestBuilder addJSBlockGeneratorFiles:@[@"Turtle/blockly_web/javascript_compressed.js",
                                              @"Turtle/generators.js"]];
  [_requestBuilder addJSONBlockDefinitionFilesFromDefaultFiles:BKYBlockJSONFileAllDefault];
  [_requestBuilder addJSONBlockDefinitionFiles:@[@"Turtle/turtle_blocks.json"]];
  _requestBuilder.onCompletion = ^(NSString *code) {
    NSLog(@"Successfully generated code:");
    NSLog(@"%@", code);
  };
  _requestBuilder.onError = ^(NSString *error) {
    NSLog(@"Failed to generate code.");
    NSLog(@"ERROR: %@", error);
  };

  BKYBlock *block = [blockFactory makeBlockWithName:@"math_number" error:nil];
  [_workspace addBlockTree:block error:nil];

  // Add workbench to this view controller
  [self addChildViewController:viewController];
  [self.view addSubview:viewController.view];
  viewController.view.bounds = self.view.bounds;

   [self addGenerateButton];
}

- (void)generateCode:(UIButton *)button {

  NSError *error = nil;
  BKYCodeGeneratorServiceRequest *request =
    [_requestBuilder makeRequestForWorkspace:self.workspace error:&error];
  if (error) {
    NSLog(@"Error: %@", error.localizedDescription);
    return;
  }
  [_codeGeneratorService generateCodeForRequest:request];
}

- (void)addGenerateButton {
  UIBarButtonItem *generateButton = [[UIBarButtonItem alloc]
    initWithTitle:@"Generate"
    style:UIBarButtonItemStylePlain
    target:self
    action:@selector(generateCode:)];
  generateButton.title = @"Generate";
  self.navigationItem.rightBarButtonItem = generateButton;
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

@end
