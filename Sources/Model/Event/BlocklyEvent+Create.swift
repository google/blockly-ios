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
   Event fired when a block is added to the workspace, possibly containing other child blocks
   and next blocks.
   */
  @objc(BKYEventCreate)
  @objcMembers public final class Create: BlocklyEvent {

    // MARK: - Properties

    /// The event type for `BlocklyEvent.Create` objects.
    public static let EVENT_TYPE = "create"

    /// The XML serialization of all blocks created by this event.
    public let xml: String

    /// The list of block ids for all blocks created by this event.
    public let blockIDs: [String]

    // MARK: - Initializers

    /**
     Constructs a `BlocklyEvent.Create` for the given block.

     - parameter workspace: The workspace containing the new block.
     - parameter block: The newly created block.
     - throws:
     `BlocklyError`: Thrown if the given block tree could not be serialized into xml.
     */
    public init(workspace: Workspace, block: Block) throws {
      xml = try block.toXML()
      blockIDs = block.allBlocksForTree().map { $0.uuid }

      super.init(
        type: Create.EVENT_TYPE, workspaceID: workspace.uuid, groupID: nil, blockID: block.uuid)
    }

    /**
     Constructs a `BlocklyEvent.Create` from the JSON serialized representation.

     - parameter json: The serialized JSON representation of `BlocklyEvent.Create`.
     - throws:
     `BlocklyError`: Thrown when the JSON could not be parsed into a `BlocklyEvent.Create` object.
     */
    public init(json: [String: Any]) throws {
      xml = json[BlocklyEvent.JSON_XML] as? String ?? ""
      blockIDs = json[BlocklyEvent.JSON_IDS] as? [String] ?? []
      try super.init(type: BlocklyEvent.Create.EVENT_TYPE, json: json)

      if (self.blockID?.isEmpty ?? true) {
        throw BlocklyError(.jsonParsing, "\"\(BlocklyEvent.JSON_BLOCK_ID)\" must be assigned.")
      }
    }

    // MARK: - Super

    public override func toJSON() throws -> [String: Any] {
      var json = try super.toJSON()
      json["xml"] = xml
      json["ids"] = blockIDs
      return json
    }
  }
}
