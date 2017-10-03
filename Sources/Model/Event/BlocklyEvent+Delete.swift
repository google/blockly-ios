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
   Event fired when a block is removed from the workspace.
   */
  @objc(BKYEventDelete)
  @objcMembers public final class Delete: BlocklyEvent {

    // MARK: - Properties

    /// The event type for `BlocklyEvent.Delete` objects.
    public static let EVENT_TYPE = "delete"

    /// The XML serialization of all blocks deleted by this event.
    public let oldXML: String

    /// The list of all block ids for all blocks deleted by this event.
    public let blockIDs: [String]

    // MARK: - Initializers

    /**
     Constructs a `BlocklyEvent.Delete`, signifying the removal of a block from the workspace.

     - parameter workspace: The workspace containing the deletion.
     - parameter block: The deleted block (or to-be-deleted block), with all children attached.
     - throws:
     `BlocklyError`: Thrown if the given block tree could not be serialized into xml.
     */
    public init(workspace: Workspace, block: Block) throws {
      oldXML = try block.toXML()
      blockIDs = block.allBlocksForTree().map { $0.uuid }

      super.init(
        type: Delete.EVENT_TYPE, workspaceID: workspace.uuid, groupID: nil, blockID: block.uuid)
    }

    /**
     Constructs a `BlocklyEvent.Delete` from the JSON serialized representation.

     - parameter json: The serialized JSON representation of `BlocklyEvent.Delete`.
     - throws:
     `BlocklyError`: Thrown when the JSON could not be parsed into a `BlocklyEvent.Delete` object.
     */
    public init(json: [String: Any]) throws {
      oldXML = json[BlocklyEvent.JSON_OLD_VALUE] as? String ?? "" // Not usually used.
      blockIDs = json[BlocklyEvent.JSON_IDS] as? [String] ?? []

      try super.init(type: BlocklyEvent.Delete.EVENT_TYPE, json: json)

      if (self.blockID?.isEmpty ?? true) {
        throw BlocklyError(.jsonParsing, "\"\(BlocklyEvent.JSON_BLOCK_ID)\" must be assigned.")
      }
    }

    // MARK: - Super

    public override func toJSON() throws -> [String: Any] {
      var json = try super.toJSON()
      json["ids"] = blockIDs
      return json
    }
  }
}
