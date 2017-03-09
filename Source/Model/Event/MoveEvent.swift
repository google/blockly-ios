/*
 * Copyright 2017 Google Inc. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License")
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
 Event fired when a block is moved on the workspace, or its parent connection is changed.

 This event must be created before the block is moved to capture the original position.
 After the move has been completed in the workspace, capture the updated position or parent
 using `recordNew(forBlock:)`.
 */
@objc(BKYMoveEvent)
public final class MoveEvent: BlocklyEvent {

  // MARK: - Properties

  /// The event type for `ChangeEvent` objects.
  public static let EVENT_TYPE = "move"

  private static let JSON_NEW_COORDINATE = "newCoordinate"
  private static let JSON_NEW_INPUT_NAME = "newInputName"
  private static let JSON_NEW_PARENT_ID = "newParentId"

  /// The previous parent block ID of the target block. If `nil`, it indicates the target block was
  /// not previously connected to a parent.
  public private(set) var oldParentID: String?
  /// If `oldParentID` is not `nil`, this is the input name of the previous parent block that the
  /// target block was connected to.
  public private(set) var oldInputName: String?
  /// The previous position of the target block. If `nil`, it indicates that the target block
  /// was previously connected to a parent block.
  public private(set) var oldPosition: WorkspacePoint?

  /// The new parent block ID of the target block. If `nil`, it indicates the target block is
  /// not connected to a parent.
  public private(set) var newParentID: String?
  /// If `newParentID` is not `nil`, this is the input name of the parent block that the target
  /// block is connected to.
  public private(set) var newInputName: String?
  /// The new position of the target block. If `nil`, it indicates that the target block
  /// is connected to a parent block.
  public private(set) var newPosition: WorkspacePoint?

  // MARK: - Initializers

  /**
   Constructs a `MoveEvent` signifying the movement of a block on the workspace.

   - parameter workspace: The workspace containing the moved blocks.
   - parameter block: The root block of the move, while it is still in its original position.
   */
  public required init(workspace: Workspace, block: Block) {
    super.init(
      type: MoveEvent.EVENT_TYPE, workspaceID: workspace.uuid, groupID: nil, blockID: block.uuid)

    if let parentConnection = block.inferiorConnection?.targetConnection {
      oldParentID = parentConnection.sourceBlock?.uuid
      oldInputName = parentConnection.sourceInput?.name
    } else {
      oldPosition = block.position
    }
  }

  /**
   Constructs a `MoveEvent` from the JSON serialized representation.

   - parameter json: The serialized `MoveEvent`.
   - throws:
   `BlocklyError`: Thrown when the JSON could not be parsed into a `MoveEvent` object.
   */
  public required init(json: [String: Any]) throws {
    if let newCoordinate = json[MoveEvent.JSON_NEW_COORDINATE] as? String {

      // JSON coordinates are always integers, separated by a comma.
      let coordinates = newCoordinate.components(separatedBy: ",")
      guard coordinates.count == 2,
        let x = Int(coordinates[0]),
        let y = Int(coordinates[1]) else
      {
        throw BlocklyError(
          .jsonParsing, "Invalid \"\(MoveEvent.JSON_NEW_COORDINATE)\": \(newCoordinate)")
      }

      newPosition = WorkspacePoint(x: CGFloat(x), y: CGFloat(y))
    }

    try super.init(type: MoveEvent.EVENT_TYPE, json: json)

    if (self.blockID?.isEmpty ?? true) {
      throw BlocklyError(.jsonParsing, "\"\(BlocklyEvent.JSON_BLOCK_ID)\" must be assigned.")
    }
  }

  // MARK: - Super

  public override func toJSON() throws -> [String: Any] {
    var json = try super.toJSON()

    if let newParentID = self.newParentID {
      json[MoveEvent.JSON_NEW_PARENT_ID] = newParentID
    }

    if let newInputName = self.newInputName {
      json[MoveEvent.JSON_NEW_INPUT_NAME] = newInputName
    }

    if let newPosition = self.newPosition {
      let x = Int(floor(newPosition.x))
      let y = Int(floor(newPosition.y))
      json[MoveEvent.JSON_NEW_COORDINATE] = "\(x),\(y)"
    }

    return json
  }

  // MARK: - State Capture

  /**
   Updates the event's "new" values to capture the current state of a given block.

   - parameter block: The `Block`.
   - throws:
   `BlocklyError`: Thrown if the given block's UUID does not match the `self.blockID` that was
   originally associated with this event.
   */
  public func recordNewValues(fromBlock block: Block) throws {
    guard self.blockID == block.uuid else {
      throw BlocklyError(.illegalArgument, "Block id does not match original.")
    }

    if let parentConnection = block.inferiorConnection?.targetConnection {
      newParentID = parentConnection.sourceBlock?.uuid
      newInputName = parentConnection.sourceInput?.name
      newPosition = nil
    } else {
      newParentID = nil
      newInputName = nil
      newPosition = block.position
    }
  }
}
