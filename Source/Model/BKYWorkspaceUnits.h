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

// MARK: - BKYWorkspacePoint

/**
 Point in the Workspace coordinate system.
 */
struct BKYWorkspacePoint {
  /// The x-coordinate
  CGFloat x;
  /// The y-coordinate
  CGFloat y;
};
typedef struct BKYWorkspacePoint BKYWorkspacePoint;

/**
 Creates a point in the Workspace coordinate system, given `(x, y)` coordinates.

 @param x X-coordinate in the Workspace coordinate system
 @param y Y-coordinate in the Workspace coordinate system
 @returns A `BKYWorkspacePoint`.
 */
BKYWorkspacePoint BKYWorkspacePointMake(CGFloat x, CGFloat y);

/**
 A point in the Workspace coordinate system, where x and y coordinates are set to zero.
 */
extern BKYWorkspacePoint const BKYWorkspacePointZero;

// MARK: - BKYWorkspaceSize

/**
 Size in the Workspace coordinate system.
 */
struct BKYWorkspaceSize {
  /// The width value
  CGFloat width;
  /// The height value
  CGFloat height;
};
typedef struct BKYWorkspaceSize BKYWorkspaceSize;

/**
 Creates a size in the Workspace coordinate system, given width and height values.

 @param width Width value in the Workspace coordinate system
 @param height Height value in the Workspace coordinate system
 @returns A `BKYWorkspaceSize`.
 */
BKYWorkspaceSize BKYWorkspaceSizeMake(CGFloat width, CGFloat height);

/**
 A size in the Workspace coordinate system, where width and height values are set to zero.
 */
extern BKYWorkspaceSize const BKYWorkspaceSizeZero;

// MARK: - BKYWorkspaceEdgeInsets

// TODO:(#195) Refactor BKYWorkspaceEdgeInsets into BKYEdgeInsets.

/**
 Edge insets in the Workspace coordinate system.
 */
typedef UIEdgeInsets BKYWorkspaceEdgeInsets;

///**
// Creates edge insets in the Workspace coordinate system, given values for each edge.
//
// @param top Top edge inset in the Workspace coordinate system
// @param left Left edge inset in the Workspace coordinate system
// @param bottom Bottom edge inset in the Workspace coordinate system
// @param right Right value in the Workspace coordinate system
// @returns A `BKYWorkspaceEdgeInsets`.
// */
BKYWorkspaceEdgeInsets BKYWorkspaceEdgeInsetsMake(
  CGFloat top, CGFloat left, CGFloat bottom, CGFloat right);

/**
 Edge insets in the Workspace coordinate system, where each inset value is set to zero.
 */
extern BKYWorkspaceEdgeInsets const BKYWorkspaceEdgeInsetsZero;
