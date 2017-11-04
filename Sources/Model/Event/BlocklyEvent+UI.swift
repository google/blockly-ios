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
   Event class for user interface related actions, including selecting blocks, opening/closing
   the toolbox or trash, and changing toolbox categories.
   */
  @objc(BKYEventUI)
  @objcMembers public final class UI: BlocklyEvent {

    // MARK: - Constants

    /// Value type used for indicating which element is being associated with the UI event.
    public typealias Element = String

    /// Element representing the visibility of a toolbox category.
    public static let elementCategory: Element = "category"
    /// Element representing if a block was tapped on.
    public static let elementClick: Element = "click"
    /// Element representing the visibility of a block comment.
    public static let elementCommentOpen: Element = "commentOpen"
    /// Element representing the visibility of a block mutator popover.
    public static let elementMutatorOpen: Element = "mutatorOpen"
    /// Element representing the selection state of a block.
    public static let elementSelected: Element = "selected"
    /// Element representing the visibility of the trash can folder.
    public static let elementTrashOpen: Element = "trashOpen"
    /// Element representing the visibility of a block's warning message.
    public static let elementWarningOpen: Element = "warningOpen"

    // MARK: - Properties

    /// The event type for `BlocklyEvent.UI` objects.
    public static let EVENT_TYPE = "ui"

    /// The element associated with the UI event.
    public let element: Element
    /// The old value of the element.
    public private(set) var oldValue: String?
    /// The new value of the element.
    public private(set) var newValue: String?

    // MARK: - Initializers

    /**
     Constructs a block related UI event, such as clicked, selected, comment opened, mutator
     opened, or warning opened.

     - parameter element: The UI element that changed.
     - parameter workspace: The workspace containing the changed element.
     - parameter block: The related block. `nil` for toolbox category events.
     - parameter oldValue: [Optional] The value before the event. Booleans are mapped to `true` and
     `false`. Defaults to `nil`.
     - parameter newValue: [Optional] The value after the event. Booleans are mapped to `true` and
     `false`. Defaults to `nil`.
     */
    public init(
      element: Element, workspace: Workspace, block: Block?, oldValue: String? = nil,
      newValue: String? = nil)
    {
      self.element = element
      super.init(type: BlocklyEvent.UI.EVENT_TYPE, workspaceID: workspace.uuid, groupID: nil,
                 blockID: block?.uuid)
      self.oldValue = oldValue
      self.newValue = newValue
    }

    /**
     Constructs a `BlocklyEvent.UI` from the JSON serialized representation.

     - parameter json: The serialized JSON representation of `BlocklyEvent.UI`.
     - throws:
     `BlocklyError`: Thrown when the JSON could not be parsed into a `BlocklyEvent.UI` object.
     */
    public init(json: [String: Any]) throws {
      if let element = json[BlocklyEvent.JSON_ELEMENT] as? Element {
        self.element = element
      } else {
        throw BlocklyError(.jsonParsing,
                           "No value was specified for \"\(BlocklyEvent.JSON_ELEMENT)\".")
      }

      try super.init(type: BlocklyEvent.UI.EVENT_TYPE, json: json)

      oldValue = json[BlocklyEvent.JSON_OLD_VALUE] as? String  // Rarely used.
      newValue = json[BlocklyEvent.JSON_NEW_VALUE] as? String

      // Validate data for known UI elements
      if [BlocklyEvent.UI.elementClick,
          BlocklyEvent.UI.elementCommentOpen,
          BlocklyEvent.UI.elementMutatorOpen,
          BlocklyEvent.UI.elementSelected,
          BlocklyEvent.UI.elementTrashOpen,
          BlocklyEvent.UI.elementWarningOpen].contains(element) &&
         (blockID?.isEmpty ?? true) {
        throw BlocklyError(.jsonParsing,
          "UI element \"\(element)\" requires that \"\(BlocklyEvent.JSON_BLOCK_ID)\" be assigned.")
      }

      if [BlocklyEvent.UI.elementCommentOpen,
          BlocklyEvent.UI.elementMutatorOpen,
          BlocklyEvent.UI.elementSelected,
          BlocklyEvent.UI.elementTrashOpen,
          BlocklyEvent.UI.elementWarningOpen].contains(element) &&
         (newValue?.isEmpty ?? true) {
        throw BlocklyError(.jsonParsing,
          "UI element \"\(element)\" requires that \(BlocklyEvent.JSON_NEW_VALUE)\" be assigned.")
      }
    }

    // MARK: - Super

    public override func toJSON() throws -> [String: Any] {
      var json = try super.toJSON()

      json["element"] = element
      if let newValue = self.newValue {
        json["newValue"] = newValue
      }
      // Old value is not included to reduce size over network.

      return json
    }

    // MARK: - Convenience Event Creators

    /**
     Creates a `BlocklyEvent.UI` reflecting when a block has been clicked, inside a given workspace.

     - parameter workspace: The workspace containing the block.
     - parameter block: The block that was clicked.
     - returns: The new `BlocklyEvent.UI`.
     */
    public static func blockClickedEvent(workspace: Workspace, block: Block) -> BlocklyEvent.UI {
      return BlocklyEvent.UI(element: elementClick, workspace: workspace, block: block)
    }

    /**
     Creates a `BlocklyEvent.UI` reflecting the change of a block's selected state, inside a given
     workspace.

     - parameter workspace: The workspace containing the block.
     - parameter block: The block that was selected.
     - parameter selectedBefore: `true` if the block was previously selected. `false` otherwise.
     - parameter selectedAfter: `true` if the block is currently selected. `false` otherwise.
     - returns: The new `BlocklyEvent.UI`.
     */
    public static func blockSelectedEvent(
      workspace: Workspace, block: Block, selectedBefore: Bool, selectedAfter: Bool)
      -> BlocklyEvent.UI
    {
      return BlocklyEvent.UI(element: elementSelected, workspace: workspace, block: block,
                             oldValue: selectedBefore ? "true" : "false",
                             newValue: selectedAfter ? "true" : "false")
    }

    /**
     Creates a `BlocklyEvent.UI` reflecting the change of a block's warning message visibility,
     inside a given workspace.

     - parameter workspace: The workspace containing the block.
     - parameter block: The target block.
     - parameter openedBefore: `true` if the block's warning was previously visible. `false`
     otherwise.
     - parameter openedAfter: `true` if the block's warning is currently visible. `false` otherwise.
     - returns: The new `BlocklyEvent.UI`.
     */
    public static func blockWarningEvent(
      workspace: Workspace, block: Block, openedBefore: Bool, openedAfter: Bool) -> BlocklyEvent.UI
    {
      return BlocklyEvent.UI(element: elementWarningOpen, workspace: workspace, block: block,
                             oldValue: openedBefore ? "true" : "false",
                             newValue: openedAfter ? "true" : "false")
    }

    /**
     Creates a `BlocklyEvent.UI` reflecting the change of a block comment's visibility, inside
     a given workspace.

     - parameter workspace: The workspace containing the block.
     - parameter block: The target block.
     - parameter openedBefore: `true` if the block's comment was previously visible. `false`
     otherwise.
     - parameter openedAfter: `true` if the block's comment is currently visible. `false` otherwise.
     - returns: The new `BlocklyEvent.UI`.
     */
    public static func commentEvent(
      workspace: Workspace, block: Block, openedBefore: Bool, openedAfter: Bool) -> BlocklyEvent.UI
    {
      return BlocklyEvent.UI(element: elementCommentOpen, workspace: workspace, block: block,
                             oldValue: openedBefore ? "true" : "false",
                             newValue: openedAfter ? "true" : "false")
    }

    /**
     Creates a `BlocklyEvent.UI` reflecting the change of a block's mutator popover's visibility,
     inside a given workspace.

     - parameter workspace: The workspace containing the block.
     - parameter block: The target block.
     - parameter openedBefore: `true` if the block's mutator popover was previously visible. `false`
     otherwise.
     - parameter openedAfter: `true` if the block's mutator popover is currently visible. `false`
     otherwise.
     - returns: The new `BlocklyEvent.UI`.
     */
    public static func mutatorPopoverEvent(
      workspace: Workspace, block: Block, openedBefore: Bool, openedAfter: Bool) -> BlocklyEvent.UI
    {
      return BlocklyEvent.UI(element: elementMutatorOpen, workspace: workspace, block: block,
                             oldValue: openedBefore ? "true" : "false",
                             newValue: openedAfter ? "true" : "false")
    }

    /**
     Creates a `BlocklyEvent.UI` reflecting the currently open toolbox category.

     - parameter workspace: The workspace of the toolbox category.
     - parameter oldValue: The previous category that was open, or `nil` if no category was open.
     - parameter newValue: The current category that is open, or `nil` if no category is open.
     - returns: The new `BlocklyEvent.UI`.
     */
    public static func toolboxCategoryEvent(
      workspace: Workspace, oldValue: String?, newValue: String?) -> BlocklyEvent.UI
    {
      return BlocklyEvent.UI(
        element: elementCategory,
        workspace: workspace,
        block: nil,
        oldValue: oldValue,
        newValue: newValue)
    }
  }
}
