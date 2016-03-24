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
Stores information on how to render and position a group of sequential `Block` objects (ie. those
that are connecting via previous/next connections).
*/
@objc(BKYBlockGroupLayout)
public class BlockGroupLayout: Layout {
  // MARK: - Properties

  /*
  A list of sequential block layouts that belong to this group. While this class doesn't enforce
  it, the following should hold true:

  1) When `i < blockLayouts.count - 1`:

  `blockLayouts[i].block.nextBlock = blockLayouts[i + 1].block`

  2) When `i >= 1`:

  `blockLayouts[i].block.previousBlock = blockLayouts[i - 1].block`
  */
  public private(set) var blockLayouts = [BlockLayout]()

  /// Z-index of the layout. This value isn't used directly by the BlockGroupLayout. Setting this
  /// value automatically updates all of its descendant blocks to use the same `zIndex`.
  public var zIndex: UInt = 0 {
    didSet {
      if zIndex == oldValue {
        return
      }

      // Update the z-index for all of its block children
      for blockLayout in self.blockLayouts {
        blockLayout.zIndex = zIndex
      }
    }
  }

  /// Flag indicating if this block group is being dragged
  public var dragging: Bool = false {
    didSet {
      if dragging == oldValue {
        return
      }

      // Update dragged property for all of its block children
      for blockLayout in self.blockLayouts {
        blockLayout.dragging = dragging
      }
    }
  }

  // MARK: - Initializers

  public override init(workspaceLayout: WorkspaceLayout) {
    super.init(workspaceLayout: workspaceLayout)
  }

  // MARK: - Super

  public override func performLayout(includeChildren includeChildren: Bool) {
    var yOffset: CGFloat = 0
    var size = WorkspaceSizeZero

    // Update relative position/size of inputs
    for blockLayout in blockLayouts {
      if includeChildren {
        blockLayout.performLayout(includeChildren: true)
      }

      blockLayout.relativePosition.x = 0
      blockLayout.relativePosition.y = yOffset

      // Blocks are technically overlapping, so the actual amount that the next block is offset by
      // must take into account the size of the notch height
      yOffset += blockLayout.totalSize.height - BlockLayout.sharedConfig.notchHeight

      size = LayoutHelper.sizeThatFitsLayout(blockLayout, fromInitialSize: size)
    }

    // Update the size required for this block
    self.contentSize = size
  }

  // MARK: - Public

  /**
  Appends all blockLayouts to `self.blockLayouts`, sets their `parentLayout` to this instance, and
  sets their `zIndex` values to match `self.zIndex`.

  - Parameter blockLayouts: The list of `BlockLayout` instances to append.
  - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  public func appendBlockLayouts(blockLayouts: [BlockLayout], updateLayout: Bool = true) {
    for blockLayout in blockLayouts {
      blockLayout.parentLayout = self
      self.blockLayouts.append(blockLayout)

      // Set the block (and its child blocks) to match the zIndex/dragging values of this group
      blockLayout.zIndex = zIndex
      blockLayout.dragging = dragging
    }

    if updateLayout {
      updateLayoutUpTree()
    }
  }

  /**
  Removes `self.blockLayouts[index]`, sets its `parentLayout` to nil, and returns it.

  - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
  - Returns: The `BlockLayout` that was removed.
  */
  public func removeBlockLayoutAtIndex(index: Int, updateLayout: Bool = true) -> BlockLayout {
    let removedLayout = blockLayouts.removeAtIndex(index)
    removedLayout.parentLayout = nil

    if updateLayout {
      updateLayoutUpTree()
    }

    return removedLayout
  }

  /**
  Removes a given block layout and all subsequent layouts from `blockLayouts`, and returns them in
  an array.

  - Parameter blockLayout: The given block layout to find and remove.
  - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
  - Returns: The list of block layouts that were removed, starting from the given block layout. If
  the given block layout could not be found, it is still returned as a single-element list.
  */
  public func removeAllStartingFromBlockLayout(blockLayout: BlockLayout, updateLayout: Bool = true)
    -> [BlockLayout] {
      var removedElements = [BlockLayout]()

      if let index = blockLayouts.indexOf(blockLayout) {
        while (index < blockLayouts.count) {
          let removedLayout = removeBlockLayoutAtIndex(index, updateLayout: false)
          removedElements.append(removedLayout)
        }

        if updateLayout {
          updateLayoutUpTree()
        }
      } else {
        // Always return the given block layout, even it's not found
        removedElements.append(blockLayout)
        blockLayout.parentLayout = nil
      }

      return removedElements
  }

  /**
   Removes all elements from `self.blockLayouts` and sets their `parentLayout` to nil.

   - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
   */
  public func reset(updateLayout updateLayout: Bool = true) {
    while blockLayouts.count > 0 {
      removeBlockLayoutAtIndex(0, updateLayout: false)
    }

    if updateLayout {
      updateLayoutUpTree()
    }
  }

  /**
  If this instance's `parentLayout` is an instance of `WorkspaceLayout`, this method changes
  `relativePosition` to the position. If not, this method does nothing.

  - Parameter position: The relative position within its parent's Workspace layout, specified as a
  Workspace coordinate system point.
  - Parameter updateCanvasSize: If true, recalculates the Workspace layout's canvas size based on
  the current positions of its block groups.
  */
  public func moveToWorkspacePosition(position: WorkspacePoint, updateCanvasSize: Bool = true) {
    if let workspaceLayout = self.parentLayout as? WorkspaceLayout {
      self.relativePosition = position
      self.refreshViewPositionsForTree(includeFields: false)

      if updateCanvasSize {
        workspaceLayout.updateCanvasSize()
      }
    }
  }
}
