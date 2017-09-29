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
 Stores information on how to render and position a `Workspace` on-screen.
 */
@objc(BKYWorkspaceLayout)
@objcMembers open class WorkspaceLayout: Layout {
  // MARK: - Static Properties

  /// Flag that should be used when the canvas size of the workspace has been updated.
  public static let Flag_UpdateCanvasSize = LayoutFlag(0)

  // MARK: - Properties

  /// The `Workspace` to layout
  public final let workspace: Workspace

  /// All child `BlockGroupLayout` objects that have been appended to this layout
  public final var blockGroupLayouts = [BlockGroupLayout]()

  /// z-index counter used to layer blocks in a specific order.
  private var _zIndexCounter: UInt = 1

  /// Maximum value that the z-index counter should reach
  private var _maximumZIndexCounter: UInt = (UInt.max - 1)

  /// The origin (x, y) coordinates of where all blocks are positioned in the workspace
  internal final var contentOrigin: WorkspacePoint = WorkspacePoint.zero

  // MARK: - Initializers

  /**
   Initializer for workspace layout.

   - parameter workspace: The `Workspace` model for this layout.
   - parameter engine: The `LayoutEngine` to associate with this layout.
   */
  public init(workspace: Workspace, engine: LayoutEngine) {
    self.workspace = workspace
    super.init(engine: engine)

    // Set the workspace's layout property
    workspace.layout = self
  }

  // MARK: - Super

  open override func performLayout(includeChildren: Bool) {
    var topLeftMostPoint = WorkspacePoint.zero
    var bottomRightMostPoint = WorkspacePoint.zero

    // Update relative position/size of blocks
    for i in 0 ..< self.blockGroupLayouts.count {
      let blockGroupLayout = self.blockGroupLayouts[i]
      if includeChildren {
        blockGroupLayout.performLayout(includeChildren: true)
      }

      if i == 0 {
        topLeftMostPoint = blockGroupLayout.relativePosition
        bottomRightMostPoint.x =
          blockGroupLayout.relativePosition.x + blockGroupLayout.totalSize.width
        bottomRightMostPoint.y =
          blockGroupLayout.relativePosition.y + blockGroupLayout.totalSize.height
      } else {
        topLeftMostPoint.x = min(topLeftMostPoint.x, blockGroupLayout.relativePosition.x)
        topLeftMostPoint.y = min(topLeftMostPoint.y, blockGroupLayout.relativePosition.y)
        bottomRightMostPoint.x = max(bottomRightMostPoint.x,
          blockGroupLayout.relativePosition.x + blockGroupLayout.totalSize.width)
        bottomRightMostPoint.y = max(bottomRightMostPoint.y,
          blockGroupLayout.relativePosition.y + blockGroupLayout.totalSize.height)
      }
    }

    // Update size required for the workspace
    self.contentOrigin = topLeftMostPoint
    self.contentSize = WorkspaceSize(
      width: bottomRightMostPoint.x - topLeftMostPoint.x,
      height: bottomRightMostPoint.y - topLeftMostPoint.y)


    // Set the content offset so children are automatically placed relative to (0, 0)
    self.childContentOffset = WorkspacePoint.zero - topLeftMostPoint

    // Update the canvas size
    sendChangeEvent(withFlags: WorkspaceLayout.Flag_UpdateCanvasSize)
  }

  open override func updateLayoutDownTree() {
    super.updateLayoutDownTree()

    // When this method is called, force a redisplay at the workspace level
    sendChangeEvent(withFlags: Layout.Flag_NeedsDisplay)
  }

  // MARK: - Public

  /**
   Returns all visible layouts associated with every block inside `self.workspace.allBlocks`.

   - returns: A list of all visible `BlockLayout` objects associated with every block in this
   workspace.
   */
  open func allVisibleBlockLayoutsInWorkspace() -> [BlockLayout] {
    return flattenedLayoutTree(ofType: BlockLayout.self).filter { $0.visible }
  }

  /**
  Appends a blockGroupLayout to `self.blockGroupLayouts` and sets its `parentLayout` to this
  instance.

  - parameter blockGroupLayout: The `BlockGroupLayout` to append.
  - parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  open func appendBlockGroupLayout(_ blockGroupLayout: BlockGroupLayout, updateLayout: Bool = true)
  {
    blockGroupLayouts.append(blockGroupLayout)
    adoptChildLayout(blockGroupLayout)

    if updateLayout {
      updateLayoutUpTree()
      sendChangeEvent(withFlags: WorkspaceLayout.Flag_NeedsDisplay)
    }
  }

  /**
  Removes a given block group layout from `self.blockGroupLayouts` and sets its `parentLayout` to
  nil.

  - parameter blockGroupLayout: The given block group layout.
  - parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  open func removeBlockGroupLayout(_ blockGroupLayout: BlockGroupLayout, updateLayout: Bool = true)
  {
    blockGroupLayouts = blockGroupLayouts.filter({ $0 != blockGroupLayout })
    removeChildLayout(blockGroupLayout)

    if updateLayout {
      updateLayoutUpTree()
      sendChangeEvent(withFlags: WorkspaceLayout.Flag_NeedsDisplay)
    }
  }

  /**
  Removes all elements from `self.blockGroupLayouts` and sets their `parentLayout` to nil.

  - parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  open func reset(updateLayout: Bool = true) {
    for blockGroupLayout in self.blockGroupLayouts {
      removeChildLayout(blockGroupLayout)
    }
    blockGroupLayouts.removeAll()

    if updateLayout {
      updateLayoutUpTree()
      sendChangeEvent(withFlags: Layout.Flag_NeedsDisplay)
    }
  }

  /**
  Brings the given block group layout to the front by setting its `zIndex` to the
  highest value in the workspace.

  - parameter blockGroupLayout: The given block group layout
  */
  open func bringBlockGroupLayoutToFront(_ blockGroupLayout: BlockGroupLayout?) {
    guard let blockGroupLayout = blockGroupLayout else {
      return
    }

    // Verify that this layout is a child of the workspace
    if !childLayouts.contains(blockGroupLayout) {
      return
    }
    if blockGroupLayout.zIndex == _zIndexCounter {
      // This block group is already at the highest level, don't need to do anything
      return
    }

    _zIndexCounter += 1
    blockGroupLayout.zIndex = _zIndexCounter

    if _zIndexCounter >= _maximumZIndexCounter {
      // The maximum z-position has been reached (unbelievable!). Normalize all block group layouts.
      _zIndexCounter = 1

      let ascendingBlockGroupLayouts = self.blockGroupLayouts.sorted(by: { $0.zIndex < $1.zIndex })

      for blockGroupLayout in ascendingBlockGroupLayouts {
        _zIndexCounter += 1
        blockGroupLayout.zIndex = _zIndexCounter
      }
    }
  }

  /**
   Updates the required size of this layout based on the current positions of all blocks.
   */
  open func updateCanvasSize() {
    performLayout(includeChildren: false)

    // View positions need to be refreshed for the entire tree since if the canvas size changes, the
    // positions of block groups also change.
    refreshViewPositionsForTree()
  }
}
