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
 Stores information on how to render and position a `Toolbox.Category` on-screen.
*/
public class ToolboxCategoryLayout: WorkspaceLayout {
  public unowned let category: Toolbox.Category

  public init(category: Toolbox.Category, layoutBuilder: LayoutBuilder) {
    self.category = category
    super.init(workspace: category.workspace, layoutBuilder: layoutBuilder)
  }

  public override func performLayout(includeChildren includeChildren: Bool) {
    let xSeparatorSpace = BlockLayout.sharedConfig.xSeparatorSpace

    var size = WorkspaceSizeZero
    var cumulativeSize: CGFloat = BlockLayout.sharedConfig.ySeparatorSpace
    var outputBlockExists = false

    // Check if there are some blocks with output tabs
    for blockGroupLayout in self.blockGroupLayouts {
      if blockGroupLayoutHasOutputTab(blockGroupLayout) {
        outputBlockExists = true
        break
      }
    }

    // Update relative position/size of blocks
    for (var i = 0; i < category.blockItems.count; i++) {
      let blockItem = self.category.blockItems[i]
      guard let blockGroupLayout = blockItem.block.layout?.parentBlockGroupLayout else {
        continue
      }

      if includeChildren {
        blockGroupLayout.performLayout(includeChildren: true)
      }

      // Account for aligning block groups with output tabs
      let outputTabSpacer = outputBlockExists && !blockGroupLayoutHasOutputTab(blockGroupLayout) ?
        BlockLayout.sharedConfig.puzzleTabWidth : 0

      // Automatically space out all block groups
      blockGroupLayout.edgeInsets = WorkspaceEdgeInsetsMake(
        0, xSeparatorSpace + outputTabSpacer, blockItem.gap, xSeparatorSpace)

      blockGroupLayout.relativePosition = WorkspacePointMake(0, cumulativeSize)
      cumulativeSize += blockGroupLayout.totalSize.height

      size = LayoutHelper.sizeThatFitsLayout(blockGroupLayout, fromInitialSize: size)
    }

    // Update size required for the workspace
    self.contentSize = size

    // Update the canvas size
    scheduleChangeEventWithFlags(Layout.Flag_NeedsDisplay)
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
