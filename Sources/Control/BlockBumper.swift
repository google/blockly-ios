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
 Object responsible for bumping blocks away from each other.
 */
@objc(BKYBlockBumper)
@objcMembers open class BlockBumper: NSObject {
  // MARK: - Properties

  /// The workspace layout coordinator where blocks are being bumped
  public weak var workspaceLayoutCoordinator: WorkspaceLayoutCoordinator?

  /// Convenience property for `self.workspaceLayoutCoordinator?.workspaceLayout`
  private var workspaceLayout: WorkspaceLayout? {
    return workspaceLayoutCoordinator?.workspaceLayout
  }

  /// The X and Y amount to bump blocks away from each other, specified as a Workspace coordinate
  /// system unit. This value is read from `self.workspaceLayout.config` using the key
  /// `LayoutConfig.BlockBumpDistance`. If no value exists for that key, this defaults to `0`.
  private var bumpDistance: CGFloat {
    return workspaceLayout?.config.unit(for: LayoutConfig.BlockBumpDistance).workspaceUnit ?? 0
  }

  // MARK: - Public

  /**
  Bumps the block layout belonging to a given connection away from another connection.

  - parameter impingingConnection: The connection of the block being bumped away.
  - parameter stationaryConnection: The connection that is being used as the source location for
  the bump.
  */
  open func bumpBlockLayoutOfConnection(
    _ impingingConnection: Connection, awayFromConnection stationaryConnection: Connection)
  {
    guard let blockLayout = impingingConnection.sourceBlock?.layout,
      let blockGroupLayout = blockLayout.rootBlockGroupLayout,
      !blockGroupLayout.dragging else {
      return
    }

    let dx = stationaryConnection.position.x + bumpDistance - impingingConnection.position.x
    let dy = stationaryConnection.position.y + bumpDistance - impingingConnection.position.y
    let newPosition = WorkspacePoint(
      x: blockGroupLayout.absolutePosition.x + dx,
      y: blockGroupLayout.absolutePosition.y + dy)
    blockGroupLayout.move(toWorkspacePosition: newPosition)
    workspaceLayout?.bringBlockGroupLayoutToFront(blockGroupLayout)
  }

  /**
   Move all neighbors of the given block layout and its sub-blocks so that they don't appear to be
   connected to the given block layout.

   - parameter blockLayout: The `BlockLayout` to bump others away from.
   - parameter alwaysBumpOthers: [Optional] When set to `true`, `blockLayout` will always bump other
   block groups instead of its own. When set to `false`, `blockLayout`'s own block group may be
   bumped. This value defaults to `false`.
   */
  open func bumpNeighbors(ofBlockLayout blockLayout: BlockLayout, alwaysBumpOthers: Bool = false) {
    // The default behavior is to always bump `blockLayout` away from the neighbors of its
    // previous/output connections. However, if `alwaysBumpOthers` has been set to `true`, then
    // those neighbors need to get bumped away instead.
    if let previousConnection = blockLayout.block.previousConnection {
      if alwaysBumpOthers {
        bumpAllBlocks(nearConnection: previousConnection)
      } else {
        bumpAwayFromNeighborsBlockLayout(ofConnection: previousConnection)
      }
    }
    if let outputConnection = blockLayout.block.outputConnection {
      if alwaysBumpOthers {
        bumpAllBlocks(nearConnection: outputConnection)
      } else {
        bumpAwayFromNeighborsBlockLayout(ofConnection: outputConnection)
      }
    }

    // Bump blocks away from high priority connections on this block
    for directConnection in blockLayout.block.directConnections {
      if directConnection.highPriority {
        if let connectedBlockLayout = directConnection.targetBlock?.layout {
          bumpNeighbors(ofBlockLayout: connectedBlockLayout, alwaysBumpOthers: alwaysBumpOthers)
        }
        if let connectedShadowBlockLayout = directConnection.shadowBlock?.layout {
          bumpNeighbors(ofBlockLayout: connectedShadowBlockLayout,
                        alwaysBumpOthers: alwaysBumpOthers)
        }

        bumpAllBlocks(nearConnection: directConnection)
      }
    }
  }

  // MARK: - Private

  /**
   Bumps a block layout belonging to a given connection away from its first neighbor.

   - parameter connection: The connection of the block that is being bumped away.
   */
  private func bumpAwayFromNeighborsBlockLayout(ofConnection connection: Connection) {
    guard
      let connectionManager = workspaceLayoutCoordinator?.connectionManager,
      let rootBlockGroupLayout = connection.sourceBlock?.layout?.rootBlockGroupLayout else
    {
      return
    }

    let neighbors =
      connectionManager.stationaryNeighbors(forConnection: connection, maxRadius: bumpDistance)

    for neighbor in neighbors {
      // Bump away from the first neighbor that isn't in the same block group as the target
      // connection's block group
      if neighbor.sourceBlock?.layout?.rootBlockGroupLayout != rootBlockGroupLayout {
        bumpBlockLayoutOfConnection(connection, awayFromConnection: neighbor)
        return
      }
    }
  }

  /**
   Finds all connections near a given connection and bumps their blocks away.

   - parameter connection: The connection that is at the center of the current bump operation
   */
  private func bumpAllBlocks(nearConnection connection: Connection) {
    guard
      let connectionManager = workspaceLayoutCoordinator?.connectionManager,
      let rootBlockGroupLayout = connection.sourceBlock?.layout?.rootBlockGroupLayout else
    {
      return
    }

    let neighbors =
      connectionManager.stationaryNeighbors(forConnection: connection, maxRadius: bumpDistance)

    for neighbor in neighbors {
      // Only bump blocks that aren't in the same block group as the target connection's block group
      if let neighborLayout = neighbor.sourceBlock?.layout
       , neighborLayout.rootBlockGroupLayout != rootBlockGroupLayout
      {
        bumpBlockLayoutOfConnection(neighbor, awayFromConnection: connection)
      }
    }
  }
}
