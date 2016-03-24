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
public class BlockBumper: NSObject {
  // MARK: - Properties

  /// The X and Y amount to bump blocks away from each other, specified as a Workspace coordinate
  /// system unit
  public var bumpDistance: CGFloat

  // MARK: - Initializers

  public init(bumpDistance: CGFloat) {
    self.bumpDistance = bumpDistance
  }

  // MARK: - Public

  /**
   Bumps a given block layout away from a given connection.

   - Parameter blockLayout: The block layout to bump away.
   - Parameter stationaryConnection: The connection that the block should be bumped away from.
   */
  public func bumpBlockLayout(blockLayout: BlockLayout,
    awayFromConnection stationaryConnection: Connection)
  {
    guard let rootBlockGroupLayout = blockLayout.rootBlockGroupLayout else {
      return
    }

    let newPosition = WorkspacePointMake(
      stationaryConnection.position.x + self.bumpDistance,
      stationaryConnection.position.y + self.bumpDistance)
    rootBlockGroupLayout.moveToWorkspacePosition(newPosition)
    rootBlockGroupLayout.workspaceLayout?.bringBlockGroupLayoutToFront(rootBlockGroupLayout)
  }

  /**
   Move all neighbours of the given block layout and its sub-blocks so that they don't appear to be
   connected to the given block layout.

   - Parameter blockLayout: The `BlockLayout` to bump others away from.
   */
  public func bumpNeighboursOfBlockLayout(blockLayout: BlockLayout) {
    // Move this block before trying to bump others
    if let previousConnection = blockLayout.block.previousConnection {
      bumpBlockLayout(blockLayout, awayFromNeighbourOfConnection: previousConnection)
    }
    if let outputConnection = blockLayout.block.outputConnection {
      bumpBlockLayout(blockLayout, awayFromNeighbourOfConnection: outputConnection)
    }

    // Bump blocks away from high priority connections on this block
    for directConnection in blockLayout.block.directConnections {
      if directConnection.highPriority {
        if let connectedBlockLayout = directConnection.targetBlock?.layout {
          bumpNeighboursOfBlockLayout(connectedBlockLayout)
        }

        bumpAllBlocksNearConnection(directConnection)
      }
    }
  }

  // MARK: - Private

  /**
  Bumps a given block layout away from the first neighbour of a given connection.

  - Parameter connection: The connection connected to the block that is being bumped away.
  */
  private func bumpBlockLayout(blockLayout: BlockLayout,
    awayFromNeighbourOfConnection connection: Connection)
  {
    guard
      let connectionManager = blockLayout.workspaceLayout?.connectionManager,
      let rootBlockGroupLayout = blockLayout.rootBlockGroupLayout else
    {
      return
    }

    let neighbours =
      connectionManager.stationaryNeighboursForConnection(connection, maxRadius: self.bumpDistance)

    for neighbour in neighbours {
      // Bump away from the first neighbour that isn't in the same block group as the target
      // connection's block group
      if neighbour.sourceBlock.layout?.rootBlockGroupLayout != rootBlockGroupLayout {
        bumpBlockLayout(blockLayout, awayFromConnection: neighbour)
        return
      }
    }
  }

  /**
   Finds all connections near a given connection and bumps their blocks away.

   - Parameter connection: The connection that is at the center of the current bump operation
   */
  private func bumpAllBlocksNearConnection(connection: Connection) {
    guard
      let connectionManager = connection.sourceBlock.layout?.workspaceLayout?.connectionManager,
      let rootBlockGroupLayout = connection.sourceBlock.layout?.rootBlockGroupLayout else
    {
      return
    }

    let neighbours =
      connectionManager.stationaryNeighboursForConnection(connection, maxRadius: self.bumpDistance)

    for neighbour in neighbours {
      // Only bump blocks that aren't in the same block group as the target connection's block group
      if let neighbourLayout = neighbour.sourceBlock.layout
       where neighbourLayout.rootBlockGroupLayout != rootBlockGroupLayout
      {
        bumpBlockLayout(neighbourLayout, awayFromConnection: connection)
      }
    }
  }
}
