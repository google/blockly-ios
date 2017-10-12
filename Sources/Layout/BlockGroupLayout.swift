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
 Abstract class that stores information on how to render and position a group of sequential
 `Block` objects (ie. those that are connecting via previous/next connections).
 */
@objc(BKYBlockGroupLayout)
@objcMembers open class BlockGroupLayout: Layout {
  // MARK: - Properties

  /// Flag that should be used when `self.zIndex` has been updated
  public static let Flag_UpdateZIndex = LayoutFlag(0)
  /// Flag that should be used when `self.dragging` has been updated
  public static let Flag_UpdateDragging = LayoutFlag(1)

  /**
   A list of sequential block layouts that belong to this group. While this class doesn't enforce
   it, the following should hold true:

   1) When `i < blockLayouts.count - 1`:

   `blockLayouts[i].block.nextBlock = blockLayouts[i + 1].block`

   2) When `i >= 1`:

   `blockLayouts[i].block.previousBlock = blockLayouts[i - 1].block`
  */
  open fileprivate(set) var blockLayouts = [BlockLayout]()

  /// Z-index of the layout
  open var zIndex: UInt = 0 {
    didSet {
      if zIndex == oldValue {
        return
      }
      sendChangeEvent(withFlags: BlockGroupLayout.Flag_UpdateZIndex)
    }
  }

  /// Flag indicating if this block group is being dragged
  open var dragging: Bool = false {
    didSet {
      if dragging == oldValue {
        return
      }
      sendChangeEvent(withFlags: BlockGroupLayout.Flag_UpdateDragging)
    }
  }

  /// The largest leading edge X offset for every `BlockLayout` in `self.blockLayouts`
  open var largestLeadingEdgeXOffset: CGFloat {
    return blockLayouts.map({ $0.leadingEdgeXOffset }).max() ?? CGFloat(0)
  }

  // MARK: - Open

  /**
  Appends all blockLayouts to `self.blockLayouts` and sets their `parentLayout` to this instance.

  - parameter blockLayouts: The list of `BlockLayout` instances to append.
  - parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  open func appendBlockLayouts(_ blockLayouts: [BlockLayout], updateLayout: Bool = true) {
    for blockLayout in blockLayouts {
      self.blockLayouts.append(blockLayout)
      adoptChildLayout(blockLayout)
    }

    if updateLayout {
      updateLayoutUpTree()
    }
  }

  /**
  Removes `self.blockLayouts[index]`, sets its `parentLayout` to nil, and returns it.

  - parameter updateLayout: If true, all parent layouts of this layout will be updated.
  - returns: The `BlockLayout` that was removed.
  */
  @discardableResult
  open func removeBlockLayout(atIndex index: Int, updateLayout: Bool = true) -> BlockLayout {
    let removedLayout = blockLayouts.remove(at: index)
    removeChildLayout(removedLayout)

    if updateLayout {
      updateLayoutUpTree()
    }

    return removedLayout
  }

  /**
   Appends a given `BlockLayout` instance to `self.blockLayouts` and adopts it as a child.

   If `blockLayout` had a previous `BlockGroupLayout` parent, it is removed as a child from that
   parent. Additionally, any children that followed this `blockLayout` in its old parent are also
   removed and appended to `self.blockLayouts`.

   - parameter blockLayout: The `BlockLayout` to adopt
   - parameter updateLayouts: If true, all parent layouts of this layout and of `blockLayout`'s
   previous parent will be updated.
   */
  open func claimWithFollowers(blockLayout: BlockLayout, updateLayouts: Bool = true) {
    let oldParentLayout = blockLayout.parentBlockGroupLayout

    var transferredLayouts = [BlockLayout]()
    if let oldParentLayout = oldParentLayout,
      let index = oldParentLayout.blockLayouts.index(of: blockLayout)
    {
      while (index < oldParentLayout.blockLayouts.count) {
        // Just remove block layout from `oldParentLayout.blockLayouts`
        // We don't want to remove it via removeChildLayout(...) or else this will fire an event.
        let transferLayout = oldParentLayout.blockLayouts.remove(at: index)
        transferredLayouts.append(transferLayout)
      }
    } else {
      transferredLayouts.append(blockLayout)
    }

    Layout.doNotAnimate {
      // Transfer the layouts over to `newBlockGroupLayout`. Do not animate these changes, as these
      // layouts need to start any potential animations from locations relative to its new parent
      // (not its old parent).
      self.appendBlockLayouts(transferredLayouts, updateLayout: false)
    }

    if updateLayouts {
      updateLayoutUpTree()
      oldParentLayout?.updateLayoutUpTree()
    }
  }

  /**
  Removes a given block layout and all subsequent layouts from `blockLayouts`, and returns them in
  an array.

  - parameter blockLayout: The given block layout to find and remove.
  - parameter updateLayout: If true, all parent layouts of this layout will be updated.
  - returns: The list of block layouts that were removed, starting from the given block layout. If
  the given block layout could not be found, it is still returned as a single-element list.
  */
  open func removeAllBlockLayouts(
    startingFrom blockLayout: BlockLayout, updateLayout: Bool = true) -> [BlockLayout] {
    var removedElements = [BlockLayout]()

    if let index = blockLayouts.index(of: blockLayout) {
      while (index < blockLayouts.count) {
        let removedLayout = removeBlockLayout(atIndex: index, updateLayout: false)
        removedElements.append(removedLayout)
      }

      if updateLayout {
        updateLayoutUpTree()
      }
    } else {
      // Always return the given block layout, even it's not found
      removedElements.append(blockLayout)
    }

    return removedElements
  }

  /**
   Removes all elements from `self.blockLayouts` and sets their `parentLayout` to nil.

   - parameter updateLayout: If true, all parent layouts of this layout will be updated.
   */
  open func reset(updateLayout: Bool = true) {
    while blockLayouts.count > 0 {
      removeBlockLayout(atIndex: 0, updateLayout: false)
    }

    if updateLayout {
      updateLayoutUpTree()
    }
  }

  /**
   If this instance's `parentLayout` is an instance of `WorkspaceLayout`, this method changes
   `relativePosition` to the position. If not, this method does nothing.

   - parameter position: The relative position within its parent's Workspace layout, specified
   as a Workspace coordinate system point.
   - parameter updateCanvasSize: If true, recalculates the Workspace layout's canvas size based on
   the current positions of its block groups.
   */
  open func move(toWorkspacePosition position: WorkspacePoint, updateCanvasSize: Bool = true) {
    if let workspaceLayout = self.parentLayout as? WorkspaceLayout {
      let updatePosition = {
        self.relativePosition = position
        self.refreshViewPositionsForTree(includeFields: false)
      }

      if let block = blockLayouts.first?.block {
        BlocklyEvent.Move.captureMoveEvent(workspace: workspaceLayout.workspace, block: block) {
          updatePosition()
        }
      } else {
        bky_debugPrint("An empty block group was moved. This may be the result of abnormal state.")
        updatePosition()
      }

      if updateCanvasSize {
        workspaceLayout.updateCanvasSize()
      }
    }
  }
}
