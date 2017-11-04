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
   Event fired when a property of a block changes.
   */
  @objc(BKYEventChange)
  @objcMembers public final class Change: BlocklyEvent {

    // MARK: - Constants

    /// Value type used for indicating which element is being associated with the change event.
    public typealias Element = String

    /// Element representing a block's collapsed/expanded state.
    public static let elementCollapsed: Element = "collapsed"
    /// Element representing a block's comment property.
    public static let elementComment: Element = "comment"
    /// Element representing a block's disabled property.
    public static let elementDisabled: Element = "disabled"
    /// Element representing a block's field.
    public static let elementField: Element = "field"
    /// Element representing a block's inline property.
    public static let elementInline: Element = "inline"
    /// Element representing a block mutation.
    public static let elementMutate: Element = "mutate"

    // MARK: - Properties

    /// The event type for `BlocklyEvent.Change` objects.
    public static let EVENT_TYPE = "change"

    /// The element associated with the change event.
    public let element: Element
    /// The field name affected by this change event.
    public let fieldName: String?
    /// The old value of the element.
    public let oldValue: String?
    /// The new value of the element.
    public let newValue: String?
    /// Convenience property for evaluating `self.oldValue == "true"`
    public var oldBoolValue: Bool {
      return oldValue == "true"
    }
    /// Convenience property for evaluating `self.newValue == "true"`
    public var newBoolValue: Bool {
      return newValue == "true"
    }

    // MARK: - Initializers

    /**
     Constructs a `BlocklyEvent.Change`, signifying block's value changed.

     - parameter element: The type of element associated with the change event.
     - parameter workspaceID: The workspace ID containing the change.
     - parameter blockID: The ID string of the block affected.
     - parameter field: [Optional] The field containing the change, if the change is a field value.
       Defaults to `nil`.
     - parameter oldValue: [Optional] The original value. Defaults to `nil`.
     - parameter newValue: [Optional] The new value. Defaults to `nil`.
     */
    public init(
      element: Element, workspaceID: String, blockID: String, fieldName: String? = nil,
      oldValue: String? = nil, newValue: String? = nil)
    {
      self.element = element
      self.fieldName = fieldName
      self.oldValue = oldValue
      self.newValue = newValue
      super.init(
        type: Change.EVENT_TYPE, workspaceID: workspaceID, groupID: nil, blockID: blockID)
    }

    /**
     Constructs a `BlocklyEvent.Change` from the JSON serialized representation.

     - parameter json: The serialized JSON representation of `BlocklyEvent.Change`.
     - throws:
     `BlocklyError`: Thrown when the JSON could not be parsed into a `BlocklyEvent.Change` object.
     */
    public init(json: [String: Any]) throws {
      if let element = json[BlocklyEvent.JSON_ELEMENT] as? Element {
        self.element = element
      } else {
        throw BlocklyError(.jsonParsing,
                           "No value was specified for \"\(BlocklyEvent.JSON_ELEMENT)\".")
      }
      self.fieldName = json[BlocklyEvent.JSON_NAME] as? String
      self.oldValue = json[BlocklyEvent.JSON_OLD_VALUE] as? String
      self.newValue = json[BlocklyEvent.JSON_NEW_VALUE] as? String

      try super.init(type: BlocklyEvent.Change.EVENT_TYPE, json: json)

      if (self.blockID?.isEmpty ?? true) {
        throw BlocklyError(.jsonParsing, "\"\(BlocklyEvent.JSON_BLOCK_ID)\" must be assigned.")
      }
    }

    // MARK: - Super

    public override func toJSON() throws -> [String: Any] {
      var json = try super.toJSON()

      json["element"] = element
      if let fieldName = self.fieldName {
        json["name"] = fieldName
      }
      json["newValue"] = newValue

      return json
    }

    public override func merged(withNextChronologicalEvent event: BlocklyEvent) -> BlocklyEvent? {
      if let changeEvent = event as? BlocklyEvent.Change,
        let blockID = self.blockID,
        workspaceID == changeEvent.workspaceID &&
        groupID == changeEvent.groupID &&
        blockID == changeEvent.blockID &&
        element == changeEvent.element &&
        fieldName == changeEvent.fieldName
      {
        let event = BlocklyEvent.Change(
          element: element, workspaceID: workspaceID, blockID: blockID,
          fieldName: fieldName, oldValue: oldValue, newValue: changeEvent.newValue)
        event.groupID = groupID
        return event
      }

      return nil
    }

    public override func isDiscardable() -> Bool {
      return oldValue == newValue
    }

    // MARK: - Convenience Event Creators

    /**
     Creates a `BlocklyEvent.Change` reflecting a change in the block's comment text.

     - parameter workspace: The workspace containing the block.
     - parameter block: The block where the state changed.
     - parameter oldValue: The prior comment text.
     - parameter newValue: The updated comment text.
     - returns: The new `BlocklyEvent.Change`.
     */
    public static func commentTextEvent(
      workspace: Workspace, block: Block, oldValue: String, newValue: String) -> BlocklyEvent.Change
    {
      return BlocklyEvent.Change(element: elementComment, workspaceID: workspace.uuid,
                                 blockID: block.uuid, oldValue: oldValue, newValue: newValue)
    }

    /**
     Creates a `BlocklyEvent.Change` reflecting a change in the block's disabled state.

     - parameter workspace: The workspace containing the block.
     - parameter block: The block where the state changed.
     - returns: The new `BlocklyEvent.Change`.
     */
    public static func disabledStateEvent(
      workspace: Workspace, block: Block) -> BlocklyEvent.Change {
      return BlocklyEvent.Change(
        element: elementDisabled, workspaceID: workspace.uuid, blockID: block.uuid,
        oldValue: !block.disabled ? "true" : "false",
        newValue: block.disabled ? "true" : "false")
    }

    /**
     Creates a `BlocklyEvent.Change` reflecting a change in a field's value.

     - parameter workspace: The workspace containing the block.
     - parameter block: The block where the state changed.
     - parameter field: The field with the changed value.
     - parameter oldValue: The prior value.
     - parameter newValue: The updated value.
     - returns: The new `BlocklyEvent.Change`.
     */
    public static func fieldValueEvent(
      workspace: Workspace, block: Block, field: Field, oldValue: String, newValue: String)
      -> BlocklyEvent.Change
    {
      return BlocklyEvent.Change(
        element: elementField, workspaceID: workspace.uuid, blockID: block.uuid,
        fieldName: field.name, oldValue: oldValue, newValue: newValue)
    }

    /**
     Creates a `BlocklyEvent.Change` reflecting a change in the block's inlined inputs state.

     - parameter workspace The workspace containing the block.
     - parameter block The block where the state changed.
     - returns: The new `BlocklyEvent.Change`.
     */
    public static func inlineStateEvent(workspace: Workspace, block: Block) -> BlocklyEvent.Change {
      return BlocklyEvent.Change(
        element: elementInline, workspaceID: workspace.uuid, blockID: block.uuid,
        oldValue: (!block.inputsInline ? "true" : "false"),
        newValue: (block.inputsInline ? "true" : "false"))
    }

    /**
     Creates a `BlocklyEvent.Change` reflecting a change in the block's mutation state.

     - parameter workspace The workspace containing the block.
     - parameter block The block where the state changed.
     - parameter oldValue The serialized version of the prior mutation state.
     - parameter newValue The serialized version of the updated mutation state.
     - returns: The new `BlocklyEvent.Change`.
     */
    public static func mutateEvent(
      workspace: Workspace, block: Block, oldValue: String?, newValue: String?)
      -> BlocklyEvent.Change
    {
      return BlocklyEvent.Change(
        element: elementMutate, workspaceID: workspace.uuid, blockID: block.uuid,
        oldValue: oldValue, newValue: newValue)
    }
  }
}
