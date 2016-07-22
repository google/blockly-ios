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

    // Build the layout tree, based on the existing state of the workspace. This creates a set of
    // layout objects for all of its blocks/inputs/fields
    try self.layoutBuilder.buildLayoutTree(self)

    // Perform a layout update for the entire tree
    updateLayoutDownTree()

    // Immediately start tracking connections of all visible blocks in the workspace
    for blockLayout in allVisibleBlockLayoutsInWorkspace() {
      trackConnections(forBlockLayout: blockLayout)
    }
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
  Returns all visible layouts associated with every block inside `self.workspace.allBlocks`.
  */
  public func allVisibleBlockLayoutsInWorkspace() -> [BlockLayout] {
    return flattenedLayoutTree(ofType: BlockLayout.self).filter { $0.visible }
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
    adoptChildLayout(blockGroupLayout)

    if updateLayout {
      updateLayoutUpTree()
      scheduleChangeEventWithFlags(WorkspaceLayout.Flag_NeedsDisplay)
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
    removeChildLayout(blockGroupLayout)

    if updateLayout {
      updateLayoutUpTree()
      scheduleChangeEventWithFlags(WorkspaceLayout.Flag_NeedsDisplay)
    }
  }

  /**
  Removes all elements from `self.blockGroupLayouts` and sets their `parentLayout` to nil.

  - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  public func reset(updateLayout updateLayout: Bool = true) {
    for blockGroupLayout in self.blockGroupLayouts {
      removeChildLayout(blockGroupLayout)
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

  private func trackConnections(forBlockLayout blockLayout: BlockLayout) {
    guard blockLayout.visible else {
      // Only track connections for visible block layouts
      return
    }

    // Automatically track changes to the connection so we can update the layout hierarchy
    // accordingly
    for connection in blockLayout.block.directConnections {
      connection.targetDelegate = self
      connectionManager.trackConnection(connection)
    }
  }

  private func untrackConnections(forBlockLayout blockLayout: BlockLayout) {
    // Detach connection tracking for the block
    for connection in blockLayout.block.directConnections {
      connection.targetDelegate = nil
      connectionManager.untrackConnection(connection)
    }
  }
}

// MARK: - WorkspaceDelegate implementation

extension WorkspaceLayout: WorkspaceDelegate {
  public func workspace(workspace: Workspace, didAddBlock block: Block) {
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

        // Track connections of all new block layouts that were added
        for blockLayout in blockGroupLayout.flattenedLayoutTree(ofType: BlockLayout.self) {
          trackConnections(forBlockLayout: blockLayout)
        }

        // Update the content size
        updateCanvasSize()

        // Schedule change event for an added block layout
        scheduleChangeEventWithFlags(WorkspaceLayout.Flag_NeedsDisplay)
      }
    } catch let error as NSError {
      bky_assertionFailure("Could not create the layout tree for block: \(error)")
    }
  }

  public func workspace(workspace: Workspace, willRemoveBlock block: Block) {
    if !block.topLevel {
      // We only need to remove layout trees for top-level blocks
      return
    }

    if let blockGroupLayout = block.layout?.parentBlockGroupLayout {
      // Untrack connections for all block layouts that will be removed
      for blockLayout in blockGroupLayout.flattenedLayoutTree(ofType: BlockLayout.self) {
        untrackConnections(forBlockLayout: blockLayout)
      }

      removeBlockGroupLayout(blockGroupLayout)

      scheduleChangeEventWithFlags(WorkspaceLayout.Flag_NeedsDisplay)
    }
  }
}

// MARK: - ConnectionTargetDelegate

extension WorkspaceLayout: ConnectionTargetDelegate {
  public func didChangeTarget(forConnection connection: Connection, oldTarget: Connection?)
  {
    do {
      try updateLayoutTree(forConnection: connection, oldTarget: oldTarget)
    } catch let error as NSError {
      bky_assertionFailure("Could not update layout tree for connection: \(error)")
    }
  }

  public func didChangeShadow(forConnection connection: Connection, oldShadow: Connection?)
  {
    do {
      if connection.shadowConnected && !connection.connected {
        // There's a new shadow block for the connection and it is not connected to anything.
        // Add the shadow block layout tree.
        try addShadowBlockLayoutTree(forConnection: connection)
      } else if !connection.shadowConnected {
        // There's no shadow block for the connection. Remove the shadow block layout tree.
        try removeShadowBlockLayoutTree(forShadowBlock: oldShadow?.sourceBlock)
      }
    } catch let error as NSError {
      bky_assertionFailure("Could not update shadow block layout tree for connection: \(error)")
    }
  }

  /**
   Adds shadow blocks for a given connection to the layout tree. If the shadow blocks already exist
   or if no shadow blocks are connected to the given connection, nothing happens.

   - Note: This method only updates the layout tree if the given connection is of type
   `.NextStatement` or `.InputValue`. Otherwise, this method does nothing.

   - Parameter connection: The connection that should have its shadow blocks added to the layout
   tree
   */
  private func addShadowBlockLayoutTree(forConnection connection: Connection?) throws {
    guard let aConnection = connection,
      shadowBlock = aConnection.shadowBlock
      where (aConnection.type == .NextStatement || aConnection.type == .InputValue) &&
        shadowBlock.layout == nil && !aConnection.connected else
    {
      // Only next/input connectors are responsible for updating the shadow block group
      // layout hierarchy, not previous/output connectors.
      return
    }

    // Nothing is connected to aConnection. Re-create the shadow block hierarchy since it doesn't
    // exist.
    let shadowBlockGroupLayout =
      try layoutBuilder.layoutFactory.layoutForBlockGroupLayout(engine: engine)
    try layoutBuilder.buildLayoutTreeForBlockGroupLayout(shadowBlockGroupLayout, block: shadowBlock)
    let shadowBlockLayouts = shadowBlockGroupLayout.blockLayouts

    // Add shadow block layouts to proper block group
    if let blockGroupLayout =
      (aConnection.sourceInput?.layout?.blockGroupLayout ?? // For input values or statements
      aConnection.sourceBlock.layout?.parentBlockGroupLayout) // For a block's next statement
    {
      blockGroupLayout.appendBlockLayouts(shadowBlockLayouts, updateLayout: false)
      blockGroupLayout.performLayout(includeChildren: true)
      blockGroupLayout.updateLayoutUpTree()
    }

    // Update connection tracking
    let allBlockLayouts = shadowBlockLayouts.flatMap {
      $0.flattenedLayoutTree(ofType: BlockLayout.self)
    }
    for blockLayout in allBlockLayouts {
      trackConnections(forBlockLayout: blockLayout)
    }

    if allBlockLayouts.count > 0 {
      scheduleChangeEventWithFlags(WorkspaceLayout.Flag_NeedsDisplay)
    }
  }

  /**
   Removes a shadow block layout tree from its parent layout, starting from a given shadow block.

   - Parameter shadowBlock: The shadow block
   */
  private func removeShadowBlockLayoutTree(forShadowBlock shadowBlock: Block?) throws {
    guard let shadowBlockLayout = shadowBlock?.layout,
      shadowBlockLayoutParent = shadowBlockLayout.parentBlockGroupLayout
      where (shadowBlock?.shadow ?? false) else
    {
      // There is no shadow block layout for this block.
      return
    }

    // Remove all layouts connected to this shadow block layout
    let removedLayouts = shadowBlockLayoutParent
      .removeAllStartingFromBlockLayout(shadowBlockLayout, updateLayout: false)
      .flatMap { $0.flattenedLayoutTree(ofType: BlockLayout.self) }

    for removedLayout in removedLayouts {
      // Set the delegate of the block to nil (effectively removing its BlockLayout)
      removedLayout.block.delegate = nil
      // Untrack connections for the layout
      untrackConnections(forBlockLayout: removedLayout)
    }

    if removedLayouts.count > 0 {
      scheduleChangeEventWithFlags(WorkspaceLayout.Flag_NeedsDisplay)
    }
  }

  /**
   Whenever a connection has been changed for a block in the workspace, this method is called to
   ensure that the layout tree is properly kept in sync to reflect this change.

   - Note: This method only updates the layout tree if the given connection is of type
   `.PreviousStatement` or `.OutputValue`. Otherwise, this method does nothing.

   - Parameter connection: The connection that changed
   - Parameter oldTarget: The previous value of `connection.targetConnection`
  */
  private func updateLayoutTree(forConnection connection: Connection, oldTarget: Connection?) throws
  {
    // TODO:(#29) Optimize re-rendering all layouts affected by this method

    guard connection.type == .PreviousStatement || connection.type == .OutputValue else {
      // Only previous/output connectors are responsible for updating the block group
      // layout hierarchy, not next/input connectors.
      return
    }

    // Check that there are layouts for both the source and target blocks of this connection
    guard let sourceBlock = connection.sourceBlock,
      let sourceBlockLayout = sourceBlock.layout
      where connection.targetConnection?.sourceInput == nil ||
        connection.targetConnection?.sourceInput?.layout != nil ||
        connection.targetConnection?.sourceBlock == nil ||
        connection.targetConnection?.sourceBlock?.layout != nil
      else
    {
      throw BlocklyError(.IllegalState, "Can't connect a block without a layout. ")
    }

    // Check that this layout is connected to a block group layout
    guard sourceBlock.layout?.parentBlockGroupLayout != nil else {
      throw BlocklyError(.IllegalState,
        "Block layout is not connected to a parent block group layout. ")
    }

    guard (connection.targetBlock == nil || workspace.containsBlock(connection.targetBlock!)) &&
      workspace.containsBlock(sourceBlock) else
    {
      throw BlocklyError(.IllegalState, "Can't connect blocks from different workspaces")
    }

    // TODO:(#119) Update this code to perform a proper move, instead of a remove/add. The reason is
    // that a remove/add will force a corresponding remove/add on the view hierarchy, which isn't
    // efficient that forces a view hierarchy recreation.

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
      // `targetConnection` is connected to something now.
      // Remove its shadow block layout tree (if it exists).
      try removeShadowBlockLayoutTree(forShadowBlock: targetConnection.shadowBlock)

      // Reattach the layouts to the proper block group layout
      if let targetInputLayout = targetConnection.sourceInput?.layout {
        // Reattach block layouts to target input's block group layout
        targetInputLayout.blockGroupLayout
          .appendBlockLayouts(layoutsToReattach, updateLayout: true)
      } else if let targetBlockLayout = targetConnection.sourceBlock.layout {
        // Reattach block layouts to the target block's group layout
        targetBlockLayout.parentBlockGroupLayout?
          .appendBlockLayouts(layoutsToReattach, updateLayout: true)
      }
    } else {
      // The connection is no longer connected to anything.

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

    // Re-create the shadow block layout tree for the previous connection target (if it has one).
    try addShadowBlockLayoutTree(forConnection: oldTarget)

    updateCanvasSize()
  }
}
