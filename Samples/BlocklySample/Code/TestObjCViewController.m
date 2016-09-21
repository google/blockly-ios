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
  BKYBlock *defaultBlock = [blockBuilder makeBlockWithShadow:NO error:nil];
  BKYWorkspace *workspace = [[BKYWorkspace alloc] init];
  [workspace addBlockTree:defaultBlock error:nil];

  // Create toolbox
  BKYBlock *toolboxBlock = [blockBuilder makeBlockWithShadow:NO error:nil];
  BKYToolbox *toolbox = [[BKYToolbox alloc] init];
  BKYToolboxCategory *category = [toolbox addCategory:@"Test" color:[UIColor blueColor] icon:nil];
  [category addBlockTree:toolboxBlock error:nil];

  // Load workbench with workspace and toolbox
  BKYWorkbenchViewController *viewController =
  [[BKYWorkbenchViewController alloc] initWithStyle:BKYWorkbenchViewControllerStyleDefaultStyle];
  [viewController loadWorkspace:workspace connectionManager:nil error:nil];
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
