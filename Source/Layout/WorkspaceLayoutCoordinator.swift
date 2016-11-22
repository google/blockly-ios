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
open class WorkspaceLayoutCoordinator: NSObject {
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
  public var variableNameManager: NameManager? = NameManager() {
    didSet {
      if variableNameManager == oldValue {
        return
      }

      oldValue?.listeners.remove(self)

      self.workspaceLayout.blockGroupLayouts.forEach {
        $0.blockLayouts.forEach { removeNameManagerFromBlockLayout($0) }
      }
      self.workspaceLayout.blockGroupLayouts.forEach {
        $0.blockLayouts.forEach { addNameManager(variableNameManager, toBlockLayout: $0) }
      }

      variableNameManager?.listeners.add(self)
    }
  }

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

    // Immediately start tracking connections of all visible blocks in the workspace
    for blockLayout in workspaceLayout.allVisibleBlockLayoutsInWorkspace() {
      trackConnections(forBlockLayout: blockLayout)
    }

    variableNameManager?.listeners.add(self)
  }

  deinit {
    workspaceLayout.workspace.listeners.remove(self)
    if let nameManager = variableNameManager {
      nameManager.listeners.remove(self)
    }
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
    return try workspaceLayout.workspace.addBlockTree(rootBlock)
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
      disconnect(previousConnection)
    }
    if let outputConnection = rootBlock.outputConnection {
      disconnect(outputConnection)
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
      disconnect(previousConnection)
    }

    // Disconnect the next connection. If both next and previous were connected, reconnect the
    // next block with the old previous block.
    if let nextConnection = block.nextConnection {
      let oldInferior = nextConnection.targetConnection
      disconnect(nextConnection)
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
        disconnect(connection)
      }
    }

    try workspaceLayout.workspace.removeBlockTree(block)
  }

  /**
   Deep copies a block and adds all of the copied blocks into the workspace.

   - parameter rootBlock: The root block to copy
   - parameter editable: Sets whether each block is `editable` or not
   - returns: The root block that was copied
   - throws:
   `BlocklyError`: Thrown if the block could not be copied
   */
  open func copyBlockTree(_ rootBlock: Block, editable: Bool) throws -> Block {
    return try workspaceLayout.workspace.copyBlockTree(rootBlock, editable: editable)
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
   Disconnects a specified connection. The layout heirarchy is automatically updated to reflect this
   change.

   - parameter connection: The connection to be disconnected.
   */
  open func disconnect(_ connection: Connection) {
    let oldTarget = connection.targetConnection
    connection.disconnect()

    didChangeTarget(forConnection: connection, oldTarget: oldTarget)
    if let oldTarget = oldTarget {
      didChangeTarget(forConnection: oldTarget, oldTarget: connection)
    }
  }


  /**
   Connects a pair of connections.  The layout heirarchy is automatically updated to reflect this
   change.

   - parameter connection1: The first `Connection` to be connected.
   - parameter connection2: The `Connction` to connect to.
   */
  open func connect(_ connection1: Connection, _ connection2: Connection) throws {
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
  fileprivate func connectValueConnections(superior: Connection, inferior: Connection) throws {
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
    disconnect(superior)
    disconnect(inferior)
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

  fileprivate func didChangeTarget(forConnection connection: Connection, oldTarget: Connection?)
  {
    do {
      try updateLayoutTree(forConnection: connection, oldTarget: oldTarget)
    } catch let error {
      bky_assertionFailure("Could not update layout tree for connection: \(error)")
    }
  }

  fileprivate func didChangeShadow(forConnection connection: Connection, oldShadow: Connection?)
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
      // Set the delegate of the block to nil (effectively removing its BlockLayout)
      removedLayout.block.delegate = nil
      // Untrack connections for the layout
      untrackConnections(forBlockLayout: removedLayout)
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
    // TODO:(#29) Optimize re-rendering all layouts affected by this method

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
      } else if let targetBlockLayout = targetConnection.sourceBlock.layout {
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
   Tracks connections for a given block layout under `self.connectionManager`.
   If `self.connectionManager is nil, nothing happens.

   - parameter blockLayout: The `BlockLayout` whose connections should be tracked.
   */
  fileprivate func trackConnections(forBlockLayout blockLayout: BlockLayout) {
    guard let connectionManager = self.connectionManager
     , blockLayout.visible else
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

   - parameter blockLayout: The `BlockLayout` whose connections should be untracked.
   */
  fileprivate func untrackConnections(forBlockLayout blockLayout: BlockLayout) {
    guard let connectionManager = self.connectionManager else {
      return
    }

    // Untrack positional changes for each connection in the connection manager
    for connection in blockLayout.block.directConnections {
      connectionManager.untrackConnection(connection)
    }
  }

  /**
   For all `FieldVariable` instances under a given `Block`, set their `nameManager` property to a
   given `NameManager`.

   - parameter nameManager: The `NameManager` to set
   - parameter block: The `Block`
   */
  fileprivate func addNameManager(_ nameManager: NameManager?,
                                  toBlockLayout blockLayout: BlockLayout) {
    blockLayout.inputLayouts.forEach { $0.fieldLayouts.forEach {
      if let fieldVariableLayout = $0 as? FieldVariableLayout {
        fieldVariableLayout.nameManager = nameManager
      }
    }}
  }

  /**
   Sets the `nameManager` for all `FieldVariable` instances under the given `Block` to `nil`.

   - parameter block: The `Block`
   */
  fileprivate func removeNameManagerFromBlockLayout(_ blockLayout: BlockLayout) {
    blockLayout.inputLayouts.forEach { $0.fieldLayouts.forEach {
      if let fieldVariableLayout = $0 as? FieldVariableLayout {
        fieldVariableLayout.nameManager = nil
      }
    }}
  }
}

// MARK: - WorkspaceListener implementation

extension WorkspaceLayoutCoordinator: WorkspaceListener {
  public func workspace(_ workspace: Workspace, didAddBlock block: Block) {
    if !block.topLevel {
      // We only need to create layout trees for top level blocks
      return
    }

    do {
      // Create the layout tree for this newly added block
      if let blockGroupLayout =
        try layoutBuilder.buildLayoutTree(forTopLevelBlock: block, workspaceLayout: workspaceLayout)
      {
        // Perform a layout for the tree
        blockGroupLayout.updateLayoutDownTree()

        // Track connections of all new block layouts that were added
        for blockLayout in blockGroupLayout.flattenedLayoutTree(ofType: BlockLayout.self) {
          trackConnections(forBlockLayout: blockLayout)
          addNameManager(variableNameManager, toBlockLayout: blockLayout)
        }

        // Update the content size
        workspaceLayout.updateCanvasSize()

        // Schedule change event for an added block layout
        workspaceLayout.sendChangeEvent(withFlags: WorkspaceLayout.Flag_NeedsDisplay)
      }
    } catch let error {
      bky_assertionFailure("Could not create the layout tree for block: \(error)")
    }
  }

  public func workspace(_ workspace: Workspace, willRemoveBlock block: Block) {
    if let layout = block.layout {
      removeNameManagerFromBlockLayout(layout)
    }

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

      workspaceLayout.sendChangeEvent(withFlags: WorkspaceLayout.Flag_NeedsDisplay)
    }
  }
}

// MARK: - NameManagerListener Implementation

extension WorkspaceLayoutCoordinator: NameManagerListener {
  public func nameManager(_ nameManager: NameManager, didRemoveName name: String) {
    let blocks = workspaceLayout.workspace.allVariableBlocks(forName: name)

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
