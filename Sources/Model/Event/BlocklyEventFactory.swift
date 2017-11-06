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
 Factory for creating `BlocklyEvent` objects from JSON data.

 This class is designed as a singleton instance, accessible via
 `BlocklyEventFactory.shared`.
 */
@objc(BKYEventFactory)
@objcMembers open class BlocklyEventFactory: NSObject {

  // MARK: - Closures

  /// Closure for returning a `BlocklyEvent` from a JSON dictionary.
  public typealias Creator = (_ json: [String: Any]) throws -> BlocklyEvent

  // MARK: - Properties

  /// Shared instance.
  public static var shared = BlocklyEventFactory()

  /// Mapping of event types to creation closures.
  private var _creators = Dictionary<BlocklyEvent.EventType, Creator>()

  // MARK: - Initializers

  /**
   A singleton instance for this class is accessible via `BlocklyEventFactory.shared.`
   */
  private override init() {
    super.init()

    registerCreator(forEventType: BlocklyEvent.Change.EVENT_TYPE) { (json) -> BlocklyEvent in
      return try BlocklyEvent.Change(json: json)
    }
    registerCreator(forEventType: BlocklyEvent.Create.EVENT_TYPE) { (json) -> BlocklyEvent in
      return try BlocklyEvent.Create(json: json)
    }
    registerCreator(forEventType: BlocklyEvent.Delete.EVENT_TYPE) { (json) -> BlocklyEvent in
      return try BlocklyEvent.Delete(json: json)
    }
    registerCreator(forEventType: BlocklyEvent.Move.EVENT_TYPE) { (json) -> BlocklyEvent in
      return try BlocklyEvent.Move(json: json)
    }
    registerCreator(forEventType: BlocklyEvent.UI.EVENT_TYPE) { (json) -> BlocklyEvent in
      return try BlocklyEvent.UI(json: json)
    }
  }

  // MARK: - Creator Registration

  /**
   Registers a creation closure to use for a given event type, when a new `BlocklyEvent`
   instance is requested via `makeBlocklyEvent(fromJSON:)`.

   - parameter eventType: The `BlocklyEvent.EventType` that the `creator` should be mapped to.
   - parameter creator: The `Creator` that will be used for `eventType`.
   */
  open func registerCreator(
    forEventType eventType: BlocklyEvent.EventType, creator: @escaping Creator)
  {
    _creators[eventType] = creator
  }

  /**
   Unregisters the creation closure for a given event type.

   - parameter eventType: The `BlocklyEvent.EventType`
   */
  open func unregisterCreator(forEventType eventType: BlocklyEvent.EventType) {
    _creators.removeValue(forKey: eventType)
  }

  /**
   Returns a new `BlocklyEvent` using given JSON data. The `BlocklyEvent` itself is created by
   finding the `BlocklyEvent.EventType` that is associated with `json[BlocklyEvent.JSON_TYPE]` and
   executing the registered creation closure for that event type.

   - parameter json: The JSON data.
   - returns: A new `BlocklyEvent` instance.
   - throws:
   `BlocklyError`: Thrown if no registered creation closure could be found for the key or if the
   `BlocklyEvent` could not be created for the JSON data.
   */
  open func makeBlocklyEvent(fromJSON json: [String: Any]) throws -> BlocklyEvent {
    guard let eventType = json[BlocklyEvent.JSON_TYPE] as? BlocklyEvent.EventType else {
      throw BlocklyError(.jsonDataMissing,
                         "Missing valid \"\(BlocklyEvent.JSON_TYPE)\" from JSON data.")
    }
    guard let closure = _creators[eventType] else {
      throw BlocklyError(.jsonDataMissing, "Could not find creator for event type \"\(eventType)\"")
    }

    return try closure(json)
  }
}
