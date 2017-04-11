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

#import <UIKit/UIKit.h>

/// The common protocol for both turtle view controllers. Any outlets required by
/// `TurtleViewController.xib` should be declared here.
@protocol TurtleViewControllerInterface

/// The parent view for `self.webView`.
@property (weak, nonatomic) IBOutlet UIView *webViewContainer;
/// Text to show generated code.
@property (weak, nonatomic) IBOutlet UILabel *codeText;
/// The parent view for `self.workbenchViewController.view`.
@property (weak, nonatomic) IBOutlet UIView *editorView;
/// The play/cancel button
@property (weak, nonatomic) IBOutlet UIButton *playButton;

- (IBAction)didPressPlayButton:(UIButton *)sender;

@end
