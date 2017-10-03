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
@objc(BKYWorkspaceFlowLayout)
@objcMembers public final class WorkspaceFlowLayout: WorkspaceLayout {

  // MARK: -  Constants

  /// Defines how consecutive block trees should be laid out relative to each other
  @objc(BKYWorkspaceFlowLayoutDirection)
  public enum LayoutDirection: Int {
    case
      /// Consecutive block trees will be laid out horizontally.
      horizontal,
      /// Consecutive block trees will be laid out vertically.
      vertical
  }

  // MARK: - Properties

  /// The workspace to layout
  public let workspaceFlow: WorkspaceFlow

  /**
   The maximum amount of space to use per line of blocks before a new line of blocks should be
   created, expressed as a Workspace coordinate unit.

   If `self.layoutDirection == .Vertical`, this value is the maximum height for a column
   of consecutive blocks.

   If `self.layoutDirection == .Horizontal`, this value is the maximum width for a row
   of consecutive blocks.

   If this value is <= 0, line sizes are not constrained.
   */
  public var maximumLineBlockSize: CGFloat = 0

  /// The direction in which this layout should place consecutive blocks next to each other
  public var layoutDirection = LayoutDirection.vertical

  // MARK: - Initializers

  /**
   Initializer for workspace flow layout.

   - parameter workspace: The `WorkspaceFlow` model for this layout.
   - parameter engine: The `LayoutEngine` to associate with this layout.
   - parameter layoutDirection: The direction (horizontal or vertical) for this layout.
   */
  public init(workspace: WorkspaceFlow, engine: LayoutEngine, layoutDirection: LayoutDirection)
  {
    self.workspaceFlow = workspace
    self.layoutDirection = layoutDirection
    super.init(workspace: workspace, engine: engine)
  }

  public override func performLayout(includeChildren: Bool) {
    let xSeparatorSpace =
      self.config.workspaceUnit(for: LayoutConfig.WorkspaceFlowXSeparatorSpace)
    let ySeparatorSpace =
      self.config.workspaceUnit(for: LayoutConfig.WorkspaceFlowYSeparatorSpace)

    var size = WorkspaceSize.zero
    var xPosition = CGFloat(xSeparatorSpace)
    var yPosition = CGFloat(ySeparatorSpace)

    // Perform the layout for each block group first. This is necessary to align all of the groups
    // properly.
    var largestLeadingEdgeXOffset = CGFloat(0)
    for blockGroupLayout in self.blockGroupLayouts {
      if includeChildren {
        blockGroupLayout.performLayout(includeChildren: true)
      }

      largestLeadingEdgeXOffset =
        max(largestLeadingEdgeXOffset, blockGroupLayout.largestLeadingEdgeXOffset)
    }

    // Update relative position/size of blocks. We iterate through workspaceFlow.items instead of
    // self.blockGroupLayouts, since we need to take into account gap information.
    for item in workspaceFlow.items {
      guard let rootBlock = item.rootBlock else {
        // This must be a gap. Simply update the current xPosition or yPosition
        xPosition += (self.layoutDirection == .horizontal ? (item.gap ?? 0) : 0)
        yPosition += (self.layoutDirection == .vertical ? (item.gap ?? 0) : 0)
        continue
      }
      guard let blockGroupLayout = rootBlock.layout?.parentBlockGroupLayout else {
        // This block has no parent group layout. Just skip it.
        continue
      }

      if self.layoutDirection == .vertical {
        // Account for aligning block groups with output tabs
        let outputTabSpacer = largestLeadingEdgeXOffset - blockGroupLayout.largestLeadingEdgeXOffset

        blockGroupLayout.edgeInsets = EdgeInsets(top: 0, leading: outputTabSpacer,
                                                 bottom: ySeparatorSpace, trailing: xSeparatorSpace)

        if self.maximumLineBlockSize > 0 &&
          yPosition + blockGroupLayout.totalSize.height > self.maximumLineBlockSize
        {
          // Start a new column
          xPosition = size.width
          yPosition = ySeparatorSpace
        }

        // Set position
        blockGroupLayout.relativePosition = WorkspacePoint(x: xPosition, y: yPosition)

        yPosition += blockGroupLayout.totalSize.height
      } else if self.layoutDirection == .horizontal {
        blockGroupLayout.edgeInsets =
          EdgeInsets(top: 0, leading: 0, bottom: ySeparatorSpace, trailing: xSeparatorSpace)

        if self.maximumLineBlockSize > 0 &&
          xPosition + blockGroupLayout.totalSize.width > self.maximumLineBlockSize
        {
          // Start a new row
          xPosition = xSeparatorSpace
          yPosition = size.height
        }

        // Set position
        blockGroupLayout.relativePosition = WorkspacePoint(x: xPosition, y: yPosition)

        xPosition += blockGroupLayout.totalSize.width
      }

      size = LayoutHelper.sizeThatFitsLayout(blockGroupLayout, fromInitialSize: size)
    }

    // Update size required for the workspace
    self.contentSize = size

    // Update the canvas size
    sendChangeEvent(withFlags: WorkspaceLayout.Flag_UpdateCanvasSize)
  }
}
