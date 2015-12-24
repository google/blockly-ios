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
  public final var blockGroupLayouts: [BlockGroupLayout] {
    return childLayouts.map({$0}) as! [BlockGroupLayout]
  }

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

  public init(workspace: Workspace, layoutBuilder: LayoutBuilder) {
    self.workspace = workspace
    self.layoutBuilder = layoutBuilder
    self.connectionManager = ConnectionManager()
    super.init(workspaceLayout: nil)

    self.workspaceLayout = self
    self.layoutBuilder.workspaceLayout = self
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
    // Setting the parentLayout automatically adds it to self.childLayouts
    blockGroupLayout.parentLayout = self

    if updateLayout {
      updateLayoutUpTree()
      scheduleChangeEventWithFlags(Layout.Flag_NeedsDisplay)
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
    // Setting the parentLayout to nil automatically removes it from self.childLayouts
    blockGroupLayout.parentLayout = nil

    if updateLayout {
      updateLayoutUpTree()
      scheduleChangeEventWithFlags(Layout.Flag_NeedsDisplay)
    }
  }

  /**
  Removes all elements from `self.blockGroupLayouts` and sets their `parentLayout` to nil.

  - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  public func reset(updateLayout updateLayout: Bool = true) {
    for layout in self.childLayouts {
      if let blockGroupLayout = layout as? BlockGroupLayout {
        removeBlockGroupLayout(blockGroupLayout, updateLayout: false)
      }
    }

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

    blockGroupLayout.zIndex = ++_zIndexCounter

    if _zIndexCounter >= _maximumZIndexCounter {
      // The maximum z-position has been reached (unbelievable!). Normalize all block group layouts.
      _zIndexCounter = 1

      let ascendingBlockGroupLayouts = self.blockGroupLayouts.sort({ $0.zIndex < $1.zIndex })

      for blockGroupLayout in ascendingBlockGroupLayouts {
        blockGroupLayout.zIndex = ++_zIndexCounter
      }
    }
  }

  /**
   Creates the layout tree for a given top-level `block` and sets its parent's block group position
   to a given `position`.

   - Parameter block: The `Block` to add
   - Parameter position: The position to place the top level block in the workspace.
   - Throws:
   `BlocklyError`: Thrown if the layout tree could not be properly constructed for `block`.
   */
  public func addLayoutTreeForTopLevelBlock(block: Block, atPosition position: WorkspacePoint)
    throws
  {
    // Create the layout tree for this new block
    try layoutBuilder.buildLayoutTreeForTopLevelBlock(block)

    guard let blockGroupLayout = block.layout?.parentBlockGroupLayout else {
      throw BlocklyError(.LayoutIllegalState, "Could not locate the parent block group layout")
    }

    // Set the position of the block group and perform a layout for the tree
    blockGroupLayout.relativePosition = position
    blockGroupLayout.updateLayoutDownTree()

    // Update the content size
    updateCanvasSize()

    // This layout needs a complete refresh since a new block group layout was added
    scheduleChangeEventWithFlags(Layout.Flag_NeedsDisplay)
  }

  /**
   Updates the required size of this layout based on the current positions of all blocks.
   */
  public func updateCanvasSize() {
    performLayout(includeChildren: false)
    refreshViewPositionsForTree()
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
}
