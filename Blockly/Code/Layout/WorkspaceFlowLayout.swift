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

import Foundation

/**
 Layout for displaying a list of blocks in Workspace in a flow layout (in a manner similar to
 UICollectionViewFlowLayout).
 */
public class WorkspaceFlowLayout: WorkspaceLayout {

  // MARK: -  LayoutDirection Enum

  /// Defines how consecutive block trees should be laid out relative to each other
  public enum LayoutDirection {
    case Horizontal, Vertical
  }

  // MARK: - Properties

  /// The workspace to layout
  public let workspaceFlow: WorkspaceFlow

  /**
   The maximum amount of space to use per line of blocks before a new line of blocks should be
   created, expressed as a Workspace coordinate unit.

   ie. If `self.layoutDirection == .Vertical`, this value is the maximum height for a column
   of consecutive blocks.
   If `self.layoutDirection == .Horizontal`, this value is the maximum width for a row
   of consecutive blocks.

   If this value is <= 0, line sizes are not constrained.
   */
  public var maximumLineBlockSize: CGFloat = 0

  /// The direction in which this layout should place consecutive blocks next to each other
  public var layoutDirection = LayoutDirection.Vertical

  // MARK: - Initializers

  public init(workspace: WorkspaceFlow, layoutDirection: LayoutDirection,
    layoutBuilder: LayoutBuilder) throws
  {
    self.workspaceFlow = workspace
    self.layoutDirection = layoutDirection
    try super.init(workspace: workspace, layoutBuilder: layoutBuilder)
  }

  public override func performLayout(includeChildren includeChildren: Bool) {
    let xSeparatorSpace = BlockLayout.sharedConfig.xSeparatorSpace
    let ySeparatorSpace = BlockLayout.sharedConfig.ySeparatorSpace

    var size = WorkspaceSizeZero
    var outputBlockExists = false
    var xPosition = CGFloat(xSeparatorSpace)
    var yPosition = CGFloat(ySeparatorSpace)

    // Check if there are some blocks with output tabs
    for blockGroupLayout in self.blockGroupLayouts {
      if blockGroupLayoutHasOutputTab(blockGroupLayout) {
        outputBlockExists = true
        break
      }
    }

    // Update relative position/size of blocks. We iterate through workspaceFlow.items instead of
    // self.blockGroupLayouts, since we need to take into account gap information.
    for item in workspaceFlow.items {
      guard let rootBlock = item.rootBlock else {
        // This must be a gap. Simply update the current xPosition or yPosition
        xPosition += (self.layoutDirection == .Horizontal ? (item.gap ?? 0) : 0)
        yPosition += (self.layoutDirection == .Vertical ? (item.gap ?? 0) : 0)
        continue
      }
      guard let blockGroupLayout = rootBlock.layout?.parentBlockGroupLayout else {
        // This block has no parent group layout. Just skip it.
        continue
      }

      if includeChildren {
        blockGroupLayout.performLayout(includeChildren: true)
      }

      if self.layoutDirection == .Vertical {
        // Account for aligning block groups with output tabs
        let outputTabSpacer = outputBlockExists && !blockGroupLayoutHasOutputTab(blockGroupLayout) ?
          BlockLayout.sharedConfig.puzzleTabWidth : 0

        blockGroupLayout.edgeInsets =
          WorkspaceEdgeInsetsMake(0, outputTabSpacer, ySeparatorSpace, xSeparatorSpace)

        if self.maximumLineBlockSize > 0 &&
          yPosition + blockGroupLayout.totalSize.height > self.maximumLineBlockSize
        {
          // Start a new column
          xPosition = size.width
          yPosition = ySeparatorSpace
        }

        // Set position
        blockGroupLayout.relativePosition = WorkspacePointMake(xPosition, yPosition)

        yPosition += blockGroupLayout.totalSize.height
      } else if self.layoutDirection == .Horizontal {
        blockGroupLayout.edgeInsets =
          WorkspaceEdgeInsetsMake(0, 0, ySeparatorSpace, xSeparatorSpace)

        if self.maximumLineBlockSize > 0 &&
          xPosition + blockGroupLayout.totalSize.width > self.maximumLineBlockSize
        {
          // Start a new row
          xPosition = xSeparatorSpace
          yPosition = size.height
        }

        // Set position
        blockGroupLayout.relativePosition = WorkspacePointMake(xPosition, yPosition)

        xPosition += blockGroupLayout.totalSize.width
      }

      size = LayoutHelper.sizeThatFitsLayout(blockGroupLayout, fromInitialSize: size)
    }

    // Update size required for the workspace
    self.contentSize = size

    // Update the canvas size
    scheduleChangeEventWithFlags(WorkspaceLayout.Flag_UpdateCanvasSize)
  }

  private func blockGroupLayoutHasOutputTab(blockGroupLayout: BlockGroupLayout) -> Bool {
    for blockLayout in blockGroupLayout.blockLayouts {
      if blockLayout.block.outputConnection != nil {
        return true
      }
    }
    return false
  }
}
