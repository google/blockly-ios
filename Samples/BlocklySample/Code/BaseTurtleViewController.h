//
//  BaseTurtleViewController.h
//  BlocklySample
//
//  Created by Cory Diers on 10/5/16.
//  Copyright © 2016 Google Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface BaseTurtleViewController: UIViewController

/// The parent view for `self.webView`.
@property (weak, nonatomic) IBOutlet UIView *webViewContainer;
/// Text to show generated code.
@property (weak, nonatomic) IBOutlet UILabel *codeText;
/// The parent view for `self.workbenchViewController.view`.
@property (weak, nonatomic) IBOutlet UIView *editorView;

- (IBAction)didPressPlayButton:(UIButton *)sender;

@end
