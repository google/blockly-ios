/*
* Copyright 2015 Google Inc. All Rights Reserved.
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

// MARK: -

/**
 Abstract class for storing information on how to render and position a `Block` on-screen.
 */
@objc(BKYBlockLayout)
@objcMembers open class BlockLayout: Layout {
  // MARK: - Static Properties

  /// Flag that should be used when `self.highlighted` has been updated
  public static let Flag_UpdateHighlight = LayoutFlag(0)
  /// Flag that should be used when `self.visible` has been updated
  public static let Flag_UpdateVisible = LayoutFlag(1)

  /// Flag that should be used when any direct connection on this block has updated its highlight
  /// value
  public static let Flag_UpdateConnectionHighlight = LayoutFlag(2)

  // MARK: - Properties

  /// The `Block` to layout.
  public final let block: Block

  /// The corresponding layout objects for `self.block.inputs[]`
  open fileprivate(set) var inputLayouts = [InputLayout]()

  /// The corresponding layout object for `self.block.mutator`
  open var mutatorLayout: MutatorLayout? = nil {
    didSet {
      if let oldLayout = oldValue {
        removeChildLayout(oldLayout)
      }
      if let newLayout = mutatorLayout {
        adoptChildLayout(newLayout)
      }
    }
  }

  /// A list of all `FieldLayout` objects belonging under this `BlockLayout`.
  open var fieldLayouts: [FieldLayout] {
    var fieldLayouts = [FieldLayout]()
    for inputLayout in inputLayouts {
      fieldLayouts += inputLayout.fieldLayouts
    }
    return fieldLayouts
  }

  /// The parent block group layout
  open var parentBlockGroupLayout: BlockGroupLayout? {
    return parentLayout as? BlockGroupLayout
  }

  /// The top most block group layout for this block
  open var rootBlockGroupLayout: BlockGroupLayout? {
    var root = parentBlockGroupLayout
    var currentLayout: Layout = self

    while let parentLayout = currentLayout.parentLayout {
      if let blockGroupLayout = parentLayout as? BlockGroupLayout {
        root = blockGroupLayout
      }
      currentLayout = parentLayout
    }

    return root
  }

  /// The first draggable `BlockLayout` up the layout tree.
  /// If there is no `BlockLayout` exists up the layout tree, this value is `nil`.  
  open var draggableBlockLayout: BlockLayout? {
    var layout: Layout? = self

    while let currentLayout = layout {
      if let blockLayout = currentLayout as? BlockLayout
        , blockLayout.block.draggable
      {
        return blockLayout
      } else if let blockGroupLayout = layout as? BlockGroupLayout
        , blockGroupLayout.blockLayouts.count > 0 &&
         blockGroupLayout.blockLayouts[0].block.draggable
      {
        return blockGroupLayout.blockLayouts[0]
      }

      layout = currentLayout.parentLayout
    }

    return nil
  }

  /// Flag if this block should be highlighted
  open var highlighted: Bool = false {
    didSet {
      if highlighted == oldValue {
        return
      }
      sendChangeEvent(withFlags: BlockLayout.Flag_UpdateHighlight)
    }
  }

  /// Flag indicating if this block should be visible
  open var visible: Bool = true {
    didSet {
      if visible == oldValue {
        return
      }
      sendChangeEvent(withFlags: BlockLayout.Flag_UpdateVisible)
    }
  }

  /// Flag determining if user interaction should be enabled for the corresponding view.
  open var userInteractionEnabled: Bool {
    return true
  }

  /// The position of the block's leading edge X offset, specified as a Workspace coordinate
  /// system unit.
  open var leadingEdgeXOffset: CGFloat {
    return 0
  }

  /// The line height of the first line in the block layout, specified as a Workspace coordinate
  /// system unit. It is used for vertical alignment purposes and should be updated during
  /// `performLayout(includeChildren:)`.
  open var firstLineHeight: CGFloat = 0

  /// Flag indicating if this block is disabled, which means it will be excluded from code
  /// generation.
  open var disabled: Bool {
    get { return block.disabled }
    set {
      if block.disabled == newValue {
        return
      }

      block.disabled = newValue

      if let workspace = self.workspace {
        let event = BlocklyEvent.Change.disabledStateEvent(workspace: workspace, block: block)
        EventManager.shared.addPendingEvent(event)
      }
    }
  }

  /// Flag indicating if input connectors should be drawn inside a block (`true`) or
  /// on the edge of the block (`false`).
  open var inputsInline: Bool {
    get { return block.inputsInline }
    set {
      if block.inputsInline == newValue {
        return
      }

      block.inputsInline = newValue

      if let workspace = self.workspace {
        let event = BlocklyEvent.Change.inlineStateEvent(workspace: workspace, block: block)
        EventManager.shared.addPendingEvent(event)
      }
    }
  }

  /// The comment text of the block.
  open var comment: String {
    get { return block.comment }
    set {
      if block.comment == newValue {
        return
      }

      let oldValue = block.comment
      block.comment = newValue

      if let workspace = self.workspace {
        let event = BlocklyEvent.Change.commentTextEvent(
          workspace: workspace, block: block, oldValue: oldValue, newValue: newValue)
        EventManager.shared.addPendingEvent(event)
      }
    }
  }

  /// The workspace this block belongs to, if it exists.
  fileprivate var workspace: Workspace? {
    return firstAncestor(ofType: WorkspaceLayout.self)?.workspace
  }

  /// Keeps track of all highlighted connection uuid's, and the set of source uuid's that are
  /// triggering the highlights.
  fileprivate var _connectionHighlights = [String: Set<String>]()

  // MARK: - Initializers

  /**
   Initializes the block layout.

   - parameter block: The given `Block` for this block layout.
   - parameter engine: The `LayoutEngine` to associate with this layout.
   */
  public init(block: Block, engine: LayoutEngine) {
    self.block = block
    super.init(engine: engine)

    block.listeners.add(self)
  }

  deinit {
    block.listeners.remove(self)
  }

  // MARK: - Input Layouts

  /**
  Appends an inputLayout to `self.inputLayouts` and sets its `parentLayout` to this instance.

  - parameter inputLayout: The `InputLayout` to append.
  */
  open func appendInputLayout(_ inputLayout: InputLayout) {
    inputLayouts.append(inputLayout)
    adoptChildLayout(inputLayout)
  }

  /**
  Removes `self.inputLayouts[index]`, sets its `parentLayout` to nil, and returns it.

  - parameter index: The index to remove from `inputLayouts`.
  - returns: The `BlockLayout` that was removed.
  */
  @discardableResult
  open func removeInputLayout(atIndex index: Int) -> InputLayout {
    let inputLayout = inputLayouts.remove(at: index)
    removeChildLayout(inputLayout)
    return inputLayout
  }

  /**
  Clears `self.inputLayouts` and `self.mutatorLayout`, and sets their `parentLayout` to nil.

  - parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  open func reset(updateLayout: Bool = true) {
    while inputLayouts.count > 0 {
      removeInputLayout(atIndex: 0)
    }

    mutatorLayout = nil

    if updateLayout {
      updateLayoutUpTree()
    }
  }

  // MARK: - Connection Highlighting

  /**
   Adds a highlight source to a given connection on this block.

   If there were no previous highlight sources for this connection, a `Flag_UpdateHighlight`
   change event is triggered in order to update connection highlighting for this block.

   - parameter sourceUUID: A UUID of the source object that is triggering this highlight.
   Typically, this is the UUID of a `Block` or a `BlockLayout`.
   - parameter connection: The `Connection`.
   */
  public func addHighlightSource(sourceUUID: String, forConnection connection: Connection) {
    guard connection.sourceBlock == block else {
      return
    }

    if _connectionHighlights[connection.uuid] != nil {
      _connectionHighlights[connection.uuid]?.insert(sourceUUID)
    } else {
      _connectionHighlights[connection.uuid] = [sourceUUID]
      sendChangeEvent(withFlags: BlockLayout.Flag_UpdateConnectionHighlight)
    }
  }

  /**
   Removes a highlight source from a given connection on this block.

   If there are no more highlight sources for the given connection (after this one is removed), a
   `Flag_UpdateHighlight` change event is triggered in order to update connection highlighting for
   this block.

   - parameter sourceUUID: The UUID of the source object that originally added itself as a
   highlight source.
   - parameter connection: The `Connection`
   */
  public func removeHighlightSource(sourceUUID: String, forConnection connection: Connection) {
    guard connection.sourceBlock == block else {
      return
    }

    if var sources = _connectionHighlights[connection.uuid] {
      sources.remove(sourceUUID)

      if sources.isEmpty {
        _connectionHighlights[connection.uuid] = nil
        sendChangeEvent(withFlags: BlockLayout.Flag_UpdateConnectionHighlight)
      } else {
        _connectionHighlights[connection.uuid] = sources
      }
    }
  }

  /**
   Returns if a connection is highlighted on this block.

   - parameter connection: The `Connection` to check.
   - returns: `true` if the connection has at least one highlight source. `false` otherwise.
   */
  public func isConnectionHighlighted(_ connection: Connection) -> Bool {
    return _connectionHighlights[connection.uuid] != nil
  }

  /**
   Returns if there are connections that have been highlighted on this block.

   - returns: `true` if any connections have been highlighted on this block. `false`
   otherwise.
   */
  public func hasHighlightedConnections() -> Bool {
    return !_connectionHighlights.isEmpty
  }

  // MARK: - Internal

  /**
  For a given input layout, returns the input layout located one cell before it within
  `inputLayouts`.

  - parameter layout: A given input layout
  - returns: If the given input layout is found at `inputLayouts[i]` where `i > 0`,
  `inputLayouts[i - 1]` is returned. Otherwise, nil is returned.
  */
  internal func inputLayout(before layout: InputLayout) -> InputLayout? {
    for i in 0 ..< inputLayouts.count {
      if inputLayouts[i] == layout {
        return i > 0 ? inputLayouts[i - 1] : nil
      }
    }
    return nil
  }

  /**
  For a given input layout, returns the input layout located one cell after it within
  `inputLayouts`.

  - parameter layout: A given input layout
  - returns: If the given input layout is found at `inputLayouts[i]` where
  `i < inputLayouts.count - 1`, `inputLayouts[i + 1]` is returned. Otherwise, nil is returned.
  */
  internal func inputLayout(after layout: InputLayout) -> InputLayout? {
    for i in 0 ..< inputLayouts.count {
      if inputLayouts[i] == layout {
        return i < (inputLayouts.count - 1) ? inputLayouts[i + 1] : nil
      }
    }
    return nil
  }
}

// MARK: - BlockDelegate

extension BlockLayout: BlockListener {
  public func didUpdateBlock(_ block: Block) {
    // Refresh the block since it's been updated
    sendChangeEvent(withFlags: BlockLayout.Flag_NeedsDisplay)
  }
}
