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

/**
 * Base class for all Blockly events.
 */
@objc(BKYEvent)
@objcMembers open class BlocklyEvent: NSObject {

  // MARK: - Properties

  /// Data type used for specifying a type of BlocklyEvent.
  public typealias EventType = String

  // JSON serialization attributes.  See also TYPENAME_ and ELEMENT_ constants for ids.
  internal static let JSON_BLOCK_ID = "blockId"
  internal static let JSON_ELEMENT = "element"
  internal static let JSON_GROUP_ID = "groupId"
  internal static let JSON_IDS = "ids"
  internal static let JSON_NAME = "name"
  internal static let JSON_NEW_VALUE = "newValue"
  internal static let JSON_OLD_VALUE = "oldValue"  // Rarely used.
  internal static let JSON_TYPE = "type"
  internal static let JSON_WORKSPACE_ID = "workspaceId" // Rarely used.
  internal static let JSON_XML = "xml"

  /// The type of this event.
  open let type: EventType
  /// The ID for the workspace that triggered this event.
  open let workspaceID: String
  /// The ID for the group of related events.
  open var groupID: String?
  /// The ID of the primary or root affected block.
  open let blockID: String?

  // MARK: - Initializers

  /**
   Creates a `BlocklyEvent`.

   - parameter type: The `EventType`.
   - parameter workspaceID: The ID string of the Blockly workspace.
   - parameter groupID: The ID string of the event group. Usually `nil` for local events (assigned
     later) and non-`nil` for remote events.
   - parameter blockID: The ID string of the block affected. `nil` for a few event types
     (e.g. toolbox category).
   */
  public init(type: EventType, workspaceID: String, groupID: String?, blockID: String?) {
    self.type = type
    self.workspaceID = workspaceID
    self.groupID = groupID
    self.blockID = blockID
  }

  /**
   Constructs a `BlocklyEvent` with base attributes assigned from JSON.

   - parameter type: The type of the event.
   - parameter json: The JSON object with event attribute values.
   - throws:
   `BlocklyError`: Thrown if `BlocklyEvent.JSON_WORKSPACE_ID` is not specified as a key within the
   given `json`.
   */
  public init(type: EventType, json: [String: Any]) throws {
    self.type = type
    if let workspaceID = json[BlocklyEvent.JSON_WORKSPACE_ID] as? String {
      self.workspaceID = workspaceID
    } else {
      throw BlocklyError(.jsonParsing,
                         "Must supply \"\(BlocklyEvent.JSON_WORKSPACE_ID)\" in JSON event")
    }
    self.groupID = json[BlocklyEvent.JSON_GROUP_ID] as? String
    self.blockID = json[BlocklyEvent.JSON_BLOCK_ID] as? String
  }

  // MARK: - JSON Serialization

  /**
   Returns a JSON dictionary serialization of the event.

   - returns: A JSON dictionary serialization of the event.
   - throws:
   `BlocklyError`: Thrown if the event could not be serialized.
   */
  open func toJSON() throws -> [String: Any] {
    var json = [String: Any]()
    json[BlocklyEvent.JSON_TYPE] = type
    json[BlocklyEvent.JSON_WORKSPACE_ID] = workspaceID

    if let blockID = self.blockID {
      json[BlocklyEvent.JSON_BLOCK_ID] = blockID
    }

    if let groupID = self.groupID {
      json[BlocklyEvent.JSON_GROUP_ID] = groupID
    }

    return json
  }

  /**
   Calls `self.toJSON()` and returns a string representation of that JSON dictionary.

   - returns: A JSON string representation of the event.
   - throws:
   `BlocklyError`: Thrown if the event could not be serialized.
   */
  public final func toJSONString() throws -> String {
    let data = try JSONSerialization.data(withJSONObject: toJSON())
    if let jsonString = String(data: data, encoding: .utf8) {
      return jsonString
    } else {
      throw BlocklyError(.jsonSerialization, "Could not serialize `self.toJSON()` into a String.")
    }
  }

  // MARK: - Filtering Events

  /**
   This method indicates if this event can be discarded so it doesn't get fired. An example of when
   this might be true is for a `BlocklyEvent.Change` where no change is recorded between old and
   new values.

   The default implementation of this method returns `false`. Subclasses may override this method
   to specify individual behavior of when the event can be discarded, based on its current state.

   - returns: `true` if this event can be discarded, or `false` otherwise.
   */
  open func isDiscardable() -> Bool {
    return false
  }

  /**
   Attempts to merge this event with the next chronological event that was fired, and returns the
   result. If the events are incompatible and cannot be merged, `nil` is returned.

   The default implementation of this method returns `nil`. Subclasses may override this method
   to specify individual merge behavior with other events.

   - parameter event: The next chronological event that was fired after this event.
   - returns: If the events are compatible, this returns a new `BlocklyEvent` that is the result
   of merging the two events together. Otherwise, `nil` is returned.
   */
  open func merged(withNextChronologicalEvent event: BlocklyEvent) -> BlocklyEvent? {
    return nil
  }
}

extension Array where Element: BlocklyEvent {
  /**
   Returns an array that filters any events that can be discarded (by checking `isDiscardable()`).

   - returns: An array filtered of discardable events.
   */
  public func filterDiscardable() -> [BlocklyEvent] {
    return self.filter({ !$0.isDiscardable() })
  }

  /**
   Merges all events in the array, from beginning to end, by repeatedly calling
   `merged(withNextChronologicalEvent:)` on adjacent events.

   - returns: An array of merged events.
   - note: This method assumes that the array is sorted in chronological
   order.
   */
  public func merged() -> [BlocklyEvent] {
    var mergedEvents = self

    var i = 0
    while (i + 1) < mergedEvents.count {
      let event1 = mergedEvents[i]
      let event2 = mergedEvents[i + 1]

      if let mergedEvent = event1.merged(withNextChronologicalEvent: event2) {
        // Replace event1 and event2 with merged event. Don't iterate `i` since this new merged
        // event could be merged with the next event.
        mergedEvents.removeSubrange(i...(i + 1))
        mergedEvents.insert(mergedEvent as! Element, at: i)
      } else {
        // Events couldn't be merged, iterate to next event
        i += 1
      }
    }

    return mergedEvents
  }
}
