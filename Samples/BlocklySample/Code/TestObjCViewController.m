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
  [blockFactory loadFromJSONPaths:@[@"Turtle/turtle_blocks.json"] bundle:nil error:nil];
  [blockFactory loadFromDefaultFiles:BKYBlockJSONFileAllDefault];

  NSString *toolboxPath = @"Blocks/toolbox_basic.xml";
  NSString *bundlePath = [[NSBundle mainBundle] pathForResource:toolboxPath ofType:nil];
  NSString *xmlString = [NSString stringWithContentsOfFile:bundlePath
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
  BKYToolbox *toolbox = [BKYToolbox makeToolboxWithXmlString:xmlString
                                                     factory:blockFactory
                                                       error:nil];

  // Load workbench with workspace and toolbox
  BKYWorkbenchViewController *viewController =
    [[BKYWorkbenchViewController alloc] initWithStyle:BKYWorkbenchViewControllerStyleDefaultStyle];
  [viewController loadWorkspace:_workspace error:nil];
  [viewController loadToolbox:toolbox error:nil];

  _codeGeneratorService = [[BKYCodeGeneratorService alloc] initWithJsCoreDependencies:@[
    [BKYBundledFile fileWithPath:@"Turtle/blockly_web/blockly_compressed.js"],
    [BKYBundledFile fileWithPath:@"Turtle/blockly_web/blocks_compressed.js"],
    [BKYBundledFile fileWithPath:@"Turtle/blockly_web/msg/js/en.js"]]];

  // Add workbench to this view controller
  [self addChildViewController:viewController];
  [self.view addSubview:viewController.view];
  viewController.view.bounds = self.view.bounds;

   [self addGenerateButton];
}

- (void)generateCode:(UIButton *)button {
  BKYCodeGeneratorServiceRequest *request =
    [[BKYCodeGeneratorServiceRequest alloc]
      initWithWorkspace:_workspace
      jsGeneratorObject:@"Blockly.JavaScript"
      jsBlockGenerators:
        @[[BKYBundledFile fileWithPath:@"Turtle/blockly_web/javascript_compressed.js"],
          [BKYBundledFile fileWithPath:@"Turtle/generators.js"]]
      jsonBlockDefinitions:
        @[[BKYBundledFile fileWithPath:@"Turtle/turtle_blocks.json"]]
      error:nil];
  request.onCompletion = ^(NSString *code) {
    NSLog(@"Successfully generated code:");
    NSLog(@"%@", code);
  };
  request.onError = ^(NSString *error) {
    NSLog(@"Failed to generate code.");
    NSLog(@"ERROR: %@", error);
  };

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
