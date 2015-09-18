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

extension BlockView {
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
  */
  public func addNotchToPath(path: WorkspaceBezierPath, drawLeftToRight: Bool) {
    if drawLeftToRight {
      path.addLineToPoint(BlockLayout.sharedConfig.notchWidth - 15, 0, relative: true)
      path.addLineToPoint(6, BlockLayout.sharedConfig.notchHeight, relative: true)
      path.addLineToPoint(3, 0, relative: true)
      path.addLineToPoint(6, -BlockLayout.sharedConfig.notchHeight, relative: true)
    } else {
      path.addLineToPoint(-6, BlockLayout.sharedConfig.notchHeight, relative: true)
      path.addLineToPoint(-3, 0, relative: true)
      path.addLineToPoint(-6, -BlockLayout.sharedConfig.notchHeight, relative: true)
      path.addLineToPoint(-(BlockLayout.sharedConfig.notchWidth - 15), 0, relative: true)
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
  public func addJaggedTeethToPath(path: WorkspaceBezierPath) {
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
  */
  public func addPuzzleTabToPath(path: WorkspaceBezierPath, drawTopToBottom: Bool) {
    let tabWidth = BlockLayout.sharedConfig.puzzleTabWidth
    let totalPuzzleTabHeight = BlockLayout.sharedConfig.puzzleTabHeight
    let verticalLineHeight = totalPuzzleTabHeight * 0.2
    let roundedHalfPieceHeight = totalPuzzleTabHeight * 0.3

    if drawTopToBottom {
      path.addLineToPoint(0, verticalLineHeight, relative: true)
      path.addCurveToPoint(WorkspacePointMake(-tabWidth, roundedHalfPieceHeight),
        controlPoint1: WorkspacePointMake(0, roundedHalfPieceHeight * 1.25),
        controlPoint2: WorkspacePointMake(-tabWidth, -roundedHalfPieceHeight),
        relative: true)
      path.addSmoothCurveToPoint(WorkspacePointMake(tabWidth, roundedHalfPieceHeight),
        controlPoint2: WorkspacePointMake(tabWidth, -roundedHalfPieceHeight * 0.3125),
        relative: true)
      path.addLineToPoint(0, verticalLineHeight, relative: true)
    } else {
      path.addLineToPoint(0, -verticalLineHeight, relative: true)
      path.addCurveToPoint(WorkspacePointMake(-tabWidth, -roundedHalfPieceHeight),
        controlPoint1: WorkspacePointMake(0, -roundedHalfPieceHeight * 1.25),
        controlPoint2: WorkspacePointMake(-tabWidth, roundedHalfPieceHeight),
        relative: true)
      path.addSmoothCurveToPoint(WorkspacePointMake(tabWidth, -roundedHalfPieceHeight),
        controlPoint2: WorkspacePointMake(tabWidth, roundedHalfPieceHeight * 0.3125),
        relative: true)
      path.addLineToPoint(0, -verticalLineHeight, relative: true)
    }
  }

  /**
  Moves the path to start drawing the top-left corner
  */
  public func movePathToTopLeftCornerStart(path: WorkspaceBezierPath) {
    path.moveToPoint(0, BlockLayout.sharedConfig.blockCornerRadius, relative: true)
  }

  /**
  Adds the path for drawing the rounded top-left corner.
  ```
  Draws:   --
          /
         |
  ```
  */
  public func addTopLeftCornerToPath(path: WorkspaceBezierPath) {
    let cornerRadius = BlockLayout.sharedConfig.blockCornerRadius

    path.addArcWithCenter(WorkspacePointMake(cornerRadius, 0),
      radius: cornerRadius, startAngle: CGFloat(M_PI), endAngle: CGFloat(M_PI * 1.5),
      clockwise: true, relative: true)
  }
}
