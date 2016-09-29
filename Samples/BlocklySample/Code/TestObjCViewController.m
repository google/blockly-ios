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
  BKYWorkspace *workspace = [[BKYWorkspace alloc] init];

  blockBuilder.position = BKYWorkspacePointMake(0, 0);
  BKYBlock *block1 = [blockBuilder makeBlockAsShadow:NO error:nil];
  [workspace addBlockTree:block1 error:nil];

  blockBuilder.position = BKYWorkspacePointMake(100, 100);
  BKYBlock *block2 = [blockBuilder makeBlockAsShadow:NO error:nil];
  [workspace addBlockTree:block2 error:nil];

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
  [viewController loadWorkspace:workspace error:nil];
  [viewController loadToolbox:toolbox error:nil];

  // Add workbench to this view controller
  [self addChildViewController:viewController];
  [self.view addSubview:viewController.view];
  viewController.view.bounds = self.view.bounds;
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

@end
