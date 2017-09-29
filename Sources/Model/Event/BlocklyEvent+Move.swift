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

extension BlocklyEvent {
  /**
   Event fired when a block is moved on the workspace, or its parent connection is changed.

   This event must be created before the block is moved to capture the original position.
   After the move has been completed in the workspace, capture the updated position or parent
   using `recordNew(forBlock:)`.
   */
  @objc(BKYEventMove)
  @objcMembers public final class Move: BlocklyEvent {

    // MARK: - Properties

    /// The event type for `BlocklyEvent.Move` objects.
    public static let EVENT_TYPE = "move"

    private static let JSON_NEW_COORDINATE = "newCoordinate"
    private static let JSON_NEW_INPUT_NAME = "newInputName"
    private static let JSON_NEW_PARENT_ID = "newParentId"

    /// The previous parent block ID of the target block. If `nil`, it indicates the target block
    /// was not previously connected to a parent.
    public fileprivate(set) var oldParentID: String?
    /// If `oldParentID` is not `nil`, this is the input name of the previous parent block that the
    /// target block was connected to.
    public fileprivate(set) var oldInputName: String?
    /// The previous position of the target block. If `nil`, it indicates that the target block
    /// was previously connected to a parent block.
    public fileprivate(set) var oldPosition: WorkspacePoint?

    /// The new parent block ID of the target block. If `nil`, it indicates the target block is
    /// not connected to a parent.
    public var newParentID: String?
    /// If `newParentID` is not `nil`, this is the input name of the parent block that the target
    /// block is connected to.
    public var newInputName: String?
    /// The new position of the target block. If `nil`, it indicates that the target block
    /// is connected to a parent block.
    public var newPosition: WorkspacePoint?

    // MARK: - Initializers

    /**
     Constructs a `BlocklyEvent.Move` signifying the movement of a block on the workspace.

     - parameter workspaceID: The ID of the workspace containing the moved blocks.
     - parameter blockID: The ID of the root block that will move.
     - parameter oldParentID: The value for `self.oldParentID`.
     - parameter oldInputName: The value for `self.oldInputName`.
     - parameter oldPosition: The value for `self.oldPosition`.
     */
    public init(
      workspaceID: String, blockID: String, oldParentID: String?, oldInputName: String?,
      oldPosition: WorkspacePoint?) {
      self.oldParentID = oldParentID
      self.oldInputName = oldInputName
      self.oldPosition = oldPosition
      super.init(type: Move.EVENT_TYPE, workspaceID: workspaceID, groupID: nil, blockID: blockID)
    }

    /**
     Constructs a `BlocklyEvent.Move` from the JSON serialized representation.

     - parameter json: The serialized JSON representation of `BlocklyEvent.Move`.
     - throws:
     `BlocklyError`: Thrown when the JSON could not be parsed into a `BlocklyEvent.Move` object.
     */
    public init(json: [String: Any]) throws {
      if let newCoordinate = json[BlocklyEvent.Move.JSON_NEW_COORDINATE] as? String {

        // JSON coordinates are always integers, separated by a comma.
        let coordinates = newCoordinate.components(separatedBy: ",")
        guard coordinates.count == 2,
          let x = Int(coordinates[0]),
          let y = Int(coordinates[1]) else
        {
          throw BlocklyError(
            .jsonParsing, "Invalid \"\(BlocklyEvent.Move.JSON_NEW_COORDINATE)\": \(newCoordinate)")
        }

        newPosition = WorkspacePoint(x: CGFloat(x), y: CGFloat(y))
      }

      try super.init(type: BlocklyEvent.Move.EVENT_TYPE, json: json)

      if (self.blockID?.isEmpty ?? true) {
        throw BlocklyError(.jsonParsing, "\"\(BlocklyEvent.JSON_BLOCK_ID)\" must be assigned.")
      }
    }

    /**
     Constructs a `BlocklyEvent.Move` signifying the movement of a block on the workspace. The
     current positional values of the block are recorded as the "old" values for the event.

     - parameter workspace: The workspace containing the moved blocks.
     - parameter block: The root block, while it is still in its original position.
     */
    public convenience init(workspace: Workspace, block: Block) {
      var oldParentID: String?
      var oldInputName: String?
      var oldPosition: WorkspacePoint?

      if let parentConnection = block.inferiorConnection?.targetConnection {
        oldParentID = parentConnection.sourceBlock?.uuid
        oldInputName = parentConnection.sourceInput?.name
      } else {
        oldPosition = block.position
      }
      self.init(workspaceID: workspace.uuid, blockID: block.uuid,
                oldParentID: oldParentID, oldInputName: oldInputName, oldPosition: oldPosition)
    }

    // MARK: - Super

    public override func toJSON() throws -> [String: Any] {
      var json = try super.toJSON()

      if let newParentID = self.newParentID {
        json[BlocklyEvent.Move.JSON_NEW_PARENT_ID] = newParentID
      }

      if let newInputName = self.newInputName {
        json[BlocklyEvent.Move.JSON_NEW_INPUT_NAME] = newInputName
      }

      if let newPosition = self.newPosition {
        let x = Int(floor(newPosition.x))
        let y = Int(floor(newPosition.y))
        json[BlocklyEvent.Move.JSON_NEW_COORDINATE] = "\(x),\(y)"
      }

      return json
    }

    public override func merged(withNextChronologicalEvent event: BlocklyEvent) -> BlocklyEvent? {
      if let moveEvent = event as? BlocklyEvent.Move,
        let blockID = self.blockID,
        workspaceID == moveEvent.workspaceID &&
        groupID == moveEvent.groupID &&
        blockID == moveEvent.blockID
      {
        let mergedEvent = BlocklyEvent.Move(
          workspaceID: workspaceID, blockID: blockID, oldParentID: oldParentID,
          oldInputName: oldInputName, oldPosition: oldPosition)
        mergedEvent.groupID = groupID
        mergedEvent.newParentID = moveEvent.newParentID
        mergedEvent.newInputName = moveEvent.newInputName
        mergedEvent.newPosition = moveEvent.newPosition
        return mergedEvent
      }

      return nil
    }

    public override func isDiscardable() -> Bool {
      return oldParentID == newParentID &&
        oldInputName == newInputName &&
        oldPosition == newPosition
    }

    // MARK: - Capturing State

    /**
     Updates the event's "new" values to capture the current state of a given block.

     - note: If the given block is `nil` or its UUID doesn't match the event's `blockID`, then no
     values are captured.
     - parameter block: The `Block` to capture.
     */
    public func recordNewValues(forBlock block: Block?) {
      guard let block = block, blockID == block.uuid else {
        // The block ID's don't match. Do nothing.
        return
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

    /**
     Helper method for automatically capturing a `BlocklyEvent.Move` event for a given block,
     based on its state before and after running a closure. This event is then added to the
     pending events queue on `EventManager.shared`.

     - parameter workspace: The `Workspace` that contains `block`.
     - parameter block: The `Block` whose state should be captured.
     - parameter closure: A closure to execute.
     */
    static func captureMoveEvent(workspace: Workspace, block: Block, closure: () throws -> Void)
      rethrows {
      let event = BlocklyEvent.Move(workspace: workspace, block: block)
      try closure()
      event.recordNewValues(forBlock: block)
      EventManager.shared.addPendingEvent(event)
    }
  }
}
