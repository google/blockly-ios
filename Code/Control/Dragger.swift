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
  private typealias ConnectionPair =
    (moving: Connection, target: Connection, fromConnectionManagerGroup: ConnectionManager.Group)

  // MARK: - Static Properties

  /**
  Blocks "snap" toward each other at the end of drags if they have compatible connections
  near each other.  This is the farthest they can snap. This value is in the UIView coordinate
  system.
  */
  private static let MAX_SNAP_DISTANCE: CGFloat = 25

  // MARK: - Properties

  /// Stores the data for each active drag gesture, keyed by the corresponding block view's layout
  /// uuid
  private var _dragGestureData = [String: DragGestureData]()

  // MARK: - Public

  /**
  Disconnect the given block layout from any superior connections and start dragging it (and any of
  its connected block layouts) in the workspace.

  - Parameter layout: The given block layout
  - Parameter touchPosition: The initial touch position, specified in the Workspace coordinate
  system
  */
  public func startDraggingBlockLayout(layout: BlockLayout, touchPosition: WorkspacePoint) {
    // Remove any existing gesture data for the layout
    clearGestureDataForBlockLayout(layout)

    // Disconnect this block from its previous or output connections prior to moving it
    let block = layout.block
    block.previousConnection?.disconnect()
    block.outputConnection?.disconnect()

    // Highlight this block
    layout.highlighted = true

    // Keep track of the gesture data for this drag
    let newConnectionGroup = layout.workspaceLayout.connectionManager.createGroup()
    let dragGestureData = DragGestureData(
      blockLayout: layout,
      blockLayoutStartPosition: layout.absolutePosition,
      touchStartPosition: touchPosition,
      connectionGroup: newConnectionGroup
    )

    // Change the connection group for all affected connections to the new one created
    // for the drag gesture
    let childConnections = block.allConnectionsForTree()
    for connection in childConnections {
      layout.workspaceLayout.connectionManager
        .trackConnection(connection, assignToGroup: newConnectionGroup)
    }

    _dragGestureData[layout.uuid] = dragGestureData
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

    // Make sure the connection manager group is in "drag mode" to avoid wasting compute cycles
    // during the drag
    gestureData.connectionGroup.dragMode = true

    // Move the block view based on the new touch position
    layout.parentBlockGroupLayout?.moveToWorkspacePosition(
      gestureData.blockLayoutStartPosition + (touchPosition - gestureData.touchStartPosition))

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
    // Remove the highlight for this block
    layout.highlighted = false

    // If this block can be connected to anything, connect it.
    if let drag = _dragGestureData[layout.uuid],
      let connectionPair = findBestConnectionForDrag(drag) {
        connectPair(connectionPair)
        clearGestureDataForBlockLayout(layout,
          moveConnectionsToGroup: connectionPair.fromConnectionManagerGroup)
    } else {
      clearGestureDataForBlockLayout(layout)
    }

    // Update the highlighted connections for all other drags (due to potential changes in block
    // sizes)
    for (_, gestureData) in _dragGestureData {
      updateHighlightedConnectionForDrag(gestureData)
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
    layout: BlockLayout, moveConnectionsToGroup group: ConnectionManager.Group? = nil) {
      guard let gestureData = _dragGestureData[layout.uuid] else {
        return
      }

      let newGroup = (group ?? layout.workspaceLayout.connectionManager.mainGroup)

      // Move connections to a different group in the connection manager
      layout.workspaceLayout.connectionManager.moveConnectionsFromGroup(
        gestureData.connectionGroup, toGroup: newGroup)

      // Delete the group
      do {
        try layout.workspaceLayout.connectionManager.deleteGroup(gestureData.connectionGroup)
      } catch let error as NSError {
        bky_assertionFailure("Could not delete drag's connection group: \(error)")
      }

      removeHighlightedConnectionForDrag(gestureData)
      _dragGestureData[layout.uuid] = nil
  }

  // MARK: - Private

  /**
  Iterate over all direct connections on the block and find the one that is closest to a
  valid connection on another block.

  - Parameter layout: The block layout whose connections to search
  - Returns: A connection pair where the `pair.moving` connection is one on the given block and the
  `pair.target` connection is the closest compatible connection. Nil is returned if no suitable
  connection pair could be found.
  */
  private func findBestConnectionForDrag(drag: DragGestureData) -> ConnectionPair? {
    // Find the connection that is closest to any connection on the block.
    let workspaceLayout = drag.blockLayout.workspaceLayout
    var candidate: ConnectionPair?
    var maxRadius = workspaceLayout.workspaceUnitFromViewUnit(Dragger.MAX_SNAP_DISTANCE)

    for draggedBlockConnection in drag.blockLayout.block.directConnections {
      if let compatibleConnection = workspaceLayout.connectionManager
        .closestConnection(draggedBlockConnection, maxRadius: maxRadius)
      {
        candidate = (
          moving: draggedBlockConnection,
          target: compatibleConnection.0,
          fromConnectionManagerGroup: compatibleConnection.1)
        maxRadius = draggedBlockConnection.distanceFromConnection(compatibleConnection.0)
      }
    }

    return candidate
  }

  /**
  Connects a pair of connections, disconnecting and possibly reattaching any existing connections,
  depending on the operation.

  - Parameter connectionPair: The pair to connect
  */
  private func connectPair(connectionPair: ConnectionPair) {
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

    if previouslyConnectedBlock != nil {
      // Try to reconnect previously connected block to the end of the input value chain
      if let lastInputConnection = inferior.sourceBlock?.lastInputValueConnectionInChain(),
        previousOutputConnection = previouslyConnectedBlock!.outputConnection {
          if lastInputConnection.canConnectTo(previousOutputConnection) {
            try lastInputConnection.connectTo(previousOutputConnection)
            return
          }
      }

      // TODO:(vicng) Bump previouslyConnectedBlock
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
    throws {
      let previouslyConnectedBlock = superior.targetBlock

      // NOTE: Layouts are automatically re-computed after disconnecting/reconnecting
      superior.disconnect()
      inferior.disconnect()
      try superior.connectTo(inferior)

      if previouslyConnectedBlock != nil {
        // Reconnect previously connected block to the end of the block chain
        if let lastConnection = inferior.sourceBlock?.lastBlockInChain().nextConnection {
          try lastConnection.connectTo(previouslyConnectedBlock!.previousConnection!)
        } else {
          // TODO:(vicng) Bump previouslyConnectedBlock
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
      if let newHighlightedConnection = connectionPair?.target {
        newHighlightedConnection.addHighlightForBlock(drag.blockLayout.block)
        drag.highlightedConnection = newHighlightedConnection
      }
    }
  }

  /**
  Removes the highlighted connection for a drag.

  - Parameter drag: The drag.
  */
  private func removeHighlightedConnectionForDrag(drag: DragGestureData) {
    drag.highlightedConnection?.removeHighlightForBlock(drag.blockLayout.block)
    drag.highlightedConnection = nil
  }
}

/**
Stores relevant data for the lifetime of a single drag.
*/
private class DragGestureData {
  /// The block layout that is being dragged
  private unowned let blockLayout: BlockLayout

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
