/*
* Copyright 2015 Google Inc. All Rights Reserved.
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

import UIKit

extension DefaultBlockView {
  // MARK: - Public

  /**
   Adds the path for drawing a next/previous notch.
   ```
   Draws: --
            \_/
   ```
   - Parameter path: The Bezier path to add to.
   - Parameter drawLeftToRight: True if the path should be drawn from left-to-right. False if it
   should be drawn right-to-left.
   - Parameter config: The `LayoutConfig` to use to draw this path
   - Parameter notchWidth: The width of the notch, specified as a Workspace coordinate system unit.
   - Parameter notchHeight: The height of the notch, specified as a Workspace coordinate system
   unit.
   */
  public final func addNotch(toPath path: WorkspaceBezierPath, drawLeftToRight: Bool,
    notchWidth: CGFloat, notchHeight: CGFloat)
  {
    if drawLeftToRight {
      path.addLineToPoint(notchWidth - 15, 0, relative: true)
      path.addLineToPoint(6, notchHeight, relative: true)
      path.addLineToPoint(3, 0, relative: true)
      path.addLineToPoint(6, -notchHeight, relative: true)
    } else {
      path.addLineToPoint(-6, notchHeight, relative: true)
      path.addLineToPoint(-3, 0, relative: true)
      path.addLineToPoint(-6, -notchHeight, relative: true)
      path.addLineToPoint(-(notchWidth - 15), 0, relative: true)
    }
  }

  /**
  Adds the path for drawing jagged teeth at the end of collapsed blocks.
  ```
  Draws: --
           |
            \
            /
           /
           \
  ```
  - Parameter path: The Bezier path to add to.
  */
  public final func addJaggedTeeth(toPath path: WorkspaceBezierPath) {
    path.addLineToPoint(8, 0, relative: true)
    path.addLineToPoint(0, 4, relative: true)
    path.addLineToPoint(8, 4, relative: true)
    path.addLineToPoint(-16, 8, relative: true)
    path.addLineToPoint(8, 4, relative: true)
  }

  /**
   Adds the path for drawing a horizontal puzzle tab.
   ```
   Draws:
          |
        /\|
       |
        \/|
          |
   ```
   - Parameter path: The Bezier path to add to.
   - Parameter drawTopToBottom: True if the path should be drawn from top-to-bottom. False if it
   should be drawn bottom-to-top.
   - Parameter puzzleTabWidth: The width of the puzzle tab, specified as a Workspace coordinate
   system unit.
   - Parameter puzzleTabHeight: The height of the puzzle tab, specified as a Workspace coordinate
   system unit.
   */
  public final func addPuzzleTab(toPath path: WorkspaceBezierPath, drawTopToBottom: Bool,
    puzzleTabWidth: CGFloat, puzzleTabHeight: CGFloat)
  {
    let verticalLineHeight = puzzleTabHeight * 0.2
    let roundedHalfPieceHeight = puzzleTabHeight * 0.3

    if drawTopToBottom {
      path.addLineToPoint(0, verticalLineHeight, relative: true)
      path.addCurveToPoint(WorkspacePoint(x: -puzzleTabWidth, y: roundedHalfPieceHeight),
        controlPoint1: WorkspacePoint(x: 0, y: roundedHalfPieceHeight * 1.25),
        controlPoint2: WorkspacePoint(x: -puzzleTabWidth, y: -roundedHalfPieceHeight),
        relative: true)
      path.addSmoothCurveToPoint(WorkspacePoint(x: puzzleTabWidth, y: roundedHalfPieceHeight),
        controlPoint2: WorkspacePoint(x: puzzleTabWidth, y: -roundedHalfPieceHeight * 0.3125),
        relative: true)
      path.addLineToPoint(0, verticalLineHeight, relative: true)
    } else {
      path.addLineToPoint(0, -verticalLineHeight, relative: true)
      path.addCurveToPoint(WorkspacePoint(x: -puzzleTabWidth, y: -roundedHalfPieceHeight),
        controlPoint1: WorkspacePoint(x: 0, y: -roundedHalfPieceHeight * 1.25),
        controlPoint2: WorkspacePoint(x: -puzzleTabWidth, y: roundedHalfPieceHeight),
        relative: true)
      path.addSmoothCurveToPoint(WorkspacePoint(x: puzzleTabWidth, y: -roundedHalfPieceHeight),
        controlPoint2: WorkspacePoint(x: puzzleTabWidth, y: roundedHalfPieceHeight * 0.3125),
        relative: true)
      path.addLineToPoint(0, -verticalLineHeight, relative: true)
    }
  }

  /**
   Moves the path to start drawing the top-left corner

   - Parameter path: The Bezier path.
   - Parameter blockCornerRadius: The block's corner radius, specified as a Workspace coordinate
    system unit.
   */
  public final func movePathToTopLeftCornerStart(
    _ path: WorkspaceBezierPath, blockCornerRadius: CGFloat)
  {
    path.moveToPoint(0, blockCornerRadius, relative: true)
  }

  /**
   Adds the path for drawing the rounded top-left corner.
   ```
   Draws:   --
           /
          |
   ```
   - Parameter blockCornerRadius: The block's corner radius, specified as a Workspace coordinate
   system unit.
   */
  public final func addTopLeftCorner(toPath path: WorkspaceBezierPath, blockCornerRadius: CGFloat)
  {
    path.addArcWithCenter(WorkspacePoint(x: blockCornerRadius, y: 0),
      radius: blockCornerRadius, startAngle: CGFloat(M_PI), endAngle: CGFloat(M_PI * 1.5),
      clockwise: true, relative: true)
  }
}
