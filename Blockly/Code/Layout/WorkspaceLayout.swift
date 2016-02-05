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

  /// The current scale of the UI, relative to the Workspace coordinate system.
  /// eg. scale = 2.0 means that a (10, 10) UIView point scales to a (5, 5) Workspace point.
  public final var scale: CGFloat = 1.0 {
    didSet {
      // Do not allow a scale less than 0.5
      if scale < 0.5 {
        scale = 0.5
      }
      if scale != oldValue {
        updateLayoutDownTree()
      }
    }
  }

  /// z-index counter used to layer blocks in a specific order.
  private var _zIndexCounter: UInt = 1

  /// Maximum value that the z-index counter should reach
  private var _maximumZIndexCounter: UInt = (UInt.max - 1)

  // MARK: - Initializers

  public init(workspace: Workspace, layoutBuilder: LayoutBuilder) throws {
    self.workspace = workspace
    self.layoutBuilder = layoutBuilder
    self.connectionManager = ConnectionManager()
    super.init(workspaceLayout: nil)

    self.workspaceLayout = self
    self.layoutBuilder.workspaceLayout = self

    // Assign the layout as the workspace's delegate so it can listen for new events that
    // occur on the workspace
    workspace.delegate = self

    // Immediately start tracking all connections of blocks in the workspace
    for (_, block) in workspace.allBlocks {
      trackConnectionsForBlock(block)
    }

    // Build the layout tree, based on the existing state of the workspace. This creates a set of
    // layout objects for all of its blocks/inputs/fields
    try workspaceLayout.layoutBuilder.buildLayoutTree()

    // Perform a layout update for the entire tree
    workspaceLayout.updateLayoutDownTree()
  }

  // MARK: - Super

  public override func performLayout(includeChildren includeChildren: Bool) {
    var size = WorkspaceSizeZero

    // Update relative position/size of blocks
    for blockGroupLayout in self.blockGroupLayouts {
      if includeChildren {
        blockGroupLayout.performLayout(includeChildren: true)
      }

      size = LayoutHelper.sizeThatFitsLayout(blockGroupLayout, fromInitialSize: size)
    }

    // Update size required for the workspace
    self.contentSize = size

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

    // View positions need to be refreshed for the entire tree since in RTL, if the canvas size
    // changes, the positions of block groups also change.
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
      if let blockGroupLayout = try layoutBuilder.buildLayoutTreeForTopLevelBlock(block) {
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

      // TODO:(vicng) Detach/unset connection listeners (call some sort of reset method?)

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
    // TODO:(vicng) Optimize re-rendering all layouts affected by this method

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
      throw BlocklyError(.LayoutIllegalState, "Can't connect a block without a layout. ")
    }

    // Check that this layout is connected to a block group layout
    if sourceBlock.layout?.parentBlockGroupLayout == nil {
      throw BlocklyError(.LayoutIllegalState,
        "Block layout is not connected to a parent block group layout. ")
    }

    if (connection.targetBlock != nil &&
      connection.targetBlock!.layout?.workspaceLayout != sourceBlockLayout.workspaceLayout)
    {
      throw BlocklyError(.LayoutIllegalState, "Can't connect blocks in different workspaces")
    }

    let workspaceLayout = sourceBlockLayout.workspaceLayout
    let workspace = workspaceLayout.workspace

    // Disconnect this block's layout and all subsequent block layouts from its block group layout,
    // so they can be reattached to another block group layout
    let layoutsToReattach: [BlockLayout]
    if let oldParentLayout = sourceBlockLayout.parentBlockGroupLayout {
      layoutsToReattach =
        oldParentLayout.removeAllStartingFromBlockLayout(sourceBlockLayout, updateLayout: true)

      if oldParentLayout.blockLayouts.count == 0 &&
        oldParentLayout.parentLayout == workspace.layout {
          // Remove this block's old parent group layout from the workspace level
          workspaceLayout.removeBlockGroupLayout(oldParentLayout, updateLayout: true)
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
      let layoutFactory = workspaceLayout.layoutBuilder.layoutFactory
      let blockGroupLayout =
      layoutFactory.layoutForBlockGroupLayout(workspaceLayout: workspaceLayout)
      blockGroupLayout.relativePosition = sourceBlockLayout.absolutePosition

      // Add this new block group layout to the workspace level
      workspaceLayout.appendBlockGroupLayout(blockGroupLayout, updateLayout: false)
      workspaceLayout.bringBlockGroupLayoutToFront(blockGroupLayout)

      // Reattach block layouts to a new block group layout
      blockGroupLayout.appendBlockLayouts(layoutsToReattach, updateLayout: true)
    }
  }
}

// TODO:(vicng) Consider pulling these methods out into another class and so each layout could
// directly reference a single instance of that class (defined for a workspace). It should
// theoretically boost performance.
// TODO:(vicng) Consider removing methods that scale between Workspace points and View points.
// Users may think they represent direct translations between the two, which is wrong (because
// of RTL).

// MARK: - Layout Scaling

extension WorkspaceLayout {
  // MARK: - Public

  /**
  Using the current `scale` value, this method scales a point from the UIView coordinate system to
  the Workspace coordinate system.

  - Parameter point: A point from the UIView coordinate system.
  - Returns: A point in the Workspace coordinate system.
  - Note: This does not translate a UIView point directly into a Workspace point, it only scales the
  magnitude of a UIView point into the Workspace coordinate system. For example, in RTL, more
  calculation would need to be done to get the UIView point's translated Workspace point.
  */
  public final func scaledWorkspaceVectorFromViewVector(point: CGPoint) -> WorkspacePoint {
    // TODO:(vicng) Handle the offset of the viewport relative to the workspace
    if scale == 0 {
      return WorkspacePointZero
    } else if scale == 1 {
      return point
    } else {
      return WorkspacePointMake(
        workspaceUnitFromViewUnit(point.x),
        workspaceUnitFromViewUnit(point.y))
    }
  }

  /**
  Using the current `scale` value, this method scales a size from the UIView coordinate system
  to the Workspace coordinate system.

  - Parameter size: A size from the UIView coordinate system.
  - Returns: A size in the Workspace coordinate system.
  */
  public final func workspaceSizeFromViewSize(size: CGSize) -> WorkspaceSize {
    if scale == 0 {
      return WorkspaceSizeZero
    } else if scale == 1 {
      return size
    } else {
      return WorkspaceSizeMake(
        workspaceUnitFromViewUnit(size.width),
        workspaceUnitFromViewUnit(size.height))
    }
  }

  /**
  Using the current `scale` value, this method scales a unit value from the UIView coordinate
  system to the Workspace coordinate system.

  - Parameter unit: A unit value from the UIView coordinate system.
  - Returns: A unit value in the Workspace coordinate system.
  */
  public final func workspaceUnitFromViewUnit(unit: CGFloat) -> CGFloat {
    if scale == 0 {
      return 0
    } else if scale == 1 {
      return unit
    } else {
      return unit / scale
    }
  }

  /**
  Using the current `scale` value, this method scales a unit value from the Workspace coordinate
  system to the UIView coordinate system.

  - Parameter unit: A unit value from the Workspace coordinate system.
  - Returns: A unit value in the UIView coordinate system.
  */
  public final func viewUnitFromWorkspaceUnit(unit: CGFloat) -> CGFloat {
    if scale == 0 {
      return 0
    } else if scale == 1 {
      return unit
    } else {
      // Round unit values when going from workspace to view coordinates. This helps keep
      // things consistent when scaling points and sizes.
      return round(unit * scale)
    }
  }

  /**
  Using the current `scale` value, this method a left-to-right point from the Workspace
  coordinate system to the UIView coordinate system.

  - Parameter point: A point from the Workspace coordinate system.
  - Returns: A point in the UIView coordinate system.
  */
  public final func viewPointFromWorkspacePoint(point: WorkspacePoint) -> CGPoint {
    // TODO:(vicng) Handle the offset of the viewport relative to the workspace
    if scale == 0 {
      return CGPointZero
    } else if scale == 1 {
      return point
    } else {
      return CGPointMake(viewUnitFromWorkspaceUnit(point.x), viewUnitFromWorkspaceUnit(point.y))
    }
  }

  /**
  Using the current `scale` value, this method scales a (x, y) point from the Workspace coordinate
  system to the UIView coordinate system.

  - Parameter x: The x-coordinate of the point
  - Parameter y: The y-coordinate of the point
  - Returns: A point in the UIView coordinate system.
  */
  public final func viewPointFromWorkspacePoint(x: CGFloat, _ y: CGFloat) -> CGPoint {
    // TODO:(vicng) Handle the offset of the viewport relative to the workspace
    if scale == 0 {
      return CGPointZero
    } else if scale == 1 {
      return CGPointMake(x, y)
    } else {
      return CGPointMake(viewUnitFromWorkspaceUnit(x), viewUnitFromWorkspaceUnit(y))
    }
  }

  /**
  Using the current `scale` value, this method scales a size from the Workspace coordinate
  system to the UIView coordinate system.

  - Parameter size: A size from the Workspace coordinate system.
  - Returns: A size in the UIView coordinate system.
  */
  public final func viewSizeFromWorkspaceSize(size: WorkspaceSize) -> CGSize {
    if scale == 0 {
      return CGSizeZero
    } else if scale == 1 {
      return size
    } else {
      return CGSizeMake(
        viewUnitFromWorkspaceUnit(size.width),
        viewUnitFromWorkspaceUnit(size.height))
    }
  }

  /**
   Maps a `UIView` point relative to `self.scrollView.blockGroupView` to a logical Workspace
   position.

   - Parameter point: The `UIView` point
   - Returns: The corresponding `WorkspacePoint`
   */
  public final func workspacePositionFromViewPosition(point: CGPoint) -> WorkspacePoint {
    var viewPoint = point
    if workspaceLayout.workspace.rtl {
      // In RTL, the workspace position is relative to the top-right corner
      viewPoint.x = viewUnitFromWorkspaceUnit(self.totalSize.width) - viewPoint.x
    }

    // Scale this CGPoint (ie. `viewPoint`) into a WorkspacePoint
    return workspaceLayout.scaledWorkspaceVectorFromViewVector(viewPoint)
  }
}
