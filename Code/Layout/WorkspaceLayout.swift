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

  /// The corresponding `BlockGroupLayout` objects seeded by each `Block` inside of
  /// `self.workspace.blocks[]`.
  public private(set) var blockGroupLayouts = [BlockGroupLayout]()

  /// The current scale of the UI, relative to the Workspace coordinate system.
  /// eg. scale = 2.0 means that a (10, 10) UIView point translates to a (5, 5) Workspace point.
  public var scale: CGFloat = 1.0 {
    didSet {
      // Do not allow a scale less than 0.5
      if scale < 0.5 {
        scale = 0.5
      }
      if scale != oldValue {
        updateLayout()
      }
    }
  }

  // MARK: - Initializers

  public required init(workspace: Workspace) {
    self.workspace = workspace
    super.init(workspaceLayout: nil, parentLayout: nil)
    self.workspace.delegate = self
    self.workspaceLayout = self
  }

  // MARK: - Super

  public override var childLayouts: [Layout] {
    return blockGroupLayouts
  }

  public override func layoutChildren() {
    // Update relative position/size of blocks
    for blockGroupLayout in blockGroupLayouts {
      blockGroupLayout.layoutChildren()
    }

    // Update size required for the workspace
    self.size = sizeThatFitsForChildLayouts()
  }

  // MARK: - Public

  /**
  Returns all descendants of this layout that are of type `BlockLayout`.
  */
  public func allBlockLayoutDescendants() -> [BlockLayout] {
    var descendants = [BlockLayout]()
    var layoutsToProcess = blockGroupLayouts

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
  */
  public func appendBlockGroupLayout(blockGroupLayout: BlockGroupLayout) {
    blockGroupLayout.parentLayout = self
    blockGroupLayouts.append(blockGroupLayout)
  }

  /**
  Removes `self.blockGroupLayouts[index]`, sets its `parentLayout` to nil, and returns it.

  - Parameter blockGroupLayout: The `BlockGroupLayout` to append.
  - Returns: The `BlockGroupLayout` that was removed.
  */
  public func removeBlockGroupLayoutAtIndex(index: Int) -> BlockGroupLayout {
    let blockGroupLayout = blockGroupLayouts.removeAtIndex(index)
    blockGroupLayout.parentLayout = nil
    return blockGroupLayout
  }
}

// MARK: - WorkspaceDelegate implementation

extension WorkspaceLayout: WorkspaceDelegate {
  public func workspaceDidChange(workspace: Workspace) {
    // TODO:(vicng) Potentially generate an event to update the corresponding view
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
      return WorkspacePointMake(point.x / scale, point.y / scale)
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
      return WorkspaceSizeMake(size.width / scale, size.height / scale)
    }
  }

  /**
  Using the current `scale` value, this method translates a point from the Workspace coordinate
  system to the UIView coordinate system.

  - Parameter size: A point from the Workspace coordinate system.
  - Returns: A point in the UIView coordinate system.
  */
  public func viewPointFromWorkspacePoint(point: WorkspacePoint) -> CGPoint {
    // TODO:(vicng) Handle the offset of the viewport relative to the workspace
    if scale == 0 {
      return CGPointZero
    } else if scale == 1 {
      return point
    } else {
      return CGPointMake(round(point.x * scale), round(point.y * scale))
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
    return viewPointFromWorkspacePoint(WorkspacePointMake(x, y))
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
        round(point.x * scale),
        round(point.y * scale),
        ceil(size.width * scale),
        ceil(size.height * scale))
    }
  }
}
