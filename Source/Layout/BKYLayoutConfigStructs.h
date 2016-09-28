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
#import "BKYWorkspaceUnits.h"

// MARK: - BKYLayoutConfigUnit

/**
 Struct for representing a unit value in both the Workspace coordinate system and UIView
 coordinate system.
 */
struct BKYLayoutConfigUnit {
  /// The unit value specified in the Workspace coordinate system
  CGFloat workspaceUnit;
  /// The unit value specified in the UIView coordinate system. This value is automatically derived
  /// from `workspaceUnit` and should not be modified directly.
  CGFloat viewUnit;
};
typedef struct BKYLayoutConfigUnit BKYLayoutConfigUnit;

/**
 Creates a `BKYLayoutConfigUnit`, initialized with a given `workspaceUnit`.

 @param workspaceUnit: The value to use for `workspaceUnit`.
 @note `viewUnit` is automatically initialized to the correct value based on the given
 `workspaceUnit`.
 */
BKYLayoutConfigUnit BKYLayoutConfigUnitMake(CGFloat workspaceUnit);

// MARK: - BKYLayoutConfigSize

/**
 Struct for representing a Size value (i.e. width/height) in both the Workspace coordinate
 system and UIView coordinate system.
 */
struct BKYLayoutConfigSize {
  /// The size value specified in the Workspace coordinate system
  BKYWorkspaceSize workspaceSize;
  /// The size value specified in the UIView coordinate system. This value is automatically derived
  /// from `workspaceUnit` and should not be modified directly.
  CGSize viewSize;
};
typedef struct BKYLayoutConfigSize BKYLayoutConfigSize;

/**
 Creates a `BKYLayoutConfigSize`, initialized with a given `workspaceSize`.

 @param workspaceSize: The value to use for `workspaceSize`.
 @note `viewSize` is automatically initialized to the correct value based on the given
 `workspaceSize`.
 */
BKYLayoutConfigSize BKYLayoutConfigSizeMake(BKYWorkspaceSize workspaceSize);
