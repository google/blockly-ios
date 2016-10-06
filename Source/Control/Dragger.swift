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
public final class Dragger: NSObject {
  // MARK: - Properties

  /// The workspace layout where blocks are being dragged
  public var workspaceLayoutCoordinator: WorkspaceLayoutCoordinator? {
    didSet {
      if workspaceLayoutCoordinator == oldValue {
        return
      }

      // Reset all gesture data
      _dragGestureData.keys.forEach { clearGestureData(forUUID: $0) }
    }
  }
  /// Stores the data for each active drag gesture, keyed by the corresponding block view's layout
  /// uuid
  fileprivate var _dragGestureData = [String: DragGestureData]()

  // MARK: - Public

  /**
  Disconnect the given block layout from any superior connections and start dragging it (and any of
  its connected block layouts) in the workspace.

  - Parameter layout: The given block layout
  - Parameter touchPosition: The initial touch position, specified in the Workspace coordinate
  system
  */
  public func startDraggingBlockLayout(_ layout: BlockLayout, touchPosition: WorkspacePoint) {
    guard let workspaceLayoutCoordinator = self.workspaceLayoutCoordinator,
      let connectionManager = workspaceLayoutCoordinator.connectionManager
      , layout.block.draggable &&
        workspaceLayoutCoordinator.workspaceLayout
          .allVisibleBlockLayoutsInWorkspace().contains(layout) else
    {
      return
    }

    Layout.animate {
      // Remove any existing gesture data for the layout
      clearGestureDataForBlockLayout(layout)

      // Disconnect this block from its previous or output connections prior to moving it
      let block = layout.block
      if let previousConnection = block.previousConnection {
        workspaceLayoutCoordinator.disconnect(previousConnection)
      }
      if let outputConnection = block.outputConnection {
        workspaceLayoutCoordinator.disconnect(outputConnection)
      }

      // Highlight this block
      layout.highlighted = true
      layout.rootBlockGroupLayout?.dragging = true

      // Bring its block group layout to the front
      workspaceLayoutCoordinator.workspaceLayout.bringBlockGroupLayoutToFront(
        layout.rootBlockGroupLayout)

      // Start a new connection group for this block group layout
      let newConnectionGroup = connectionManager.startGroup(forBlock: block)

      // Keep track of the gesture data for this drag
      let dragGestureData = DragGestureData(
        blockLayout: layout,
        blockLayoutStartPosition: layout.absolutePosition,
        touchStartPosition: touchPosition,
        connectionGroup: newConnectionGroup
      )

      _dragGestureData[layout.uuid] = dragGestureData
    }
  }

  /**
  Continue dragging a block layout (and any of its connected block layouts) in the workspace.

  - Parameter layout: The given block layout
  - Parameter touchPosition: The current touch position, specified in the Workspace coordinate
  system
  */
  public func continueDraggingBlockLayout(_ layout: BlockLayout, touchPosition: WorkspacePoint) {
    guard let gestureData = _dragGestureData[layout.uuid] else {
      return
    }

    // Set dragging to true, so the block groups displays with correct alpha through changes to the
    // group mid-drag
    layout.rootBlockGroupLayout?.dragging = true

    // Set the connection manager group to "drag mode" to avoid wasting compute cycles during the
    // drag
    gestureData.connectionGroup.dragMode = true

    // Figure out the new workspace position based on the touch position
    let position = gestureData.blockLayoutStartPosition +
      (touchPosition - gestureData.touchStartPosition)

    // Move to the new position (only update the canvas size at the very end of the drag)
    layout.parentBlockGroupLayout?.move(toWorkspacePosition: position, updateCanvasSize: false)

    // Update the highlighted connection for this drag
    updateHighlightedConnection(forDrag: gestureData)

    // Now that the drag is complete, unset the flag
    gestureData.connectionGroup.dragMode = false
  }

  /**
  Finish dragging a block layout (and any of its connected block layouts) in the workspace.

  - Parameter layout: The given block layout
  */
  public func finishDraggingBlockLayout(_ layout: BlockLayout) {
    guard let workspaceLayoutCoordinator = self.workspaceLayoutCoordinator else {
      return
    }

    Layout.animate {
      // Remove the highlight for this block
      layout.highlighted = false
      layout.rootBlockGroupLayout?.dragging = false

      // If this block can be connected to anything, connect it.
      if let drag = _dragGestureData[layout.uuid],
        let connectionPair = findBestConnection(forDrag: drag)
      {
        workspaceLayoutCoordinator.connectPair(connectionPair)

        clearGestureDataForBlockLayout(layout,
          moveConnectionsToGroup: connectionPair.fromConnectionManagerGroup)
      } else {
        clearGestureDataForBlockLayout(layout)

        // Update the workspace canvas size since it may have changed (this was purposely skipped
        // during the drag for performance reasons, so we have to update it now). Also, there is
        // no need to call this method in the `if` part of this `if/else` block, since
        // `self.connectPair(:)` implicitly calls it already.
        workspaceLayoutCoordinator.workspaceLayout.updateCanvasSize()
      }

      // Bump any neighbors of the block layout
      workspaceLayoutCoordinator.blockBumper.bumpNeighbors(ofBlockLayout: layout)

      // Update the highlighted connections for all other drags (due to potential changes in block
      // sizes)
      for (_, gestureData) in _dragGestureData {
        updateHighlightedConnection(forDrag: gestureData)
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
    _ layout: BlockLayout, moveConnectionsToGroup connectionGroup: ConnectionManager.Group? = nil)
  {
    clearGestureData(forUUID: layout.uuid, moveConnectionsToGroup: connectionGroup)
  }

  // MARK: - Private

  /**
   Clears the drag data for a block layout's UUID, removes any highlights, and moves connections
   that were being tracked by the drag to a new group.

   - Parameter uuid: The given block layout's UUID
   - Parameter connectionGroup: The new connection group to move the connections to. If this is
   nil, the connection manager's `mainGroup` is used.
   */
  fileprivate func clearGestureData(
    forUUID uuid: String, moveConnectionsToGroup connectionGroup: ConnectionManager.Group? = nil)
  {
    guard let gestureData = _dragGestureData[uuid] else {
      return
    }

    // Move connections to a different group in the connection manager
    workspaceLayoutCoordinator?.connectionManager?
      .mergeGroup(gestureData.connectionGroup, intoGroup: connectionGroup)

    removeHighlightedConnection(forDrag: gestureData)
    _dragGestureData[uuid] = nil
  }

  /**
  Updates the highlighted connection for a dragged block.

  - Parameter drag: The `DragGestureData` that is being tracked for the block.
  */
  fileprivate func updateHighlightedConnection(forDrag drag: DragGestureData) {
    let connectionPair = findBestConnection(forDrag: drag)
    if connectionPair?.target != drag.highlightedConnection {
      // The highlight has changed, remove the old highlight
      removeHighlightedConnection(forDrag: drag)

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
  fileprivate func removeHighlightedConnection(forDrag drag: DragGestureData) {
    if let blockLayout = drag.blockLayout {
      drag.highlightedConnection?.removeHighlightForBlock(blockLayout.block)
      drag.highlightedConnection = nil
    }
  }

  /**
  Returns the most suitable connection pair for a given drag, if one exists.
  */
  fileprivate func findBestConnection(forDrag drag: DragGestureData)
    -> ConnectionManager.ConnectionPair?
  {
    if let workspaceLayout = workspaceLayoutCoordinator?.workspaceLayout,
      let connectionManager = workspaceLayoutCoordinator?.connectionManager
    {
      let maxRadius = workspaceLayout.config.unit(
        for: LayoutConfig.BlockSnapDistance, defaultValue: LayoutConfig.Unit(0)).workspaceUnit

      return
        connectionManager.findBestConnection(forGroup: drag.connectionGroup, maxRadius: maxRadius)
    }
    return nil
  }
}

/**
Stores relevant data for the lifetime of a single drag.
*/
private class DragGestureData {
  /// The block layout that is being dragged
  fileprivate weak var blockLayout: BlockLayout?

  /// Stores the block layout's starting position when the drag began, in Workspace coordinates
  fileprivate let blockLayoutStartPosition: WorkspacePoint

  /// Stores the starting touch position when the drag began, in Workspace coordinates
  fileprivate let touchStartPosition: WorkspacePoint

  /// Group of connections from the connection manager at the beginning of the pan gesture.
  fileprivate let connectionGroup: ConnectionManager.Group

  /// Stores the current connection that is being highlighted because of this drag gesture
  fileprivate weak var highlightedConnection: Connection?

  // MARK: - Initializers

  fileprivate init(blockLayout: BlockLayout, blockLayoutStartPosition: WorkspacePoint,
    touchStartPosition: WorkspacePoint, connectionGroup: ConnectionManager.Group) {
      self.blockLayout = blockLayout
      self.blockLayoutStartPosition = blockLayoutStartPosition
      self.touchStartPosition = touchStartPosition
      self.connectionGroup = connectionGroup
  }
}
