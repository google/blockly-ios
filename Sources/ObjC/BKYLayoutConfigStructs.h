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
#import "BKYEdgeInsets.h"
#import "BKYWorkspaceUnits.h"

// MARK: - BKYLayoutConfigUnit

/// Struct for representing a unit value in both the Workspace coordinate system and UIView
/// coordinate system.
struct BKYLayoutConfigUnit {
  /// The unit value specified in the Workspace coordinate system
  CGFloat workspaceUnit;
  /// The unit value specified in the UIView coordinate system. This value is automatically derived
  /// from `workspaceUnit` and should not be modified directly.
  CGFloat viewUnit;
} CF_SWIFT_NAME(LayoutConfigUnit);
typedef struct BKYLayoutConfigUnit BKYLayoutConfigUnit;

/**
 Creates a `BKYLayoutConfigUnit`, initialized with a given `workspaceUnit`.

 @param workspaceUnit The value to use for `workspaceUnit`.
 @note `viewUnit` is automatically initialized to the correct value based on the given
 `workspaceUnit`.
 */
BKYLayoutConfigUnit BKYLayoutConfigUnitMake(CGFloat workspaceUnit)
  CF_SWIFT_NAME(LayoutConfigUnit.init(_:));

// MARK: - BKYLayoutConfigSize

/// Struct for representing a Size value (i.e. width/height) in both the Workspace coordinate
/// system and UIView coordinate system.
struct BKYLayoutConfigSize {
  /// The size value specified in the Workspace coordinate system
  BKYWorkspaceSize workspaceSize;
  /// The size value specified in the UIView coordinate system. This value is automatically derived
  /// from `workspaceUnit` and should not be modified directly.
  CGSize viewSize;
} CF_SWIFT_NAME(LayoutConfigSize);
typedef struct BKYLayoutConfigSize BKYLayoutConfigSize;

/**
 Creates a `BKYLayoutConfigSize`, initialized with a given workspace width/height to generate
 `workspaceSize`.

 @param workspaceWidth The width value to use for `workspaceSize`
 @param workspaceHeight The height value to use for `workspaceSize`
 @note `viewSize` is automatically initialized to the correct value based on the generated
 `workspaceSize`.
 */
BKYLayoutConfigSize BKYLayoutConfigSizeMake(CGFloat workspaceWidth, CGFloat workspaceHeight)
  CF_SWIFT_NAME(LayoutConfigSize.init(width:height:));

// MARK: - BKYLayoutConfigEdgeInsets

/// Struct for representing an EdgeInsets value (i.e. width/height) in both the Workspace coordinate
/// system and UIView coordinate system.
struct BKYLayoutConfigEdgeInsets {
  /// The size value specified in the Workspace coordinate system
  BKYEdgeInsets workspaceEdgeInsets;
  /// The size value specified in the UIView coordinate system. This value is automatically derived
  /// from `workspaceUnit` and should not be modified directly.
  BKYEdgeInsets viewEdgeInsets;
} CF_SWIFT_NAME(LayoutConfigEdgeInsets);
typedef struct BKYLayoutConfigEdgeInsets BKYLayoutConfigEdgeInsets;

/**
 Creates a `BKYLayoutConfigEdgeInsets`, where `workspaceEdgeInsets` is initialized with
 given edge insets.

 @param top The top value to use for `workspaceEdgeInsets`.
 @param leading The leading value to use for `workspaceEdgeInsets`.
 @param bottom The bottom value to use for `workspaceEdgeInsets`.
 @param trailing The trailing value to use for `workspaceEdgeInsets`.
 @note `viewEdgeInsets` is automatically initialized to the correct value based on the generated
 `workspaceEdgeInsets`.
 */
BKYLayoutConfigEdgeInsets BKYLayoutConfigEdgeInsetsMake(
  CGFloat top, CGFloat leading, CGFloat bottom, CGFloat trailing)
  CF_SWIFT_NAME(LayoutConfigEdgeInsets.init(top:leading:bottom:trailing:));

/**
 Creates a `BKYLayoutConfigEdgeInsets`, where both workspace and view edge inset values are set to zero.
 */
extern BKYLayoutConfigEdgeInsets const BKYLayoutConfigEdgeInsetsZero
  CF_SWIFT_NAME(LayoutConfigEdgeInsets.zero);
