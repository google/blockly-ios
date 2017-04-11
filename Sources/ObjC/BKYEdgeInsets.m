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
#import "BKYEdgeInsets.h"

BKYEdgeInsets BKYEdgeInsetsMake(CGFloat top, CGFloat leading, CGFloat bottom, CGFloat trailing) {
  BKYEdgeInsets edgeInsets;
  edgeInsets.top = top;
  edgeInsets.leading = leading;
  edgeInsets.bottom = bottom;
  edgeInsets.trailing = trailing;
  return edgeInsets;
}

BKYEdgeInsets const BKYEdgeInsetsZero = { .top = 0, .leading = 0, .bottom = 0, .trailing = 0 };

CGFloat BKYEdgeInsetsGetLeft(BKYEdgeInsets edgeInsets) {
  return [UIApplication sharedApplication].userInterfaceLayoutDirection ==
    UIUserInterfaceLayoutDirectionRightToLeft ? edgeInsets.trailing : edgeInsets.leading;
}

CGFloat BKYEdgeInsetsGetRight(BKYEdgeInsets edgeInsets) {
  return [UIApplication sharedApplication].userInterfaceLayoutDirection ==
    UIUserInterfaceLayoutDirectionRightToLeft ? edgeInsets.leading : edgeInsets.trailing;
}
