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
   Bumps the block belonging to a given connection away from another connection.
   
   - Parameter impingingConnection: The connection of the block being bumped away.
   - Parameter stationaryConnection: The connection that is being used as the source location for
   the bump.
   */
  public func bumpBlockFromConnection(
    impingingConnection: Connection, awayFromConnection stationaryConnection: Connection)
  {
    guard let blockGroupLayout = impingingConnection.sourceBlock.layout?.rootBlockGroupLayout else {
      return
    }

    let newPosition = WorkspacePointMake(
      stationaryConnection.position.x + self.bumpDistance,
      stationaryConnection.position.y + self.bumpDistance)
    blockGroupLayout.moveToWorkspacePosition(newPosition)
    blockGroupLayout.workspaceLayout?.bringBlockGroupLayoutToFront(blockGroupLayout)
  }

  /**
   Move all neighbours of the given block layout and its sub-blocks so that they don't appear to be
   connected to the given block.

   - Parameter blockLayout: The `BlockLayout` to bump others away from.
   */
  public func bumpNeighboursOfBlockLayout(blockLayout: BlockLayout) {
    // Move this block before trying to bump others
    if let previousConnection = blockLayout.block.previousConnection {
      bumpFirstBlockNearConnection(previousConnection)
    }
    if let outputConnection = blockLayout.block.outputConnection {
      bumpFirstBlockNearConnection(outputConnection)
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

  private func bumpFirstBlockNearConnection(connection: Connection) {
    bumpBlocksNearConnection(connection, maximumBumps: 1)
  }

  private func bumpAllBlocksNearConnection(connection: Connection) {
    bumpBlocksNearConnection(connection, maximumBumps: nil)
  }

  /**
   Finds all connections near a given connection and bumps their blocks away.
   
   - Parameter connection: The connection that is at the center of the current bump operation
   - Parameter maximumBumps: If specified, the maximum number of bumps that should be performed by
   this method. If nil, no maximum is enforced and all block bumps are performed.
   */
  private func bumpBlocksNearConnection(connection: Connection, maximumBumps: Int?) {
    if maximumBumps != nil && maximumBumps! <= 0 {
      return
    }
    guard
      let connectionManager = connection.sourceBlock.layout?.workspaceLayout?.connectionManager,
      let rootBlockGroupLayout = connection.sourceBlock.layout?.rootBlockGroupLayout else
    {
      return
    }

    let neighbours =
      connectionManager.stationaryNeighboursForConnection(connection, maxRadius: self.bumpDistance)
    var totalBumps = 0

    for neighbour in neighbours {
      // Only bump blocks that aren't in the same block group as the target connection's block group
      if neighbour.sourceBlock.layout?.rootBlockGroupLayout != rootBlockGroupLayout {
        bumpBlockFromConnection(neighbour, awayFromConnection: connection)
        totalBumps += 1

        if maximumBumps != nil && totalBumps >= maximumBumps! {
          return
        }
      }
    }
  }
}
