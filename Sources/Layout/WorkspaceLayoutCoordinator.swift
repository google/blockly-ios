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
@objcMembers open class WorkspaceLayoutCoordinator: NSObject {
  // MARK: - Properties

  /// The workspace layout whose layout hierarchy is being managed by this object
  open let workspaceLayout: WorkspaceLayout

  /// Builder for constructing layouts under `self.workspaceLayout`
  public final let layoutBuilder: LayoutBuilder

  /// Manager for tracking all connection positions under `self.workspaceLayout`. If this value
  /// is `nil`, connection positions aren't being tracked.
  public fileprivate(set) final var connectionManager: ConnectionManager?

  /// Object responsible for bumping blocks away from each other
  open let blockBumper = BlockBumper()

  /// Manager responsible for keeping track of all variable names under this workspace
  public weak var variableNameManager: NameManager? {
    didSet {
      if variableNameManager == oldValue {
        return
      }

      oldValue?.listeners.remove(self)

      workspaceLayout.flattenedLayoutTree(ofType: BlockLayout.self).forEach {
        removeNameManager(fromBlockLayout: $0)
      }
      workspaceLayout.flattenedLayoutTree(ofType: BlockLayout.self).forEach {
        addNameManager(variableNameManager, toBlockLayout: $0)
      }

      variableNameManager?.listeners.add(self)
    }
  }

  /// The factory for building blocks dynamically. Currently only used for building variable blocks
  ///  for the toolbox.
  public var blockFactory: BlockFactory?

  // MARK: - Initializers / De-initializers

  /**
   Initializes the workspace layout coordinator.

   - parameter workspaceLayout: The `WorkspaceLayout` that should be managed by this coordinator
   - parameter layoutBuilder: Builder for constructing layouts under `workspaceLayout`
   - parameter connectionManager: Manager for tracking all connection positions under
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
    try layoutBuilder.buildLayoutTree(forWorkspaceLayout: workspaceLayout)

    // Perform a layout update for the entire tree
    workspaceLayout.updateLayoutDownTree()

    // Immediately start tracking all visible blocks in the workspace
    for blockLayout in workspaceLayout.allVisibleBlockLayoutsInWorkspace() {
      trackBlockLayout(blockLayout)
    }

    variableNameManager?.listeners.add(self)
  }

  deinit {
    workspaceLayout.workspace.listeners.remove(self)
    variableNameManager?.listeners.remove(self)
  }

  // MARK: - Public

  /**
   Adds a block tree (a block and its children) to the workspace handled by the workspace layout
   coordinator. The layout heirarchy is automatically updated to reflect this change.

   - parameter rootBlock: The parent `Block` to add.
   - throws:
     `BlocklyError`: If the block to be added would put the workspace into an illegal state.
   */
  open func addBlockTree(_ rootBlock: Block) throws {
    try workspaceLayout.workspace.addBlockTree(rootBlock)
  }

  /**
   Disconnects a given block from its previous/output connections, and removes it and all of its
   connected blocks from the workspace.

   - parameter rootBlock: The root block to remove.
   - throws:
   `BlocklyError`: Thrown if the tree of blocks could not be removed from the workspace.
   */
  open func removeBlockTree(_ rootBlock: Block) throws {
    // Disconnect this block from anything
    if let previousConnection = rootBlock.previousConnection {
      try disconnect(previousConnection)
      try disconnectShadow(previousConnection)
    }
    if let outputConnection = rootBlock.outputConnection {
      try disconnect(outputConnection)
      try disconnectShadow(outputConnection)
    }

    try workspaceLayout.workspace.removeBlockTree(rootBlock)
  }

  /**
   Disconnects a single block from all connections, and removes it. This function will also
   reconnect next blocks to the previous block.

   - parameter block: The block to remove.
   - throws:
   `BlocklyError`: Thrown if the block could not be removed from the workspace, or if the
     connections can't be reconnected.
   */
  open func removeSingleBlock(_ block: Block) throws {
    // Disconnect the previous connection.
    var oldSuperior: Connection? = nil
    if let previousConnection = block.previousConnection {
      oldSuperior = previousConnection.targetConnection
      try disconnect(previousConnection)
    }

    // Disconnect the next connection. If both next and previous were connected, reconnect the
    // next block with the old previous block.
    if let nextConnection = block.nextConnection {
      let oldInferior = nextConnection.targetConnection
      try disconnect(nextConnection)
      if let inferior = oldInferior,
        let superior = oldSuperior,
        inferior.canConnectTo(superior) {
        try connectStatementConnections(superior: superior, inferior: inferior)
      }
    }

    // Disconnect any other non-shadow connections.
    for connection in block.directConnections {
      if connection != block.previousConnection &&
        connection != block.nextConnection &&
        !connection.shadowConnected
      {
        try disconnect(connection)
      }
    }

    try workspaceLayout.workspace.removeBlockTree(block)
  }

  /**
   Deep copies a block and adds all of the copied blocks into the workspace.

   - parameter rootBlock: The root block to copy
   - parameter editable: Sets whether each block is `editable` or not
   - parameter position: [Optional] The position of where the copied block should be placed in the
   workspace. Defaults to `WorkspacePoint.zero`.
   - returns: The root block that was copied
   - throws:
   `BlocklyError`: Thrown if the block could not be copied
   */
  open func copyBlockTree(_ rootBlock: Block, editable: Bool,
                          position: WorkspacePoint = WorkspacePoint.zero) throws -> Block
  {
    let blockCopy = try workspaceLayout.workspace.copyBlockTree(
      rootBlock, editable: editable, position: position)

    return blockCopy
  }

  /**
   Connects a pair of connections, disconnecting and possibly reattaching any existing connections,
   depending on the operation.

   - parameter connectionPair: The pair to connect
   */
  open func connectPair(_ connectionPair: ConnectionManager.ConnectionPair) {
    let moving = connectionPair.moving
    let target = connectionPair.target

    do {
      switch (moving.type) {
      case .inputValue:
        try connectValueConnections(superior: moving, inferior: target)
      case .outputValue:
        try connectValueConnections(superior: target, inferior: moving)
      case .nextStatement:
        try connectStatementConnections(superior: moving, inferior: target)
      case .previousStatement:
        try connectStatementConnections(superior: target, inferior: moving)
      }
    } catch let error {
      bky_assertionFailure("Could not connect pair together: \(error)")
    }
  }

  /**
   Disconnects a specified connection. The layout hierarchy is automatically updated to reflect this
   change.

   - parameter connection: The connection to be disconnected.
   - throws:
   `BlocklyError`: Thrown if the connection is not attached to a source block.
   */
  open func disconnect(_ connection: Connection) throws {
    guard connection.connected else {
      // Already disconnected.
      return
    }

    guard let sourceBlock = connection.sourceBlock,
      let oldTarget = connection.targetConnection,
      let targetBlock = connection.targetBlock else
    {
      throw BlocklyError(.illegalArgument,
        "Connections need to be attached to a source block prior to being disconnected.")
    }

    let inferiorBlock = connection.isInferior ? sourceBlock : targetBlock
    BlocklyEvent.Move.captureMoveEvent(workspace: workspaceLayout.workspace, block: inferiorBlock) {
      connection.disconnect()

      didChangeTarget(forConnection: connection, oldTarget: oldTarget)
      didChangeTarget(forConnection: oldTarget, oldTarget: connection)
    }
  }

  /**
   Disconnects the shadow connection for a specified connection. The layout hierarchy is
   automatically updated to reflect this change.

   - parameter connection: The connection whose shadow connection should be disconnected.
   - throws:
   `BlocklyError`: Thrown if the connection is not attached to a source block.
   */
  open func disconnectShadow(_ connection: Connection) throws {
    guard connection.shadowConnected else {
      // Shadow is not connected.
      return
    }

    guard let oldShadow = connection.shadowConnection,
      connection.sourceBlock != nil,
      connection.shadowBlock != nil else
    {
      throw BlocklyError(.illegalArgument,
        "Shadow connections need to be attached to a source block prior to being disconnected.")
    }

    connection.disconnectShadow()

    didChangeShadow(forConnection: connection, oldShadow: oldShadow)
    didChangeShadow(forConnection: oldShadow, oldShadow: connection)
  }

  /**
   Connects a pair of connections.  The layout hierarchy is automatically updated to reflect this
   change.

   - parameter connection1: The first `Connection` to be connected.
   - parameter connection2: The `Connction` to connect to.
   - throws:
   `BlocklyError`: Thrown if either connection is not attached to a source block or if the
   connections were unable to connect.
   */
  open func connect(_ connection1: Connection, _ connection2: Connection) throws {
    guard let sourceBlock1 = connection1.sourceBlock,
      let sourceBlock2 = connection2.sourceBlock else
    {
      throw BlocklyError(.illegalArgument,
        "Connections need to be attached to a source block prior to being connected.")
    }

    let inferiorBlock = connection1.isInferior ? sourceBlock1 : sourceBlock2
    try BlocklyEvent.Move.captureMoveEvent(
      workspace: workspaceLayout.workspace, block: inferiorBlock) {
      let oldTarget1 = connection1.targetConnection
      let oldTarget2 = connection2.targetConnection
      try connection1.connectTo(connection2)

      didChangeTarget(forConnection: connection1, oldTarget: oldTarget1)
      didChangeTarget(forConnection: connection2, oldTarget: oldTarget2)
    }
  }

  /**
   Re-builds the layout hierarchy for a block that is already associated with a layout.

   - parameter block: The block to rebuild its layout hierarchy.
   - throws:
   `BlocklyError`: Thrown if the specified block is not associated with a layout yet.
   */
  open func rebuildLayoutTree(forBlock block: Block) throws {
    guard block.layout != nil else {
      throw BlocklyError(.illegalState,
        "Cannot re-build layout tree for a block that's not already associated with a layout.")
    }

    // Since this method is being called, there may be some connections that no longer belong to
    // `block`. Take this time to untrack all orphaned connections from the connection manager.
    connectionManager?.untrackOrphanedConnections()

    // Rebuild the layout tree
    let blockLayout =
      try layoutBuilder.buildLayoutTree(forBlock: block, engine: workspaceLayout.engine)

    // Track this block layout
    trackBlockLayout(blockLayout)

    // Update the layout tree, in both directions
    blockLayout.updateLayoutDownTree()
    blockLayout.updateLayoutUpTree()
  }

  // MARK: - Private

  /**
   Connects two value connections. If a block was previously connected to the superior connection,
   this method attempts to reattach it to the end of the inferior connection's block input value
   chain. If unsuccessful, the disconnected block is bumped away.
   */
  fileprivate func connectValueConnections(superior: Connection, inferior: Connection) throws {
    let previouslyConnectedBlock = superior.targetBlock

    // NOTE: Layouts are automatically re-computed after disconnecting/reconnecting
    try disconnect(superior)
    try disconnect(inferior)
    try connect(superior, inferior)

    // Bring the entire block group layout to the front
    if let rootBlockGroupLayout = superior.sourceBlock?.layout?.rootBlockGroupLayout {
      workspaceLayout.bringBlockGroupLayoutToFront(rootBlockGroupLayout)
    }

    if let previousOutputConnection = previouslyConnectedBlock?.outputConnection {
      if let lastInputConnection = inferior.sourceBlock?.lastInputValueConnectionInChain()
        , lastInputConnection.canConnectTo(previousOutputConnection)
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

   - parameter superior: A connection of type `.NextStatement`
   - parameter inferior: A connection of type `.PreviousStatement`
   - throws:
   `BlocklyError`: Thrown if the previous/next statements could not be connected together or if
   the previously disconnected block could not be re-connected to the end of the block chain.
   */
  fileprivate func connectStatementConnections(superior: Connection, inferior: Connection)
    throws
  {
    let previouslyConnectedBlock = superior.targetBlock

    // NOTE: Layouts are automatically re-computed after disconnecting/reconnecting
    try disconnect(superior)
    try disconnect(inferior)
    try connect(superior, inferior)

    // Bring the entire block group layout to the front
    if let rootBlockGroupLayout = superior.sourceBlock?.layout?.rootBlockGroupLayout {
      workspaceLayout.bringBlockGroupLayoutToFront(rootBlockGroupLayout)
    }

    if let previousConnection = previouslyConnectedBlock?.previousConnection {
      if let lastConnection = inferior.sourceBlock?.lastBlockInChain().nextConnection
        , lastConnection.canConnectTo(previousConnection)
      {
        // Reconnect previously connected block to the end of the block chain
        try connect(lastConnection, previousConnection)
      } else {
        // Bump previously connected block away from the superior connection
        blockBumper.bumpBlockLayoutOfConnection(previousConnection, awayFromConnection: superior)
      }
    }
  }

  fileprivate func didChangeTarget(forConnection connection: Connection, oldTarget: Connection?) {
    do {
      try updateLayoutTree(forConnection: connection, oldTarget: oldTarget)
    } catch let error {
      bky_assertionFailure("Could not update layout tree for connection: \(error)")
    }
  }

  fileprivate func didChangeShadow(forConnection connection: Connection, oldShadow: Connection?) {
    do {
      if connection.shadowConnected && !connection.connected {
        // There's a new shadow block for the connection and it is not connected to anything.
        // Add the shadow block layout tree.
        try addShadowBlockLayoutTree(forConnection: connection)
      } else if !connection.shadowConnected {
        // There's no shadow block for the connection. Remove the shadow block layout tree.
        try removeShadowBlockLayoutTree(forShadowBlock: oldShadow?.sourceBlock)
      }
    } catch let error {
      bky_assertionFailure("Could not update shadow block layout tree for connection: \(error)")
    }
  }

  /**
   Adds shadow blocks for a given connection to the layout tree. If the shadow blocks already exist
   or if no shadow blocks are connected to the given connection, nothing happens.

   - note: This method only updates the layout tree if the given connection is of type
   `.NextStatement` or `.InputValue`. Otherwise, this method does nothing.

   - parameter connection: The connection that should have its shadow blocks added to the layout
   tree
   */
  fileprivate func addShadowBlockLayoutTree(forConnection connection: Connection?) throws {
    guard let aConnection = connection,
      let shadowBlock = aConnection.shadowBlock
      , (aConnection.type == .nextStatement || aConnection.type == .inputValue) &&
        shadowBlock.layout == nil && !aConnection.connected else
    {
      // Only next/input connectors are responsible for updating the shadow block group
      // layout hierarchy, not previous/output connectors.
      return
    }

    // Nothing is connected to aConnection. Re-create the shadow block hierarchy since it doesn't
    // exist.
    let shadowBlockGroupLayout =
      try layoutBuilder.layoutFactory.makeBlockGroupLayout(engine: workspaceLayout.engine)
    try layoutBuilder.buildLayoutTree(forBlockGroupLayout: shadowBlockGroupLayout,
                                      block: shadowBlock)
    let shadowBlockLayouts = shadowBlockGroupLayout.blockLayouts

    // Add shadow block layouts to proper block group
    if let blockGroupLayout =
      (aConnection.sourceInput?.layout?.blockGroupLayout ?? // For input values or statements
        aConnection.sourceBlock?.layout?.parentBlockGroupLayout) // For a block's next statement
    {
      // Lay out and position the shadow block group at its new parent block group's absolute
      // position. The reason for is so that the shadow block group animates more smoothly into
      // when it's adopted by its new parent block group.
      // NOTE: This still isn't perfect as it should ideally animate from the previous connector
      // location to its new connector location.
      shadowBlockGroupLayout.relativePosition.x = blockGroupLayout.absolutePosition.x
      shadowBlockGroupLayout.relativePosition.y = blockGroupLayout.absolutePosition.y
      shadowBlockGroupLayout.performLayout(includeChildren: true)
      shadowBlockGroupLayout.refreshViewPositionsForTree()

      // Add the shadow block group to the block group layout, and update all positions.
      blockGroupLayout.appendBlockLayouts(shadowBlockLayouts, updateLayout: true)
      blockGroupLayout.performLayout(includeChildren: false)
      blockGroupLayout.refreshViewPositionsForTree()
      blockGroupLayout.updateLayoutUpTree()
    }

    // Track shadow block layouts
    let allBlockLayouts = shadowBlockLayouts.flatMap {
      $0.flattenedLayoutTree(ofType: BlockLayout.self)
    }
    for blockLayout in allBlockLayouts {
      trackBlockLayout(blockLayout)
    }

    if allBlockLayouts.count > 0 {
      workspaceLayout.sendChangeEvent(withFlags: WorkspaceLayout.Flag_NeedsDisplay)
    }
  }

  /**
   Removes a shadow block layout tree from its parent layout, starting from a given shadow block.

   - parameter shadowBlock: The shadow block
   */
  fileprivate func removeShadowBlockLayoutTree(forShadowBlock shadowBlock: Block?) throws {
    guard let shadowBlockLayout = shadowBlock?.layout,
      let shadowBlockLayoutParent = shadowBlockLayout.parentBlockGroupLayout
      , (shadowBlock?.shadow ?? false) else
    {
      // There is no shadow block layout for this block.
      return
    }

    // Remove all layouts connected to this shadow block layout
    let removedLayouts = shadowBlockLayoutParent
      .removeAllBlockLayouts(startingFrom: shadowBlockLayout, updateLayout: false)
      .flatMap { $0.flattenedLayoutTree(ofType: BlockLayout.self) }

    for removedLayout in removedLayouts {
      // Remove the associated block layout
      removedLayout.block.layout = nil
      // Untrack the layout
      untrackBlockLayout(removedLayout)
    }

    if removedLayouts.count > 0 {
      workspaceLayout.sendChangeEvent(withFlags: WorkspaceLayout.Flag_NeedsDisplay)
    }
  }

  /**
   Whenever a connection has been changed for a block in the workspace, this method is called to
   ensure that the layout tree is properly kept in sync to reflect this change.

   - note: This method only updates the layout tree if the given connection is of type
   `.PreviousStatement` or `.OutputValue`. Otherwise, this method does nothing.

   - parameter connection: The connection that changed
   - parameter oldTarget: The previous value of `connection.targetConnection`
   */
  fileprivate func updateLayoutTree(forConnection connection: Connection, oldTarget: Connection?)
    throws
  {
    // TODO(#29): Optimize re-rendering all layouts affected by this method

    guard connection.type == .previousStatement || connection.type == .outputValue else {
      // Only previous/output connectors are responsible for updating the block group
      // layout hierarchy, not next/input connectors.
      return
    }

    // Check that there are layouts for both the source and target blocks of this connection
    guard let sourceBlock = connection.sourceBlock,
      let sourceBlockLayout = sourceBlock.layout
      , connection.targetConnection?.sourceInput == nil ||
        connection.targetConnection?.sourceInput?.layout != nil ||
        connection.targetConnection?.sourceBlock == nil ||
        connection.targetConnection?.sourceBlock?.layout != nil
      else
    {
      throw BlocklyError(.illegalState, "Can't connect a block without a layout. ")
    }

    // Check that this layout is connected to a block group layout
    guard sourceBlock.layout?.parentBlockGroupLayout != nil else {
      throw BlocklyError(.illegalState,
                         "Block layout is not connected to a parent block group layout. ")
    }

    let workspace = workspaceLayout.workspace

    guard (connection.targetBlock == nil || workspace.containsBlock(connection.targetBlock!)) &&
      workspace.containsBlock(sourceBlock) else
    {
      throw BlocklyError(.illegalState, "Can't connect blocks from different workspaces")
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
          .claimWithFollowers(blockLayout: sourceBlockLayout, updateLayouts: true)
      } else if let targetBlockLayout = targetConnection.sourceBlock?.layout {
        // Move them to the target block's group layout
        targetBlockLayout.parentBlockGroupLayout?
          .claimWithFollowers(blockLayout: sourceBlockLayout, updateLayouts: true)
      }
    } else {
      // The connection is no longer connected to anything.

      // Block was disconnected and added to the workspace level.
      // Create a new block group layout and set its `relativePosition` to the current absolute
      // position of the block that was disconnected
      let layoutFactory = layoutBuilder.layoutFactory
      let blockGroupLayout =
        try layoutFactory.makeBlockGroupLayout(engine: workspaceLayout.engine)
      blockGroupLayout.relativePosition = sourceBlockLayout.absolutePosition

      Layout.doNotAnimate {
        // Add this new block group layout to the workspace level
        self.workspaceLayout.appendBlockGroupLayout(blockGroupLayout, updateLayout: true)
        self.workspaceLayout.bringBlockGroupLayoutToFront(blockGroupLayout)
      }

      blockGroupLayout.claimWithFollowers(blockLayout: sourceBlockLayout, updateLayouts: true)
    }

    // Re-create the shadow block layout tree for the previous connection target (if it has one).
    try addShadowBlockLayoutTree(forConnection: oldTarget)

    // If the previous block group layout parent of `sourceBlockLayout` is now empty and is at the
    // the top-level of the workspace, remove it
    if let emptyBlockGroupLayout = oldParentLayout
      , emptyBlockGroupLayout.blockLayouts.count == 0 &&
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
   Tracks the connections for a given block layout under `self.connectionManager` and associates
   itself with any sub-layouts that need a reference to this layout coordinator.

   - parameter blockLayout: The `BlockLayout` that should be tracked.
   */
  fileprivate func trackBlockLayout(_ blockLayout: BlockLayout) {
    // If the block layout is visible, track positional changes for each connection in the
    // connection manager
    if let connectionManager = self.connectionManager, blockLayout.visible {
      for connection in blockLayout.block.directConnections {
        connectionManager.trackConnection(connection)
      }
    }

    addNameManager(variableNameManager, toBlockLayout: blockLayout)

    addLayoutCoordinator(toBlockLayout: blockLayout)
  }

  /**
   Untracks connections for a given block layout under `self.connectionManager` and disassociates
   itself from any sub-layouts that referenced this layout coordinator.

   - parameter blockLayout: The `BlockLayout` whose connections should be untracked.
   */
  fileprivate func untrackBlockLayout(_ blockLayout: BlockLayout) {
    // Untrack positional changes for each connection in the connection manager
    if let connectionManager = self.connectionManager {
      for connection in blockLayout.block.directConnections {
        connectionManager.untrackConnection(connection)
      }
    }

    removeNameManager(fromBlockLayout: blockLayout)

    removeLayoutCoordinator(fromBlockLayout: blockLayout)
  }

  /**
   For all `FieldVariableLayout` instances under a given `BlockLayout`, set their `nameManager`
   property to a given `NameManager`.

   - parameter nameManager: The `NameManager` to set
   - parameter blockLayout: The `BlockLayout`
   */
  fileprivate func addNameManager(_ nameManager: NameManager?,
                                  toBlockLayout blockLayout: BlockLayout) {
    blockLayout.inputLayouts.forEach {
      $0.fieldLayouts.forEach {
        if let fieldVariableLayout = $0 as? FieldVariableLayout {
          fieldVariableLayout.nameManager = nameManager
        }
      }
    }
  }

  /**
   Sets the `nameManager` for all `FieldVariableLayout` instances under the given `BlockLayout` to
   `nil`.

   - parameter blockLayout: The `BlockLayout`
   */
  fileprivate func removeNameManager(fromBlockLayout blockLayout: BlockLayout) {
    blockLayout.inputLayouts.forEach {
      $0.fieldLayouts.forEach {
        if let fieldVariableLayout = $0 as? FieldVariableLayout {
          fieldVariableLayout.nameManager = nil
        }
      }
    }
  }

  private func addLayoutCoordinator(toBlockLayout blockLayout: BlockLayout) {
    // Add associations for sub-layouts
    for layout in blockLayout.flattenedLayoutTree() {
      if let variableLayout = layout as? FieldVariableLayout {
        variableLayout.layoutCoordinator = self
      } else if let mutatorLayout = layout as? MutatorLayout {
        mutatorLayout.layoutCoordinator = self
      }
    }
  }

  private func removeLayoutCoordinator(fromBlockLayout blockLayout: BlockLayout) {
    // Remove associations for sub-layouts
    for layout in blockLayout.flattenedLayoutTree() {
      if let variableLayout = layout as? FieldVariableLayout {
        variableLayout.layoutCoordinator = nil
      } else if let mutatorLayout = layout as? MutatorLayout {
        mutatorLayout.layoutCoordinator = nil
      }
    }
  }
}

// MARK: - WorkspaceListener implementation

extension WorkspaceLayoutCoordinator: WorkspaceListener {
  public func workspace(_ workspace: Workspace, didAddBlockTrees blockTrees: [Block]) {
    for block in blockTrees {
      do {
        // Fire creation event for the root block
        let event = try BlocklyEvent.Create(workspace: workspaceLayout.workspace, block: block)
        EventManager.shared.addPendingEvent(event)

        // Create the layout tree for this newly added block
        let blockGroupLayout =
          try layoutBuilder.buildLayoutTree(forTopLevelBlock: block,
                                            workspaceLayout: workspaceLayout)

        // Perform a layout for the tree
        blockGroupLayout.updateLayoutDownTree()

        // Track all block layouts
        for blockLayout in blockGroupLayout.flattenedLayoutTree(ofType: BlockLayout.self) {
          trackBlockLayout(blockLayout)
        }

        // Update the content size
        workspaceLayout.updateCanvasSize()

        // Schedule change event for an added block layout
        workspaceLayout.sendChangeEvent(withFlags: WorkspaceLayout.Flag_NeedsDisplay)
      } catch let error {
        bky_assertionFailure("Could not create the layout tree for block: \(error)")
      }
    }
  }

  public func workspace(_ workspace: Workspace, didRemoveBlockTrees blockTrees: [Block]) {
    for block in blockTrees {
      do {
        // Fire delete event for the root block
        let event = try BlocklyEvent.Delete(workspace: workspaceLayout.workspace, block: block)
        EventManager.shared.addPendingEvent(event)
      } catch let error {
        bky_assertionFailure("Could not fire delete event: \(error)")
      }

      if let blockGroupLayout = block.layout?.parentBlockGroupLayout {
        // Untrack all block layouts
        for blockLayout in blockGroupLayout.flattenedLayoutTree(ofType: BlockLayout.self) {
          untrackBlockLayout(blockLayout)
        }

        workspaceLayout.removeBlockGroupLayout(blockGroupLayout)

        workspaceLayout.sendChangeEvent(withFlags: WorkspaceLayout.Flag_NeedsDisplay)
      }
    }
  }
}

// MARK: - NameManagerListener Implementation

extension WorkspaceLayoutCoordinator: NameManagerListener {
  public func nameManager(_ nameManager: NameManager, didRemoveName name: String) {
    let blocks = workspaceLayout.workspace.allVariableBlocks(forName: name)
    // Don't do anything to toolbox/trash workspaces.
    if workspaceLayout.workspace.workspaceType != .interactive {
      return
    }

    // Remove each block with matching variable fields.
    for block in blocks {
      do {
        try removeSingleBlock(block)
      } catch let error {
        bky_assertionFailure("Couldn't remove block: \(error)")
      }
    }
  }
}
