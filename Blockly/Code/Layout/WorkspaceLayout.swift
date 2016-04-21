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

/*
Stores information on how to render and position a `Workspace` on-screen.
*/
@objc(BKYWorkspaceLayout)
public class WorkspaceLayout: Layout {
  // MARK: - Static Properties

  /// Flag that should be used when the canvas size of the workspace has been updated.
  public static let Flag_UpdateCanvasSize = LayoutFlag(0)

  /// Flag that should be used when a block layout has been added to the workspace
  public static let Flag_AddedBlockLayout = LayoutFlag(1)

  /// Flag that should be used when a block layout has been removed from the workspace
  public static let Flag_RemovedBlockLayout = LayoutFlag(2)

  // MARK: - Properties

  /// The `Workspace` to layout
  public final let workspace: Workspace

  /// The locations of all connections in this workspace
  public final let connectionManager: ConnectionManager

  /// Builder for constructing layouts under this workspace
  public final let layoutBuilder: LayoutBuilder

  /// All child `BlockGroupLayout` objects that have been appended to this layout
  public final var blockGroupLayouts = [BlockGroupLayout]()

  /// z-index counter used to layer blocks in a specific order.
  private var _zIndexCounter: UInt = 1

  /// Maximum value that the z-index counter should reach
  private var _maximumZIndexCounter: UInt = (UInt.max - 1)

  /// The origin (x, y) coordinates of where all blocks are positioned in the workspace
  internal final var contentOrigin: WorkspacePoint = WorkspacePointZero

  // MARK: - Initializers

  public init(workspace: Workspace, engine: LayoutEngine, layoutBuilder: LayoutBuilder) throws {
    self.workspace = workspace
    self.layoutBuilder = layoutBuilder
    self.connectionManager = ConnectionManager()
    super.init(engine: engine)

    // Assign the layout as the workspace's delegate so it can listen for new events that
    // occur on the workspace
    workspace.delegate = self

    // Immediately start tracking all connections of blocks in the workspace
    for (_, block) in workspace.allBlocks {
      trackConnectionsForBlock(block)
    }

    // Build the layout tree, based on the existing state of the workspace. This creates a set of
    // layout objects for all of its blocks/inputs/fields
    try self.layoutBuilder.buildLayoutTree(self)

    // Perform a layout update for the entire tree
    updateLayoutDownTree()
  }

  // MARK: - Super

  public override func performLayout(includeChildren includeChildren: Bool) {
    var topLeftMostPoint = WorkspacePointZero
    var bottomRightMostPoint = WorkspacePointZero

    // Update relative position/size of blocks
    for i in 0 ..< self.blockGroupLayouts.count {
      let blockGroupLayout = self.blockGroupLayouts[i]
      if includeChildren {
        blockGroupLayout.performLayout(includeChildren: true)
      }

      if i == 0 {
        topLeftMostPoint = blockGroupLayout.relativePosition
        bottomRightMostPoint.x = blockGroupLayout.relativePosition.x + blockGroupLayout.totalSize.width
        bottomRightMostPoint.y = blockGroupLayout.relativePosition.y + blockGroupLayout.totalSize.height
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
    self.contentSize = WorkspaceSizeMake(
      bottomRightMostPoint.x - topLeftMostPoint.x,
      bottomRightMostPoint.y - topLeftMostPoint.y)

    // Update the canvas size
    scheduleChangeEventWithFlags(WorkspaceLayout.Flag_UpdateCanvasSize)
  }

  public override func updateLayoutDownTree() {
    super.updateLayoutDownTree()

    // When this method is called, force a redisplay at the workspace level
    scheduleChangeEventWithFlags(Layout.Flag_NeedsDisplay)
  }

  // MARK: - Public

  /**
  Returns all layouts associated with every block inside `self.workspace.allBlocks`.
  */
  public func allBlockLayoutsInWorkspace() -> [BlockLayout] {
    var descendants = [BlockLayout]()
    for (_, block) in workspace.allBlocks {
      if let layout = block.layout {
        descendants.append(layout)
      }
    }
    return descendants
  }

  /**
  Appends a blockGroupLayout to `self.blockGroupLayouts` and sets its `parentLayout` to this
  instance.

  - Parameter blockGroupLayout: The `BlockGroupLayout` to append.
  - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  public func appendBlockGroupLayout(blockGroupLayout: BlockGroupLayout, updateLayout: Bool = true)
  {
    blockGroupLayouts.append(blockGroupLayout)
    blockGroupLayout.parentLayout = self

    if updateLayout {
      updateLayoutUpTree()
      scheduleChangeEventWithFlags(WorkspaceLayout.Flag_AddedBlockLayout)
    }
  }

  /**
  Removes a given block group layout from `self.blockGroupLayouts` and sets its `parentLayout` to
  nil.

  - Parameter blockGroupLayout: The given block group layout.
  - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  public func removeBlockGroupLayout(blockGroupLayout: BlockGroupLayout, updateLayout: Bool = true)
  {
    blockGroupLayouts = blockGroupLayouts.filter({ $0 != blockGroupLayout })
    blockGroupLayout.parentLayout = nil

    if updateLayout {
      updateLayoutUpTree()
      scheduleChangeEventWithFlags(WorkspaceLayout.Flag_RemovedBlockLayout)
    }
  }

  /**
  Removes all elements from `self.blockGroupLayouts` and sets their `parentLayout` to nil.

  - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  public func reset(updateLayout updateLayout: Bool = true) {
    for blockGroupLayout in self.blockGroupLayouts {
      blockGroupLayout.parentLayout = nil
    }
    blockGroupLayouts.removeAll()

    if updateLayout {
      updateLayoutUpTree()
      scheduleChangeEventWithFlags(Layout.Flag_NeedsDisplay)
    }
  }

  /**
  Brings the given block group layout to the front by setting its `zIndex` to the
  highest value in the workspace.

  - Parameter blockGroupLayout: The given block group layout
  */
  public func bringBlockGroupLayoutToFront(layout: BlockGroupLayout?) {
    guard let blockGroupLayout = layout else {
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

      let ascendingBlockGroupLayouts = self.blockGroupLayouts.sort({ $0.zIndex < $1.zIndex })

      for blockGroupLayout in ascendingBlockGroupLayouts {
        _zIndexCounter += 1
        blockGroupLayout.zIndex = _zIndexCounter
      }
    }
  }

  /**
   Updates the required size of this layout based on the current positions of all blocks.
   */
  public func updateCanvasSize() {
    performLayout(includeChildren: false)

    // View positions need to be refreshed for the entire tree since if the canvas size changes, the
    // positions of block groups also change.
    refreshViewPositionsForTree()
  }

  // MARK: - Private

  private func trackConnectionsForBlock(block: Block) {
    // Automatically track changes to the connection so we can update the layout hierarchy
    // accordingly
    for connection in block.directConnections {
      connection.targetDelegate = self
      connectionManager.trackConnection(connection)
    }
  }

  private func untrackConnectionsForBlock(block: Block) {
    // Detach connection tracking for the block
    for connection in block.directConnections {
      connection.targetDelegate = nil
      connectionManager.untrackConnection(connection)
    }
  }
}

// MARK: - WorkspaceDelegate implementation

extension WorkspaceLayout: WorkspaceDelegate {
  public func workspace(workspace: Workspace, didAddBlock block: Block) {
    trackConnectionsForBlock(block)

    if !block.topLevel {
      // We only need to create layout trees for top level blocks
      return
    }

    do {
      // Create the layout tree for this newly added block
      if let blockGroupLayout =
        try self.layoutBuilder.buildLayoutTreeForTopLevelBlock(block, workspaceLayout: self)
      {
        // Perform a layout for the tree
        blockGroupLayout.updateLayoutDownTree()

        // Update the content size
        updateCanvasSize()

        // Schedule change event for an added block layout
        scheduleChangeEventWithFlags(WorkspaceLayout.Flag_AddedBlockLayout)
      }
    } catch let error as NSError {
      bky_assertionFailure("Could not create the layout tree for block: \(error)")
    }
  }

  public func workspace(workspace: Workspace, willRemoveBlock block: Block) {
    untrackConnectionsForBlock(block)

    if !block.topLevel {
      // We only need to remove layout trees for top-level blocks
      return
    }

    if let blockGroupLayout = block.layout?.parentBlockGroupLayout {
      removeBlockGroupLayout(blockGroupLayout)

      scheduleChangeEventWithFlags(WorkspaceLayout.Flag_RemovedBlockLayout)
    }
  }
}

// MARK: - ConnectionTargetDelegate

extension WorkspaceLayout: ConnectionTargetDelegate {
  public func didChangeTargetForConnection(connection: Connection) {
    do {
      try updateLayoutHierarchyForConnection(connection)
    } catch let error as NSError {
      bky_assertionFailure("Could not update layout for connection: \(error)")
    }
  }

  /**
   Whenever a connection has been changed for a block in the workspace, this method is called to
   ensure that the layout hierarchy is properly kept in sync to reflect this change.
  */
  private func updateLayoutHierarchyForConnection(connection: Connection) throws {
    // TODO:(#29) Optimize re-rendering all layouts affected by this method

    let sourceBlock = connection.sourceBlock
    let sourceBlockLayout = sourceBlock.layout as BlockLayout!

    if connection != sourceBlock.previousConnection && connection != sourceBlock.outputConnection {
      // Only previous/output connectors are responsible for updating the block group
      // layout hierarchy, not next/input connectors.
      return
    }

    // Check that there are layouts for both the source and target blocks of this connection
    if sourceBlockLayout == nil ||
      (connection.sourceInput != nil && connection.sourceInput!.layout == nil) ||
      (connection.targetBlock != nil && connection.targetBlock!.layout == nil)
    {
      throw BlocklyError(.IllegalState, "Can't connect a block without a layout. ")
    }

    // Check that this layout is connected to a block group layout
    if sourceBlock.layout?.parentBlockGroupLayout == nil {
      throw BlocklyError(.IllegalState,
        "Block layout is not connected to a parent block group layout. ")
    }

    if (connection.targetBlock != nil &&
      connection.targetBlock!.layout?.workspaceLayout != sourceBlockLayout.workspaceLayout)
    {
      throw BlocklyError(.IllegalState, "Can't connect blocks in different workspaces")
    }

    // Disconnect this block's layout and all subsequent block layouts from its block group layout,
    // so they can be reattached to another block group layout
    let layoutsToReattach: [BlockLayout]
    if let oldParentLayout = sourceBlockLayout.parentBlockGroupLayout {
      layoutsToReattach =
        oldParentLayout.removeAllStartingFromBlockLayout(sourceBlockLayout, updateLayout: true)

      if oldParentLayout.blockLayouts.count == 0 &&
        oldParentLayout.parentLayout == workspace.layout {
          // Remove this block's old parent group layout from the workspace level
          removeBlockGroupLayout(oldParentLayout, updateLayout: true)
      }
    } else {
      layoutsToReattach = [sourceBlockLayout]
    }

    if let targetConnection = connection.targetConnection {
      // Block was connected to another block

      if targetConnection.sourceInput != nil {
        // Reattach block layouts to target input's block group layout
        targetConnection.sourceInput!.layout?.blockGroupLayout
          .appendBlockLayouts(layoutsToReattach, updateLayout: true)
      } else {
        // Reattach block layouts to the target block's group layout
        targetConnection.sourceBlock.layout?.parentBlockGroupLayout?
          .appendBlockLayouts(layoutsToReattach, updateLayout: true)
      }
    } else {
      // Block was disconnected and added to the workspace level.
      // Create a new block group layout and set its `relativePosition` to the current absolute
      // position of the block that was disconnected
      let layoutFactory = self.layoutBuilder.layoutFactory
      let blockGroupLayout = try layoutFactory.layoutForBlockGroupLayout(engine: self.engine)
      blockGroupLayout.relativePosition = sourceBlockLayout.absolutePosition

      // Add this new block group layout to the workspace level
      appendBlockGroupLayout(blockGroupLayout, updateLayout: false)
      bringBlockGroupLayoutToFront(blockGroupLayout)

      // Reattach block layouts to a new block group layout
      blockGroupLayout.appendBlockLayouts(layoutsToReattach, updateLayout: true)
    }
  }
}
