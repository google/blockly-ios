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
Stores information on how to render and position a `Block` on-screen.
*/
@objc(BKYWorkspaceLayout)
public class WorkspaceLayout: Layout {
  // MARK: - Properties

  /// The `Workspace` to layout
  public let workspace: Workspace

  /// The locations of all connections in this workspace
  public let connectionManager: ConnectionManager

  /// All child `BlockGroupLayout` objects that have been appended to this layout
  public var blockGroupLayouts: [BlockGroupLayout] {
    return childLayouts.map({$0.1}) as! [BlockGroupLayout]
  }

  /// The current scale of the UI, relative to the Workspace coordinate system.
  /// eg. scale = 2.0 means that a (10, 10) UIView point translates to a (5, 5) Workspace point.
  public var scale: CGFloat = 1.0 {
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
  private var _zIndexCounter: CGFloat = 1

  /// Maximum value that the z-index counter should reach
  private var _maximumZIndexCounter: CGFloat = (pow(2, 23) - 1)

  /// Builder for constructing layouts under this workspace
  public let layoutBuilder: LayoutBuilder

  // MARK: - Initializers

  public required init(workspace: Workspace, layoutBuilder: LayoutBuilder) {
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

    // Force the workspace to be re-displayed
    self.needsDisplay = true
  }

  // MARK: - Public

  /**
  Returns all descendants of this layout that are of type `BlockLayout`.
  */
  public func allBlockLayoutDescendants() -> [BlockLayout] {
    var descendants = [BlockLayout]()
    var layoutsToProcess = childLayouts.map({$0.1}) as! [BlockGroupLayout]

    while !layoutsToProcess.isEmpty {
      let blockGroupLayout = layoutsToProcess.removeFirst()
      descendants += blockGroupLayout.blockLayouts

      for blockLayout in blockGroupLayout.blockLayouts {
        for inputLayout in blockLayout.inputLayouts {
          layoutsToProcess.append(inputLayout.blockGroupLayout)
        }
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
    }
  }

  /**
  Removes all elements from `self.blockGroupLayouts` and sets their `parentLayout` to nil.

  - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  public func reset(updateLayout updateLayout: Bool) {
    for (_, layout) in self.childLayouts {
      if let blockGroupLayout = layout as? BlockGroupLayout {
        removeBlockGroupLayout(blockGroupLayout, updateLayout: false)
      }
    }

    if updateLayout {
      updateLayoutUpTree()
    }
  }

  /**
  Brings the given block group layout to the front by setting its `zPosition` to the
  highest value in the workspace.

  - Parameter blockGroupLayout: The given block group layout
  */
  public func bringBlockGroupLayoutToFront(layout: BlockGroupLayout?) {
    guard let blockGroupLayout = layout else {
      return
    }

    // Verify that this layout is a child of the workspace
    if childLayouts[blockGroupLayout.uuid] == nil {
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
}

// MARK: - Layout Translation

extension WorkspaceLayout {
  // MARK: - Public

  /**
  Using the current `scale` value, this method translates a point from the UIView coordinate system
  to the Workspace coordinate system.

  - Parameter point: A point from the UIView coordinate system.
  - Returns: A point in the Workspace coordinate system.
  */
  public func workspacePointFromViewPoint(point: CGPoint) -> WorkspacePoint {
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
  Using the current `scale` value, this method translates a size from the UIView coordinate system
  to the Workspace coordinate system.

  - Parameter size: A size from the UIView coordinate system.
  - Returns: A size in the Workspace coordinate system.
  */
  public func workspaceSizeFromViewSize(size: CGSize) -> WorkspaceSize {
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
  Using the current `scale` value, this method translates a unit value from the UIView coordinate
  system to the Workspace coordinate system.

  - Parameter unit: A unit value from the UIView coordinate system.
  - Returns: A unit value in the Workspace coordinate system.
  */
  public func workspaceUnitFromViewUnit(unit: CGFloat) -> CGFloat {
    if scale == 0 {
      return 0
    } else if scale == 1 {
      return unit
    } else {
      return unit / scale
    }
  }

  /**
  Using the current `scale` value, this method translates a unit value from the Workspace coordinate
  system to the UIView coordinate system.

  - Parameter unit: A unit value from the Workspace coordinate system.
  - Returns: A unit value in the UIView coordinate system.
  */
  public func viewUnitFromWorkspaceUnit(unit: CGFloat) -> CGFloat {
    if scale == 0 {
      return 0
    } else if scale == 1 {
      return unit
    } else {
      // Round unit values when going from workspace to view coordinates. This helps keep
      // things consistent when translating points and sizes.
      return round(unit * scale)
    }
  }

  /**
  Using the current `scale` value, this method translates a point from the Workspace coordinate
  system to the UIView coordinate system.

  - Parameter point: A point from the Workspace coordinate system.
  - Returns: A point in the UIView coordinate system.
  */
  public func viewPointFromWorkspacePoint(point: WorkspacePoint) -> CGPoint {
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
  Using the current `scale` value, this method translates an (x, y) point from the Workspace
  coordinate system to the UIView coordinate system.

  - Parameter x: The x-coordinate of the point
  - Parameter y: The y-coordinate of the point
  - Returns: A point in the UIView coordinate system.
  */
  public func viewPointFromWorkspacePoint(x: CGFloat, _ y: CGFloat) -> CGPoint {
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
  Using the current `scale` value, this method translates a size from the Workspace coordinate
  system to the UIView coordinate system.

  - Parameter size: A size from the Workspace coordinate system.
  - Returns: A size in the UIView coordinate system.
  */
  public func viewSizeFromWorkspaceSize(size: WorkspaceSize) -> CGSize {
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
  Using the current `scale` value, this method translates a point and size from the Workspace
  coordinate system to a rectangle view frame in the UIView coordinate system.

  - Parameter point: A point from the Workspace coordinate system.
  - Parameter size: A size from the Workspace coordinate system.
  - Returns: A rectangle in the UIView coordinate system.
  */
  public func viewFrameFromWorkspacePoint(point: WorkspacePoint, size: WorkspaceSize) -> CGRect {
    // TODO:(vicng) Handle the offset of the viewport relative to the workspace
    if scale == 0 {
      return CGRectZero
    } else if scale == 1 {
      return CGRectMake(point.x, point.y, size.width, size.height)
    } else {
      return CGRectMake(
        viewUnitFromWorkspaceUnit(point.x),
        viewUnitFromWorkspaceUnit(point.y),
        viewUnitFromWorkspaceUnit(size.width),
        viewUnitFromWorkspaceUnit(size.height))
    }
  }
}
