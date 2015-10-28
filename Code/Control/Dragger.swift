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
  private typealias ConnectionPair = (moving: Connection, target: Connection)

  // MARK: - Static Properties

  /**
  Blocks "snap" toward each other at the end of drags if they have compatible connections
  near each other.  This is the farthest they can snap. This value is in the UIView coordinate
  system.
  */
  private static let MAX_SNAP_DISTANCE: CGFloat = 25

  // MARK: - Properties

  /// The workspace view that owns this dragger
  private unowned var _workspaceView: WorkspaceView

  /// Stores the data for each active drag gesture, keyed by the corresponding block view's layout
  /// uuid
  private var _dragGestureData = [String: DragGestureData]()

  // MARK: - Initializers

  public init(workspaceView: WorkspaceView) {
    _workspaceView = workspaceView
  }

  // MARK: - Public

  /**
  Disconnect the given block view from any superior connections and start dragging a block view
  (and any of its connected blocks) in the workspace.

  - Parameter blockView: The given block view
  - Parameter gesture: The gesture that recognized the drag
  */
  public func startDraggingBlock(blockView: BlockView, gesture: UIPanGestureRecognizer) {
    guard let layout = blockView.layout,
      block = blockView.blockLayout?.block else {
        return
    }

    // Store the start position of the block view and first touch point
    let touchStartPosition =
    layout.workspaceLayout.workspacePointFromViewPoint(gesture.locationInView(_workspaceView))
    let dragGestureData = DragGestureData(
      blockViewStartPosition: layout.absolutePosition, touchStartPosition: touchStartPosition)

    // Disconnect this block from its previous or output connections prior to moving it
    block.previousConnection?.disconnect()
    block.outputConnection?.disconnect()

    // For any connections that are being dragged around, set their drag mode to true and
    // remove them from the connection manager
    // TODO:(vicng) Handle dragging multiple blocks around at the same time.
    dragGestureData.childConnections = block.allConnectionsForTree()
    for connection in dragGestureData.childConnections {
      layout.workspaceLayout.connectionManager.removeConnection(connection)
      connection.dragMode = true
    }

    _dragGestureData[layout.uuid] = dragGestureData
  }

  /**
  Continue dragging a block view (and any of its connected blocks) in the workspace.

  - Parameter blockView: The given block view
  - Parameter gesture: The gesture that recognized the drag.
  */
  public func continueDraggingBlock(blockView: BlockView, gesture: UIPanGestureRecognizer) {
    guard let layout = blockView.layout,
      gestureData = _dragGestureData[layout.uuid] else {
        return
    }

    // TODO:(vicng) Double check that this works correctly when the workspace layout is at different
    // a scale

    // Move the block view based on the gesture pan movement
    let touchPosition =
    layout.workspaceLayout.workspacePointFromViewPoint(gesture.locationInView(_workspaceView))

    blockView.blockLayout?.parentBlockGroupLayout?.moveToWorkspacePosition(
      gestureData.blockViewStartPosition + (touchPosition - gestureData.touchStartPosition))

    // TODO:(vicng) Highlight connection candidates
  }

  /**
  Finish dragging a block view (and any of its connected blocks) in the workspace.

  - Parameter blockView: The given block view
  - Parameter gesture: The gesture that recognized the drag.
  */
  public func finishDraggingBlock(blockView: BlockView, gesture: UIPanGestureRecognizer) {
    guard let layout = blockView.layout,
      gestureData = _dragGestureData[layout.uuid] else {
        return
    }

    // If this block can be connected to anything, connect it.
    if let connectionPair = findBestConnectionForBlock(blockView) {
      connectPair(connectionPair)
    }

    // Unset drag mode for connections and add back to the connection manager
    // TODO:(vicng) Take into account dragging multiple blocks at the same time and how that
    // affects the connection manager
    for connection in gestureData.childConnections {
      connection.dragMode = false
      layout.workspaceLayout.connectionManager.addConnection(connection)
    }

    // TODO:(vicng) Clear highlight

    _dragGestureData[layout.uuid] = nil
  }

  // MARK: - Private

  /**
  Iterate over all direct connections on the block and find the one that is closest to a
  valid connection on another block.

  - Parameter blockView: The block whose connections to search
  - Returns: A connection pair where the `pair.moving` connection is one on the given block and the
  `pair.target` connection is the closest compatible connection. Nil is returned if no suitable
  connection pair could be found.
  */
  private func findBestConnectionForBlock(blockView: BlockView) -> ConnectionPair? {
    guard let blockLayout = blockView.blockLayout else {
      return nil
    }

    // Find the connection that is closest to any connection on the block.
    var candidate: ConnectionPair?
    var maxRadius = blockLayout.workspaceLayout.workspaceUnitFromViewUnit(Dragger.MAX_SNAP_DISTANCE)

    for draggedBlockConnection in blockLayout.block.directConnections {
      if let compatibleConnection = blockLayout.workspaceLayout.connectionManager
        .closestConnection(draggedBlockConnection, maxRadius: maxRadius)
      {
        candidate = (moving: draggedBlockConnection, target: compatibleConnection)
        maxRadius = draggedBlockConnection.distanceFromConnection(compatibleConnection)
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
}

/**
Stores relevant data for the lifetime of a single drag.
*/
private class DragGestureData {
  /// Stores the block view's starting position when the pan gesture began, in Workspace coordinates
  private var blockViewStartPosition: WorkspacePoint

  /// Stores the starting touch position when the pan gesture began, in Workspace coordinates
  private var touchStartPosition: WorkspacePoint

  /// Child connections for the block that were removed from the connection manager at the beginning
  /// of the pan gesture.
  private var childConnections = [Connection]()

  // MARK: - Initializers

  private init(blockViewStartPosition: WorkspacePoint, touchStartPosition: WorkspacePoint) {
    self.blockViewStartPosition = blockViewStartPosition
    self.touchStartPosition = touchStartPosition
  }
}
