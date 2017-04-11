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

#import <CoreGraphics/CoreGraphics.h>

/// Defines inset distances for views/layouts, that allows for both LTR and RTL layouts.
struct BKYEdgeInsets {
  /// The inset distance for the top edge.
  CGFloat top;
  /// The inset distance for the leading edge.
  CGFloat leading;
  /// The inset distance for the bottom edge.
  CGFloat bottom;
  /// The inset distance for the trailing edge.
  CGFloat trailing;
} CF_SWIFT_NAME(EdgeInsets);
typedef struct BKYEdgeInsets BKYEdgeInsets;

/**
 Creates edge insets, with given values for each edge.

 @param top Top edge inset
 @param leading Leading edge inset
 @param bottom Bottom edge inset
 @param trailing Trailing edge inset
 @returns: A `BKYEdgeInsets`.
 */
BKYEdgeInsets BKYEdgeInsetsMake(CGFloat top, CGFloat leading, CGFloat bottom, CGFloat trailing)
  CF_SWIFT_NAME(EdgeInsets.init(top:leading:bottom:trailing:));

/**
 Creates edge insets, with each inset value set to zero.
 */
extern BKYEdgeInsets const BKYEdgeInsetsZero
  CF_SWIFT_NAME(EdgeInsets.zero);

// TODO(#57): Once Jazzy supports generating docs with headers using the CF_SWIFT_NAME(...) getter
// macro, add it here and remove EdgeInsets.swift.

/**
 The inset distance for the left edge.
 In LTR layouts, this value is equal to `self.leading`.
 In RTL layouts, this value is equal to `self.trailing`.
 */
CGFloat BKYEdgeInsetsGetLeft(BKYEdgeInsets edgeInsets);

/**
 The inset distance for the right edge.
 In LTR layouts, this value is equal to `self.trailing`.
 In RTL layouts, this value is equal to `self.leading`.
 */
CGFloat BKYEdgeInsetsGetRight(BKYEdgeInsets edgeInsets);
