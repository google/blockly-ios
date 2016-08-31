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
Controller for dragging blocks around in the workspace.
*/
@objc(BKYDragger)
public class Dragger: NSObject {
  // MARK: - Static Properties

  /**
  Blocks "snap" toward each other at the end of drags if they have compatible connections
  near each other.  This is the farthest they can snap. This value is in the UIView coordinate
  system.
  */
  private static let MAX_SNAP_DISTANCE: CGFloat = 25

  // MARK: - Properties

  /// The workspace layout where blocks are being dragged
  public var workspaceLayout: WorkspaceLayout? {
    didSet {
      if workspaceLayout == oldValue {
        return
      }

      // Reset all gesture data and update the block bumper with the new workspace layout
      _dragGestureData.keys.forEach { clearGestureData(forUUID: $0) }
      _blockBumper.workspaceLayout = workspaceLayout
    }
  }
  /// Stores the data for each active drag gesture, keyed by the corresponding block view's layout
  /// uuid
  private var _dragGestureData = [String: DragGestureData]()
  /// Object responsible for bumping blocks out of the way
  private let _blockBumper = BlockBumper(bumpDistance: Dragger.MAX_SNAP_DISTANCE)

  // MARK: - Public

  /**
  Disconnect the given block layout from any superior connections and start dragging it (and any of
  its connected block layouts) in the workspace.

  - Parameter layout: The given block layout
  - Parameter touchPosition: The initial touch position, specified in the Workspace coordinate
  system
  */
  public func startDraggingBlockLayout(layout: BlockLayout, touchPosition: WorkspacePoint) {
    if !layout.block.draggable {
      return
    }

    Layout.animate {
      // Remove any existing gesture data for the layout
      self.clearGestureDataForBlockLayout(layout)

      // Disconnect this block from its previous or output connections prior to moving it
      let block = layout.block
      block.previousConnection?.disconnect()
      block.outputConnection?.disconnect()

      // Highlight this block
      layout.highlighted = true
      layout.rootBlockGroupLayout?.dragging = true

      // Bring its block group layout to the front
      self.workspaceLayout?.bringBlockGroupLayoutToFront(layout.rootBlockGroupLayout)

      // Start a new connection group for this block group layout
      if let newConnectionGroup =
        self.workspaceLayout?.connectionManager.startGroupForBlock(block)
      {
        // Keep track of the gesture data for this drag
        let dragGestureData = DragGestureData(
          blockLayout: layout,
          blockLayoutStartPosition: layout.absolutePosition,
          touchStartPosition: touchPosition,
          connectionGroup: newConnectionGroup
        )

        self._dragGestureData[layout.uuid] = dragGestureData
      }
    }
  }

  /**
  Continue dragging a block layout (and any of its connected block layouts) in the workspace.

  - Parameter layout: The given block layout
  - Parameter touchPosition: The current touch position, specified in the Workspace coordinate
  system
  */
  public func continueDraggingBlockLayout(layout: BlockLayout, touchPosition: WorkspacePoint) {
    guard let gestureData = _dragGestureData[layout.uuid] else {
      return
    }

    // Set the connection manager group to "drag mode" to avoid wasting compute cycles during the
    // drag
    gestureData.connectionGroup.dragMode = true

    // Figure out the new workspace position based on the touch position
    let position = gestureData.blockLayoutStartPosition +
      (touchPosition - gestureData.touchStartPosition)

    // Move to the new position (only update the canvas size at the very end of the drag)
    layout.parentBlockGroupLayout?.moveToWorkspacePosition(position, updateCanvasSize: false)

    // Update the highlighted connection for this drag
    updateHighlightedConnectionForDrag(gestureData)

    // Now that the drag is complete, unset the flag
    gestureData.connectionGroup.dragMode = false
  }

  /**
  Finish dragging a block layout (and any of its connected block layouts) in the workspace.

  - Parameter layout: The given block layout
  */
  public func finishDraggingBlockLayout(layout: BlockLayout) {
    Layout.animate {
      // Remove the highlight for this block
      layout.highlighted = false
      layout.rootBlockGroupLayout?.dragging = false

      // If this block can be connected to anything, connect it.
      if let drag = self._dragGestureData[layout.uuid],
        let connectionPair = self.findBestConnectionForDrag(drag)
      {
        self.connectPair(connectionPair)

        self.clearGestureDataForBlockLayout(layout,
          moveConnectionsToGroup: connectionPair.fromConnectionManagerGroup)
      } else {
        self.clearGestureDataForBlockLayout(layout)

        // Update the workspace canvas size since it may have changed (this was purposely skipped
        // during the drag for performance reasons, so we have to update it now). Also, there is
        // no need to call this method in the `if` part of this `if/else` block, since
        // `self.connectPair(:)` implicitly calls it already.
        self.workspaceLayout?.updateCanvasSize()
      }

      // Bump any neighbours of the block layout
      self._blockBumper.bumpNeighboursOfBlockLayout(layout)

      // Update the highlighted connections for all other drags (due to potential changes in block
      // sizes)
      for (_, gestureData) in self._dragGestureData {
        self.updateHighlightedConnectionForDrag(gestureData)
      }
    }
  }

  /**
  Clears the drag data for a block layout, removes any highlights, and moves connections that were
  being tracked by the drag to a new group.

  - Parameter layout: The given block layout
  - Parameter connectionGroup: The new connection group to move the connections to. If this is
  nil, the connection manager's `mainGroup` is used.
  */
  public func clearGestureDataForBlockLayout(
    layout: BlockLayout, moveConnectionsToGroup group: ConnectionManager.Group? = nil)
  {
    clearGestureData(forUUID: layout.uuid, moveConnectionsToGroup: group)
  }

  // MARK: - Private

  /**
   Clears the drag data for a block layout's UUID, removes any highlights, and moves connections
   that were being tracked by the drag to a new group.

   - Parameter uuid: The given block layout's UUID
   - Parameter connectionGroup: The new connection group to move the connections to. If this is
   nil, the connection manager's `mainGroup` is used.
   */
  private func clearGestureData(
    forUUID uuid: String, moveConnectionsToGroup group: ConnectionManager.Group? = nil)
  {
    guard let gestureData = _dragGestureData[uuid] else {
      return
    }

    // Move connections to a different group in the connection manager
    workspaceLayout?.connectionManager
      .mergeGroup(gestureData.connectionGroup, intoGroup: group)

    removeHighlightedConnectionForDrag(gestureData)
    _dragGestureData[uuid] = nil
  }

  /**
  Connects a pair of connections, disconnecting and possibly reattaching any existing connections,
  depending on the operation.

  - Parameter connectionPair: The pair to connect
  */
  private func connectPair(connectionPair: ConnectionManager.ConnectionPair) {
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

  /**
  Connects two value connections. If a block was previously connected to the superior connection,
  this method attempts to reattach it to the end of the inferior connection's block input value
  chain. If unsuccessful, the disconnected block is bumped away.
  */
  private func connectValueConnections(superior superior: Connection, inferior: Connection) throws {
    let previouslyConnectedBlock = superior.targetBlock

    // NOTE: Layouts are automatically re-computed after disconnecting/reconnecting
    superior.disconnect()
    inferior.disconnect()
    try superior.connectTo(inferior)

    // Bring the entire block group layout to the front
    if let workspaceLayout = self.workspaceLayout,
      let rootBlockGroupLayout = superior.sourceBlock?.layout?.rootBlockGroupLayout
    {
      workspaceLayout.bringBlockGroupLayoutToFront(rootBlockGroupLayout)
    }

    if let previousOutputConnection = previouslyConnectedBlock?.outputConnection {
      if let lastInputConnection = inferior.sourceBlock?.lastInputValueConnectionInChain()
        where lastInputConnection.canConnectTo(previousOutputConnection)
      {
        // Try to reconnect previously connected block to the end of the input value chain
        try lastInputConnection.connectTo(previousOutputConnection)
      } else {
        // Bump previously connected block away from the superior connection
        _blockBumper.bumpBlockLayoutOfConnection(previousOutputConnection,
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
    superior.disconnect()
    inferior.disconnect()
    try superior.connectTo(inferior)

    // Bring the entire block group layout to the front
    if let workspaceLayout = self.workspaceLayout,
      let rootBlockGroupLayout = superior.sourceBlock?.layout?.rootBlockGroupLayout
    {
      workspaceLayout.bringBlockGroupLayoutToFront(rootBlockGroupLayout)
    }

    if let previousConnection = previouslyConnectedBlock?.previousConnection {
      if let lastConnection = inferior.sourceBlock?.lastBlockInChain().nextConnection
        where lastConnection.canConnectTo(previousConnection)
      {
        // Reconnect previously connected block to the end of the block chain
        try lastConnection.connectTo(previousConnection)
      } else {
        // Bump previously connected block away from the superior connection
        _blockBumper.bumpBlockLayoutOfConnection(previousConnection, awayFromConnection: superior)
      }
    }
  }

  /**
  Updates the highlighted connection for a dragged block.

  - Parameter drag: The `DragGestureData` that is being tracked for the block.
  */
  private func updateHighlightedConnectionForDrag(drag: DragGestureData) {
    let connectionPair = findBestConnectionForDrag(drag)
    if connectionPair?.target != drag.highlightedConnection {
      // The highlight has changed, remove the old highlight
      removeHighlightedConnectionForDrag(drag)

      // Add the new highlight (if something was found)
      if let blockLayout = drag.blockLayout,
        let newHighlightedConnection = connectionPair?.target
      {
        newHighlightedConnection.addHighlightForBlock(blockLayout.block)
        drag.highlightedConnection = newHighlightedConnection
      }
    }
  }

  /**
  Removes the highlighted connection for a drag.

  - Parameter drag: The drag.
  */
  private func removeHighlightedConnectionForDrag(drag: DragGestureData) {
    if let blockLayout = drag.blockLayout {
      drag.highlightedConnection?.removeHighlightForBlock(blockLayout.block)
      drag.highlightedConnection = nil
    }
  }

  /**
  Returns the most suitable connection pair for a given drag, if one exists.
  */
  private func findBestConnectionForDrag(drag: DragGestureData)
    -> ConnectionManager.ConnectionPair?
  {
    if let workspaceLayout = self.workspaceLayout {
      let maxRadius = workspaceLayout.engine.workspaceUnitFromViewUnit(Dragger.MAX_SNAP_DISTANCE)

      return workspaceLayout.connectionManager.findBestConnectionForGroup(drag.connectionGroup,
        maxRadius: maxRadius)
    }
    return nil
  }
}

/**
Stores relevant data for the lifetime of a single drag.
*/
private class DragGestureData {
  /// The block layout that is being dragged
  private weak var blockLayout: BlockLayout?

  /// Stores the block layout's starting position when the drag began, in Workspace coordinates
  private let blockLayoutStartPosition: WorkspacePoint

  /// Stores the starting touch position when the drag began, in Workspace coordinates
  private let touchStartPosition: WorkspacePoint

  /// Group of connections from the connection manager at the beginning of the pan gesture.
  private let connectionGroup: ConnectionManager.Group

  /// Stores the current connection that is being highlighted because of this drag gesture
  private weak var highlightedConnection: Connection?

  // MARK: - Initializers

  private init(blockLayout: BlockLayout, blockLayoutStartPosition: WorkspacePoint,
    touchStartPosition: WorkspacePoint, connectionGroup: ConnectionManager.Group) {
      self.blockLayout = blockLayout
      self.blockLayoutStartPosition = blockLayoutStartPosition
      self.touchStartPosition = touchStartPosition
      self.connectionGroup = connectionGroup
  }
}
