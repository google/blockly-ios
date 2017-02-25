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
 Event fired when a property of a block changes.
 */
@objc(BKYChangeEvent)
public final class ChangeEvent: BlocklyEvent {

  // MARK: - Constants

  /// Possible elements that can be associated with a `ChangeEvent`.
  @objc(BKYChangeEventElement)
  public enum Element: Int {
    case collapsed = 1,
    comment,
    disabled,
    field,
    inline,
    mutate

    fileprivate static let stringMapping = [
      collapsed: "collapsed",
      comment: "comment",
      disabled: "disabled",
      field: "field",
      inline: "inline",
      mutate: "mutate"
    ]

    public var stringValue: String {
      return Element.stringMapping[self]!
    }

    internal init?(string: String) {
      guard let value = Element.stringMapping.bky_anyKeyForValue(string) else {
        return nil
      }
      self = value
    }
  }

  // MARK: - Properties

  /// The event type for `ChangeEvent` objects.
  public static let EVENT_TYPE = "change"

  /// The element associated with the change event.
  public let element: Element
  /// The field name affected by this change event.
  public let fieldName: String?
  /// The old value of the element.
  public let oldValue: String?
  /// The new value of the element.
  public let newValue: String?

  // MARK: - Initializers

  /**
   Constructs a `ChangeEvent`, signifying block's value changed.

   - parameter workspace: The workspace containing the change.
   - parameter block: The block containing the change.
   - parameter field: [Optional] The field containing the change, if the change is a field value.
     Defaults to `nil`.
   - parameter oldValue: [Optional] The original value. Defaults to `nil`.
   - parameter newValue: [Optional] The new value. Defaults to `nil`.
   */
  public required init(element: Element, workspace: Workspace, block: Block,
               field: Field? = nil, oldValue: String? = nil, newValue: String? = nil)
  {
    self.element = element
    self.fieldName = field?.name
    self.oldValue = oldValue
    self.newValue = newValue
    super.init(
      type: ChangeEvent.EVENT_TYPE, workspaceID: workspace.uuid, groupID: nil, blockID: block.uuid)
  }

  /**
   Constructs a `ChangeEvent` from the JSON serialized representation.

   - parameter json: The serialized `ChangeEvent`.
   - throws:
   `BlocklyError`: Thrown when the JSON could not be parsed into a `ChangeEvent` object.
   */
  public required init(json: [String: Any]) throws {
    if let element = Element(string: json[BlocklyEvent.JSON_ELEMENT] as? String ?? "") {
      self.element = element
      self.fieldName = json[BlocklyEvent.JSON_NAME] as? String
    } else {
      throw BlocklyError(.jsonParsing, "Invalid change element \"\(BlocklyEvent.JSON_BLOCK_ID)\".")
    }
    self.oldValue = json[BlocklyEvent.JSON_OLD_VALUE] as? String
    self.newValue = json[BlocklyEvent.JSON_NEW_VALUE] as? String

    try super.init(type: ChangeEvent.EVENT_TYPE, json: json)

    if (self.blockID?.isEmpty ?? true) {
      throw BlocklyError(.jsonParsing, "\"\(BlocklyEvent.JSON_BLOCK_ID)\" must be assigned.")
    }
  }


  /**
   Creates a `ChangeEvent` reflecting a change in the block's comment text.

   - parameter workspace: The workspace containing the block.
   - parameter block: The block where the state changed.
   - parameter oldValue: The prior comment text.
   - parameter newValue: The updated comment text.
   - returns: The new `ChangeEvent`.
   */
  public static func commentTextEvent(
    workspace: Workspace, block: Block, oldValue: String, newValue: String) -> ChangeEvent
  {
    return ChangeEvent(
      element: .comment, workspace: workspace, block: block, oldValue: oldValue, newValue: newValue)
  }

  /**
   Creates a `ChangeEvent` reflecting a change in the block's disabled state.

   - parameter workspace: The workspace containing the block.
   - parameter block: The block where the state changed.
   - returns: The new `ChangeEvent`.
   */
  public static func disabledStateEvent(workspace: Workspace, block: Block) -> ChangeEvent {
    return ChangeEvent(element: .disabled, workspace: workspace, block: block,
                       oldValue: !block.disabled ? "true" : "false",
                       newValue: block.disabled ? "true" : "false")
  }

  /**
   Creates a `ChangeEvent` reflecting a change in a field's value.

   - parameter workspace: The workspace containing the block.
   - parameter block: The block where the state changed.
   - parameter field: The field with the changed value.
   - parameter oldValue: The prior value.
   - parameter newValue: The updated value.
   - returns: The new `ChangeEvent`.
   */
  public static func fieldValueEvent(
    workspace: Workspace, block: Block, field: Field, oldValue: String, newValue: String)
    -> ChangeEvent
  {
    return ChangeEvent(element: .field, workspace: workspace, block: block,
                       field: field, oldValue: oldValue, newValue: newValue)
  }

  /**
   Creates a `ChangeEvent` reflecting a change in the block's inlined inputs state.

   - parameter workspace The workspace containing the block.
   - parameter block The block where the state changed.
   - returns: The new `ChangeEvent`.
   */
  public static func inlineStateEvent(workspace: Workspace, block: Block) -> ChangeEvent {
    return ChangeEvent(element: .inline, workspace: workspace, block: block,
                       oldValue: (!block.inputsInline ? "true" : "false"),
                       newValue: (block.inputsInline ? "true" : "false"))
  }

  /**
   Creates a `ChangeEvent` reflecting a change in the block's mutation state.

   - parameter workspace The workspace containing the block.
   - parameter block The block where the state changed.
   - parameter oldValue The serialized version of the prior mutation state.
   - parameter newValue The serialized version of the updated mutation state.
   - returns: The new `ChangeEvent`.
   */
  public static func mutateEvent(
    workspace: Workspace, block: Block, oldValue: String?, newValue: String?) -> ChangeEvent
  {
    return ChangeEvent(
      element: .mutate, workspace: workspace, block: block, oldValue: oldValue, newValue: newValue)
  }

  // MARK: - Super

  public override func toJSON() throws -> [String: Any] {
    var json = try super.toJSON()

    json["element"] = element.stringValue
    if let fieldName = self.fieldName {
      json["name"] = fieldName
    }
    json["newValue"] = newValue

    return json
  }
}
