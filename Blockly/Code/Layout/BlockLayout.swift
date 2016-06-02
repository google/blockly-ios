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
public class BlockLayout: Layout {
  // MARK: - Static Properties

  /// Flag that should be used when `self.zIndex` has been updated
  public static let Flag_UpdateZIndex = LayoutFlag(0)
  /// Flag that should be used when `self.highlighted` has been updated
  public static let Flag_UpdateHighlight = LayoutFlag(1)
  /// Flag that should be used when `self.dragging` has been updated
  public static let Flag_UpdateDragging = LayoutFlag(2)
  /// Flag that should be used when `self.visible` has been updated
  public static let Flag_UpdateVisible = LayoutFlag(3)

  /// Flag that should be used when any direct connection on this block has updated its highlight
  /// value
  public static let Flag_UpdateConnectionHighlight = LayoutFlag(2)

  // MARK: - Properties

  /// The `Block` to layout.
  public final let block: Block

  /// Flag if this block should be highlighted
  public var highlighted: Bool = false {
    didSet {
      if highlighted != oldValue {
        scheduleChangeEventWithFlags(BlockLayout.Flag_UpdateHighlight)
      }
    }
  }

  /// The corresponding layout objects for `self.block.inputs[]`
  public private(set) var inputLayouts = [InputLayout]()

  /// A list of all `FieldLayout` objects belonging under this `BlockLayout`.
  public var fieldLayouts: [FieldLayout] {
    var fieldLayouts = [FieldLayout]()
    for inputLayout in inputLayouts {
      fieldLayouts += inputLayout.fieldLayouts
    }
    return fieldLayouts
  }

  /// The parent block group layout
  public var parentBlockGroupLayout: BlockGroupLayout? {
    return parentLayout as? BlockGroupLayout
  }

  /// The top most block group layout for this block
  public var rootBlockGroupLayout: BlockGroupLayout? {
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

  /// Z-index of the layout. Those with higher values should render on top of those with lower
  /// values. Setting this value automatically updates every value of
  /// `self.inputLayouts[i].renderedBlockGroupLayout.zIndex` to use the same `zIndex`.
  public var zIndex: UInt = 0 {
    didSet {
      if zIndex == oldValue {
        return
      }

      // Update the z-position for all of its input layouts
      for inputLayout in inputLayouts {
        inputLayout.blockGroupLayout.zIndex = zIndex
      }

      scheduleChangeEventWithFlags(BlockLayout.Flag_UpdateZIndex)
    }
  }

  /// The first draggable `BlockLayout` up the layout tree. Returns `nil` if there is
  /// no `BlockLayout` that can be dragged.
  public var draggableBlockLayout: BlockLayout? {
    var layout: Layout? = self

    while let currentLayout = layout {
      // A block layout is considered draggable as long as it is not a shadow block
      if let blockLayout = currentLayout as? BlockLayout
        where !blockLayout.block.shadow
      {
        return blockLayout
      } else if let blockGroupLayout = layout as? BlockGroupLayout
        where blockGroupLayout.blockLayouts.count > 0 &&
         !blockGroupLayout.blockLayouts[0].block.shadow
      {
        return blockGroupLayout.blockLayouts[0]
      }

      layout = currentLayout.parentLayout
    }

    return nil
  }

  /// Flag indicating if this block is being dragged
  public var dragging: Bool = false {
    didSet {
      if dragging == oldValue {
        return
      }

      // Update dragging for all of its block group children
      for inputLayout in inputLayouts {
        inputLayout.blockGroupLayout.dragging = dragging
      }

      scheduleChangeEventWithFlags(BlockLayout.Flag_UpdateDragging)
    }
  }

  /// Flag indicating if this block should be visible
  public var visible: Bool = true {
    didSet {
      if visible == oldValue {
        return
      }

      // Update visible for all of its block group children
      for inputLayout in inputLayouts {
        inputLayout.blockGroupLayout.visible = visible
      }

      scheduleChangeEventWithFlags(BlockLayout.Flag_UpdateVisible)
    }
  }

  /// The position of the block's leading edge X offset, specified as a Workspace coordinate
  /// system unit.
  public var leadingEdgeXOffset: CGFloat {
    return 0
  }

  // MARK: - Initializers

  public init(block: Block, engine: LayoutEngine) {
    self.block = block
    super.init(engine: engine)

    for connection in self.block.directConnections {
      connection.highlightDelegate = self
    }
  }

  // MARK: - Public

  /**
  Appends an inputLayout to `self.inputLayouts` and sets its `parentLayout` to this instance.

  - Parameter inputLayout: The `InputLayout` to append.
  */
  public func appendInputLayout(inputLayout: InputLayout) {
    inputLayout.parentLayout = self
    inputLayouts.append(inputLayout)
  }

  /**
  Removes `self.inputLayouts[index]`, sets its `parentLayout` to nil, and returns it.

  - Parameter index: The index to remove from `inputLayouts`.
  - Returns: The `BlockLayout` that was removed.
  */
  public func removeInputLayoutAtIndex(index: Int) -> InputLayout {
    let inputLayout = inputLayouts.removeAtIndex(index)
    inputLayout.parentLayout = nil
    return inputLayout
  }

  /**
  Removes all elements from `self.inputLayouts` and sets their `parentLayout` to nil.

  - Parameter updateLayout: If true, all parent layouts of this layout will be updated.
  */
  public func reset(updateLayout updateLayout: Bool = true) {
    while inputLayouts.count > 0 {
      removeInputLayoutAtIndex(0)
    }

    if updateLayout {
      updateLayoutUpTree()
    }
  }

  // MARK: - Internal

  /**
  For a given input layout, returns the input layout located one cell before it within
  `inputLayouts`.

  - Parameter layout: A given input layout
  - Returns: If the given input layout is found at `inputLayouts[i]` where `i > 0`,
  `inputLayouts[i - 1]` is returned. Otherwise, nil is returned.
  */
  internal func inputLayoutBeforeLayout(layout: InputLayout) -> InputLayout? {
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

  - Parameter layout: A given input layout
  - Returns: If the given input layout is found at `inputLayouts[i]` where
  `i < inputLayouts.count - 1`, `inputLayouts[i + 1]` is returned. Otherwise, nil is returned.
  */
  internal func inputLayoutAfterLayout(layout: InputLayout) -> InputLayout? {
    for i in 0 ..< inputLayouts.count {
      if inputLayouts[i] == layout {
        return i < (inputLayouts.count - 1) ? inputLayouts[i + 1] : nil
      }
    }
    return nil
  }
}

// MARK: - ConnectionHighlightDelegate

extension BlockLayout: ConnectionHighlightDelegate {
  public func didChangeHighlightForConnection(connection: Connection) {
    scheduleChangeEventWithFlags(BlockLayout.Flag_UpdateConnectionHighlight)
  }
}

// MARK: - BlockDelegate

extension BlockLayout: BlockDelegate {
}
