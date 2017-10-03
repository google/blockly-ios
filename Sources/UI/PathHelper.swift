/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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

import Foundation

/**
 Helper for drawing different shapes inside a `WorkspaceBezierPath`.
 */
@objc(BKYPathHelper)
@objcMembers public class PathHelper: NSObject {
  // MARK: - Constants

  /**
   Representation of a block's corners.
   */
  public enum Corner {
    /// The bottom-left corner of the block.
    case bottomLeft
    /// The bottom-right corner of the block.
    case bottomRight
    /// The top-left corner of the block.
    case topLeft
    /// The top-right corner of the block.
    case topRight
  }

  // MARK: - Public

  /**
   Adds the path for drawing a next/previous notch.

   Draws:
   ```
   \_/
   ```

   - parameter path: The Bezier path to add to.
   - parameter drawLeftToRight: True if the path should be drawn from left-to-right. False if it
   should be drawn right-to-left.
   - parameter notchWidth: The width of the notch, specified as a Workspace coordinate system unit.
   - parameter notchHeight: The height of the notch, specified as a Workspace coordinate system
   unit.
   */
  public static func addNotch(
    toPath path: WorkspaceBezierPath, drawLeftToRight: Bool, notchWidth: CGFloat,
    notchHeight: CGFloat)
  {
    if drawLeftToRight {
      path.addLineTo(x: notchWidth * 0.4, y: notchHeight, relative: true)
      path.addLineTo(x: notchWidth * 0.2, y: 0, relative: true)
      path.addLineTo(x: notchWidth * 0.4, y: -notchHeight, relative: true)
    } else {
      path.addLineTo(x: -notchWidth * 0.4, y: notchHeight, relative: true)
      path.addLineTo(x: -notchWidth * 0.2, y: 0, relative: true)
      path.addLineTo(x: -notchWidth * 0.4, y: -notchHeight, relative: true)
    }
  }

  /**
   Adds the path for drawing jagged teeth at the end of collapsed blocks.

   Draws:
   ```
   --
   |
   \
   /
   /
   \
   ```

   - parameter path: The Bezier path to add to.
   */
  public static func addJaggedTeeth(toPath path: WorkspaceBezierPath) {
    path.addLineTo(x: 8, y: 0, relative: true)
    path.addLineTo(x: 0, y: 4, relative: true)
    path.addLineTo(x: 8, y: 4, relative: true)
    path.addLineTo(x: -16, y: 8, relative: true)
    path.addLineTo(x: 8, y: 4, relative: true)
  }

  /**
   Adds the path for drawing a horizontal puzzle tab.

   Draws:
   ```
   /\|
   |
   \/|
   ```

   - parameter path: The Bezier path to add to.
   - parameter drawTopToBottom: True if the path should be drawn from top-to-bottom. False if it
   should be drawn bottom-to-top.
   - parameter puzzleTabWidth: The width of the puzzle tab, specified as a Workspace coordinate
   system unit.
   - parameter puzzleTabHeight: The height of the puzzle tab, specified as a Workspace coordinate
   system unit.
   */
  public static func addPuzzleTab(
    toPath path: WorkspaceBezierPath, drawTopToBottom: Bool, puzzleTabWidth: CGFloat,
    puzzleTabHeight: CGFloat)
  {
    let roundedHalfPieceHeight = puzzleTabHeight * 0.5

    if drawTopToBottom {
      path.addCurve(to: WorkspacePoint(x: -puzzleTabWidth, y: roundedHalfPieceHeight),
                    controlPoint1: WorkspacePoint(x: 0, y: roundedHalfPieceHeight * 1.25),
                    controlPoint2: WorkspacePoint(x: -puzzleTabWidth, y: -roundedHalfPieceHeight),
                    relative: true)
      path.addSmoothCurve(to: WorkspacePoint(x: puzzleTabWidth, y: roundedHalfPieceHeight),
                          controlPoint2: WorkspacePoint(x: puzzleTabWidth, y: -roundedHalfPieceHeight * 0.3125),
                          relative: true)
    } else {
      path.addCurve(to: WorkspacePoint(x: -puzzleTabWidth, y: -roundedHalfPieceHeight),
                    controlPoint1: WorkspacePoint(x: 0, y: -roundedHalfPieceHeight * 1.25),
                    controlPoint2: WorkspacePoint(x: -puzzleTabWidth, y: roundedHalfPieceHeight),
                    relative: true)
      path.addSmoothCurve(to: WorkspacePoint(x: puzzleTabWidth, y: -roundedHalfPieceHeight),
                          controlPoint2: WorkspacePoint(x: puzzleTabWidth, y: roundedHalfPieceHeight * 0.3125),
                          relative: true)
    }
  }

  /**
   Moves the path to start drawing the top-left corner.

   - parameter path: The Bezier path.
   - parameter blockCornerRadius: The block's corner radius, specified as a Workspace coordinate
   system unit.
   */
  public static func movePathToTopLeftCornerStart(
    _ path: WorkspaceBezierPath, blockCornerRadius: CGFloat)
  {
    path.moveTo(x: 0, y: blockCornerRadius, relative: true)
  }

  /**
   Adds the path for drawing a rounded corner.

   - parameter corner: The `Corner` to draw.
   - parameter path: The Bezier path.
   - parameter radius: The radius of the corner, specified as a Workspace coordinate system unit.
   - parameter clockwise: `true` if the corner should be drawn clockwise. `false` if the corner
   should be drawn counter-clockwise.
   */
  public static func addCorner(
    _ corner: Corner, toPath path: WorkspaceBezierPath, radius: CGFloat, clockwise: Bool) {
    guard radius > 0 else { return }

    var arc: (centerX: CGFloat, centerY: CGFloat, startAngle: CGFloat, endAngle: CGFloat)
    switch (corner, clockwise) {
    case (.bottomLeft, true):
      arc = (centerX: 0, centerY: -radius, startAngle: CGFloat.pi * 0.5, endAngle: CGFloat.pi)
    case (.bottomLeft, false):
      arc = (centerX: radius, centerY: 0, startAngle: CGFloat.pi, endAngle: CGFloat.pi * 0.5)
    case (.bottomRight, true):
      arc = (centerX: -radius, centerY: 0, startAngle: 0, endAngle: CGFloat.pi * 0.5)
    case (.bottomRight, false):
      arc = (centerX: 0, centerY: -radius, startAngle: CGFloat.pi * 0.5, endAngle: 0)
    case (.topLeft, true):
      arc = (centerX: radius, centerY: 0, startAngle: CGFloat.pi, endAngle: CGFloat.pi * 1.5)
    case (.topLeft, false):
      arc = (centerX: 0, centerY: radius, startAngle: CGFloat.pi * 1.5, endAngle: CGFloat.pi)
    case (.topRight, true):
      arc = (centerX: 0, centerY: radius, startAngle: CGFloat.pi * 1.5, endAngle: 0)
    case (.topRight, false):
      arc = (centerX: -radius, centerY: 0, startAngle: 0, endAngle: CGFloat.pi * 1.5)
    }

    path.addArc(withCenter: WorkspacePoint(x: arc.centerX, y: arc.centerY),
                radius: radius, startAngle: arc.startAngle, endAngle: arc.endAngle,
                clockwise: clockwise, relative: true)
  }

  /**
   Adds the path for drawing a hat in the style of a cap.

   Draws:
   ```
    ---
   /   \
   ```

   - parameter path: The Bezier path.
   - parameter hatSize: The size of the hat, specified as a Workspace coordinate system size.
   */
  public static func addHatCap(toPath path: WorkspaceBezierPath, hatSize: WorkspaceSize)
  {
    path.addCurve(to: WorkspacePoint(x: hatSize.width, y: 0),
                  controlPoint1: WorkspacePoint(x: hatSize.width * 0.3, y: -hatSize.height),
                  controlPoint2: WorkspacePoint(x: hatSize.width * 0.7, y: -hatSize.height),
                  relative: true)
  }
}
