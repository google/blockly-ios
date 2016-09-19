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
open class BlockBumper: NSObject {
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
    return workspaceLayout?.config.unitFor(LayoutConfig.BlockBumpDistance).workspaceUnit ?? 0
  }

  // MARK: - Public

  /**
  Bumps the block layout belonging to a given connection away from another connection.

  - Parameter impingingConnection: The connection of the block being bumped away.
  - Parameter stationaryConnection: The connection that is being used as the source location for
  the bump.
  */
  open func bumpBlockLayoutOfConnection(
    _ impingingConnection: Connection, awayFromConnection stationaryConnection: Connection)
  {
    guard let blockLayout = impingingConnection.sourceBlock.layout,
      let blockGroupLayout = blockLayout.rootBlockGroupLayout else {
      return
    }

    let dx = stationaryConnection.position.x + bumpDistance - impingingConnection.position.x
    let dy = stationaryConnection.position.y + bumpDistance - impingingConnection.position.y
    let newPosition = WorkspacePointMake(
      blockGroupLayout.absolutePosition.x + dx,
      blockGroupLayout.absolutePosition.y + dy)
    blockGroupLayout.moveTo(workspacePosition: newPosition)
    workspaceLayout?.bringBlockGroupLayoutToFront(blockGroupLayout)
  }

  /**
   Move all neighbours of the given block layout and its sub-blocks so that they don't appear to be
   connected to the given block layout.

   - Parameter blockLayout: The `BlockLayout` to bump others away from.
   */
  open func bumpNeighboursOf(blockLayout: BlockLayout) {
    // Move this block before trying to bump others
    if let previousConnection = blockLayout.block.previousConnection {
      bumpAwayFromNeighboursBlockLayoutOf(connection: previousConnection)
    }
    if let outputConnection = blockLayout.block.outputConnection {
      bumpAwayFromNeighboursBlockLayoutOf(connection: outputConnection)
    }

    // Bump blocks away from high priority connections on this block
    for directConnection in blockLayout.block.directConnections {
      if directConnection.highPriority {
        if let connectedBlockLayout = directConnection.targetBlock?.layout {
          bumpNeighboursOf(blockLayout: connectedBlockLayout)
        }
        if let connectedShadowBlockLayout = directConnection.shadowBlock?.layout {
          bumpNeighboursOf(blockLayout: connectedShadowBlockLayout)
        }

        bumpAllBlocksNear(connection: directConnection)
      }
    }
  }

  // MARK: - Private

  /**
   Bumps a block layout belonging to a given connection away from its first neighbour.

   - Parameter connection: The connection of the block that is being bumped away.
   */
  private func bumpAwayFromNeighboursBlockLayoutOf(connection: Connection) {
    guard
      let connectionManager = workspaceLayoutCoordinator?.connectionManager,
      let rootBlockGroupLayout = connection.sourceBlock.layout?.rootBlockGroupLayout else
    {
      return
    }

    let neighbours =
      connectionManager.stationaryNeighboursFor(connection: connection, maxRadius: bumpDistance)

    for neighbour in neighbours {
      // Bump away from the first neighbour that isn't in the same block group as the target
      // connection's block group
      if neighbour.sourceBlock.layout?.rootBlockGroupLayout != rootBlockGroupLayout {
        bumpBlockLayoutOfConnection(connection, awayFromConnection: neighbour)
        return
      }
    }
  }

  /**
   Finds all connections near a given connection and bumps their blocks away.

   - Parameter connection: The connection that is at the center of the current bump operation
   */
  private func bumpAllBlocksNear(connection: Connection) {
    guard
      let connectionManager = workspaceLayoutCoordinator?.connectionManager,
      let rootBlockGroupLayout = connection.sourceBlock.layout?.rootBlockGroupLayout else
    {
      return
    }

    let neighbours =
      connectionManager.stationaryNeighboursFor(connection: connection, maxRadius: bumpDistance)

    for neighbour in neighbours {
      // Only bump blocks that aren't in the same block group as the target connection's block group
      if let neighbourLayout = neighbour.sourceBlock.layout
       , neighbourLayout.rootBlockGroupLayout != rootBlockGroupLayout
      {
        bumpBlockLayoutOfConnection(neighbour, awayFromConnection: connection)
      }
    }
  }
}
