/*
 * Copyright 2016 Google Inc. All Rights Reserved.
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
 Object that is responsible for managing a worksapce layout. This includes maintaining the layout
 hierarchy of the workspace and ensuring that model and layout objects under this workspace layout
 remains in-sync.
 */
@objc(BKYWorkspaceLayoutCoordinator)
public class WorkspaceLayoutCoordinator: NSObject {
  /// The workspace layout whose layout hierarchy is being managed by this object
  public let workspaceLayout: WorkspaceLayout

  /// Builder for constructing layouts under `self.workspaceLayout`
  public final let layoutBuilder: LayoutBuilder

  /// Manager for tracking all connection positions under `self.workspaceLayout`. If this value
  /// is `nil`, connection positions aren't being tracked.
  public private(set) final var connectionManager: ConnectionManager?

  /// Object responsible for bumping blocks away from each other
  public let blockBumper = BlockBumper()

  // MARK: - Initializers / De-initializers

  /**
   Initializes the workspace layout coordinator.

   - Parameter workspaceLayout: The `WorkspaceLayout` that should be managed by this coordinator
   - Parameter layoutBuilder: Builder for constructing layouts under `workspaceLayout`
   - Parameter connectionManager: Manager for tracking all connection positions under
   `workspaceLayout`. If this value is `nil`, connection positions will not be tracked.
   */
  public init(
    workspaceLayout: WorkspaceLayout, layoutBuilder: LayoutBuilder,
    connectionManager: ConnectionManager?) throws
  {
    self.workspaceLayout = workspaceLayout
    self.layoutBuilder = layoutBuilder
    self.connectionManager = connectionManager

    super.init()

    blockBumper.workspaceLayoutCoordinator = self

    // Listen for changes in the workspace, so this object can update the layout hierarchy
    // appropriately
    workspaceLayout.workspace.listeners.add(self)

    // Build the layout tree, based on the existing state of the workspace. This creates a set of
    // layout objects for all of its blocks/inputs/fields
    try layoutBuilder.buildLayoutTree(workspaceLayout)

    // Perform a layout update for the entire tree
    workspaceLayout.updateLayoutDownTree()

    // Immediately start tracking connections of all visible blocks in the workspace
    for blockLayout in workspaceLayout.allVisibleBlockLayoutsInWorkspace() {
      trackConnections(forBlockLayout: blockLayout)
    }
  }

  deinit {
    workspaceLayout.workspace.listeners.remove(self)
  }

  // MARK: - Public

  public func addBlockTree(rootBlock: Block) throws {
    return try workspaceLayout.workspace.addBlockTree(rootBlock)
  }

  /**
   Disconnects a given block from its previous/output connections, and removes it and all of its
   connected blocks from the workspace.

   - Parameter rootBlock: The root block to remove.
   - Throws:
   `BlocklyError`: Thrown if the tree of blocks could not be removed from the workspace.
   */
  public func removeBlockTree(rootBlock: Block) throws {
    // Disconnect this block from anything
    if let previousConnection = rootBlock.previousConnection {
      disconnect(previousConnection)
    }
    if let outputConnection = rootBlock.outputConnection {
      disconnect(outputConnection)
    }

    try workspaceLayout.workspace.removeBlockTree(rootBlock)
  }

  /**
   Deep copies a block and adds all of the copied blocks into the workspace.

   - Parameter rootBlock: The root block to copy
   - Parameter editable: Sets whether each block is `editable` or not
   - Returns: The root block that was copied
   - Throws:
   `BlocklyError`: Thrown if the block could not be copied
   */
  public func copyBlockTree(rootBlock: Block, editable: Bool) throws -> Block {
    return try workspaceLayout.workspace.copyBlockTree(rootBlock, editable: editable)
  }

  /**
   Connects a pair of connections, disconnecting and possibly reattaching any existing connections,
   depending on the operation.

   - Parameter connectionPair: The pair to connect
   */
  public func connectPair(connectionPair: ConnectionManager.ConnectionPair) {
    let moving = connectionPair.moving
    let target = connectionPair.target

    do {
      switch (moving.type) {
      case .InputValue:
        try connectValueConnections(superior: moving, inferior: target)
      case .OutputValue:
        try connectValueConnections(superior: target, inferior: moving)
      case .NextStatement:
        try connectStatementConnections(superior: moving, inferior: target)
      case .PreviousStatement:
        try connectStatementConnections(superior: target, inferior: moving)
      }
    } catch let error as NSError {
      bky_assertionFailure("Could not connect pair together: \(error)")
    }
  }

  public func disconnect(connection: Connection) {
    let oldTarget = connection.targetConnection
    connection.disconnect()

    didChangeTarget(forConnection: connection, oldTarget: oldTarget)
    if let oldTarget = oldTarget {
      didChangeTarget(forConnection: oldTarget, oldTarget: connection)
    }
  }

  public func connect(connection1: Connection, _ connection2: Connection) throws {
    let oldTarget1 = connection1.targetConnection
    let oldTarget2 = connection2.targetConnection
    try connection1.connectTo(connection2)

    didChangeTarget(forConnection: connection1, oldTarget: oldTarget1)
    didChangeTarget(forConnection: connection2, oldTarget: oldTarget2)
  }

  // MARK: - Private

  /**
   Connects two value connections. If a block was previously connected to the superior connection,
   this method attempts to reattach it to the end of the inferior connection's block input value
   chain. If unsuccessful, the disconnected block is bumped away.
   */
  private func connectValueConnections(superior superior: Connection, inferior: Connection) throws {
    let previouslyConnectedBlock = superior.targetBlock

    // NOTE: Layouts are automatically re-computed after disconnecting/reconnecting
    disconnect(superior)
    disconnect(inferior)
    try connect(superior, inferior)

    // Bring the entire block group layout to the front
    if let rootBlockGroupLayout = superior.sourceBlock?.layout?.rootBlockGroupLayout {
      workspaceLayout.bringBlockGroupLayoutToFront(rootBlockGroupLayout)
    }

    if let previousOutputConnection = previouslyConnectedBlock?.outputConnection {
      if let lastInputConnection = inferior.sourceBlock?.lastInputValueConnectionInChain()
        where lastInputConnection.canConnectTo(previousOutputConnection)
      {
        // Try to reconnect previously connected block to the end of the input value chain
        try connect(lastInputConnection, previousOutputConnection)
      } else {
        // Bump previously connected block away from the superior connection
        blockBumper.bumpBlockLayoutOfConnection(previousOutputConnection,
                                                 awayFromConnection: superior)
      }
    }
  }

  /**
   Connects two statement connections. If a block was previously connected to the superior
   connection, this method attempts to reattach it to the end of the inferior connection's block
   chain. If unsuccessful, the disconnected block is bumped away.

   - Parameter superior: A connection of type `.NextStatement`
   - Parameter inferior: A connection of type `.PreviousStatement`
   - Throws:
   `BlocklyError`: Thrown if the previous/next statements could not be connected together or if
   the previously disconnected block could not be re-connected to the end of the block chain.
   */
  private func connectStatementConnections(superior superior: Connection, inferior: Connection)
    throws
  {
    let previouslyConnectedBlock = superior.targetBlock

    // NOTE: Layouts are automatically re-computed after disconnecting/reconnecting
    disconnect(superior)
    disconnect(inferior)
    try connect(superior, inferior)

    // Bring the entire block group layout to the front
    if let rootBlockGroupLayout = superior.sourceBlock?.layout?.rootBlockGroupLayout {
      workspaceLayout.bringBlockGroupLayoutToFront(rootBlockGroupLayout)
    }

    if let previousConnection = previouslyConnectedBlock?.previousConnection {
      if let lastConnection = inferior.sourceBlock?.lastBlockInChain().nextConnection
        where lastConnection.canConnectTo(previousConnection)
      {
        // Reconnect previously connected block to the end of the block chain
        try connect(lastConnection, previousConnection)
      } else {
        // Bump previously connected block away from the superior connection
        blockBumper.bumpBlockLayoutOfConnection(previousConnection, awayFromConnection: superior)
      }
    }
  }

  private func didChangeTarget(forConnection connection: Connection, oldTarget: Connection?)
  {
    do {
      try updateLayoutTree(forConnection: connection, oldTarget: oldTarget)
    } catch let error as NSError {
      bky_assertionFailure("Could not update layout tree for connection: \(error)")
    }
  }

  private func didChangeShadow(forConnection connection: Connection, oldShadow: Connection?)
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
      try layoutBuilder.layoutFactory.layoutForBlockGroupLayout(engine: workspaceLayout.engine)
    try layoutBuilder.buildLayoutTreeForBlockGroupLayout(shadowBlockGroupLayout, block: shadowBlock)
    let shadowBlockLayouts = shadowBlockGroupLayout.blockLayouts

    // Add shadow block layouts to proper block group
    if let blockGroupLayout =
      (aConnection.sourceInput?.layout?.blockGroupLayout ?? // For input values or statements
        aConnection.sourceBlock.layout?.parentBlockGroupLayout) // For a block's next statement
    {
      Layout.doNotAnimate {
        blockGroupLayout.appendBlockLayouts(shadowBlockLayouts, updateLayout: true)
        blockGroupLayout.performLayout(includeChildren: true)
        blockGroupLayout.refreshViewPositionsForTree()
      }

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
      workspaceLayout.sendChangeEventWithFlags(WorkspaceLayout.Flag_NeedsDisplay)
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
      workspaceLayout.sendChangeEventWithFlags(WorkspaceLayout.Flag_NeedsDisplay)
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

    let workspace = workspaceLayout.workspace

    guard (connection.targetBlock == nil || workspace.containsBlock(connection.targetBlock!)) &&
      workspace.containsBlock(sourceBlock) else
    {
      throw BlocklyError(.IllegalState, "Can't connect blocks from different workspaces")
    }

    // Keep a reference to the old parent block group layout, in case we need to clean it up later
    // (if it becomes empty).
    let oldParentLayout = sourceBlockLayout.parentBlockGroupLayout

    if let targetConnection = connection.targetConnection {
      // `targetConnection` is connected to something now.
      // Remove its shadow block layout tree (if it exists).
      try removeShadowBlockLayoutTree(forShadowBlock: targetConnection.shadowBlock)

      // Move `sourceBlockLayout` and its followers to a new block group layout
      if let targetInputLayout = targetConnection.sourceInput?.layout {
        // Move them to target input's block group layout
        targetInputLayout.blockGroupLayout
          .claimBlockLayoutAndFollowers(sourceBlockLayout, updateLayouts: true)
      } else if let targetBlockLayout = targetConnection.sourceBlock.layout {
        // Move them to the target block's group layout
        targetBlockLayout.parentBlockGroupLayout?
          .claimBlockLayoutAndFollowers(sourceBlockLayout, updateLayouts: true)
      }
    } else {
      // The connection is no longer connected to anything.

      // Block was disconnected and added to the workspace level.
      // Create a new block group layout and set its `relativePosition` to the current absolute
      // position of the block that was disconnected
      let layoutFactory = layoutBuilder.layoutFactory
      let blockGroupLayout =
        try layoutFactory.layoutForBlockGroupLayout(engine: workspaceLayout.engine)
      blockGroupLayout.relativePosition = sourceBlockLayout.absolutePosition

      Layout.doNotAnimate {
        // Add this new block group layout to the workspace level
        self.workspaceLayout.appendBlockGroupLayout(blockGroupLayout, updateLayout: true)
        self.workspaceLayout.bringBlockGroupLayoutToFront(blockGroupLayout)
      }

      blockGroupLayout.claimBlockLayoutAndFollowers(sourceBlockLayout, updateLayouts: true)
    }

    // Re-create the shadow block layout tree for the previous connection target (if it has one).
    try addShadowBlockLayoutTree(forConnection: oldTarget)

    // If the previous block group layout parent of `sourceBlockLayout` is now empty and is at the
    // the top-level of the workspace, remove it
    if let emptyBlockGroupLayout = oldParentLayout
      where emptyBlockGroupLayout.blockLayouts.count == 0 &&
        emptyBlockGroupLayout.parentLayout == workspaceLayout
    {
      Layout.doNotAnimate {
        // Remove this block's old parent group layout from the workspace level
        self.workspaceLayout.removeBlockGroupLayout(emptyBlockGroupLayout, updateLayout: true)
      }
    }

    Layout.doNotAnimate {
      self.workspaceLayout.updateCanvasSize()
    }
  }

  /**
   Tracks connections for a given block layout under `self.connectionManager`.
   If `self.connectionManager is nil, nothing happens.

   - Parameter blockLayout: The `BlockLayout` whose connections should be tracked.
   */
  private func trackConnections(forBlockLayout blockLayout: BlockLayout) {
    guard let connectionManager = self.connectionManager
     where blockLayout.visible else
    {
      // Only track connections for visible block layouts
      return
    }

    // Track positional changes for each connection in the connection manager
    for connection in blockLayout.block.directConnections {
      connectionManager.trackConnection(connection)
    }
  }

  /**
   Untracks connections for a given block layout under `self.connectionManager`.
   If `self.connectionManager is nil, nothing happens.

   - Parameter blockLayout: The `BlockLayout` whose connections should be untracked.
   */
  private func untrackConnections(forBlockLayout blockLayout: BlockLayout) {
    guard let connectionManager = self.connectionManager else {
      return
    }

    // Untrack positional changes for each connection in the connection manager
    for connection in blockLayout.block.directConnections {
      connectionManager.untrackConnection(connection)
    }
  }
}

// MARK: - WorkspaceListener implementation

extension WorkspaceLayoutCoordinator: WorkspaceListener {
  public func workspace(workspace: Workspace, didAddBlock block: Block) {
    if !block.topLevel {
      // We only need to create layout trees for top level blocks
      return
    }

    do {
      // Create the layout tree for this newly added block
      if let blockGroupLayout =
        try layoutBuilder.buildLayoutTreeForTopLevelBlock(block, workspaceLayout: workspaceLayout)
      {
        // Perform a layout for the tree
        blockGroupLayout.updateLayoutDownTree()

        // Track connections of all new block layouts that were added
        for blockLayout in blockGroupLayout.flattenedLayoutTree(ofType: BlockLayout.self) {
          trackConnections(forBlockLayout: blockLayout)
        }

        // Update the content size
        workspaceLayout.updateCanvasSize()

        // Schedule change event for an added block layout
        workspaceLayout.sendChangeEventWithFlags(WorkspaceLayout.Flag_NeedsDisplay)
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

      workspaceLayout.removeBlockGroupLayout(blockGroupLayout)

      workspaceLayout.sendChangeEventWithFlags(WorkspaceLayout.Flag_NeedsDisplay)
    }
  }
}
