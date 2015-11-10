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
Stores information on how to render and position a `Block` on-screen.
*/
@objc(BKYBlockLayout)
public class BlockLayout: Layout {
  // MARK: - Static Properties

  /// The shared instance used to configure all instances of `BlockLayout`.
  public static let sharedConfig = Config()

  // MARK: - Properties

  /// The `Block` to layout.
  public unowned let block: Block

  /// The information for rendering the background for this block.
  public let background = BlockLayout.Background()

  /// Flag if this block should be highlighted
  public var highlighted: Bool = false {
    didSet {
      if highlighted != oldValue {
        // Force re-draw
        self.needsDisplay = true
      }
    }
  }

  /// The relative position of the output connection, expressed as a Workspace coordinate system
  /// unit
  private var outputConnectionRelativePosition: WorkspacePoint = WorkspacePointZero

  /// The relative position of the next connection, expressed as a Workspace coordinate system unit
  private var nextConnectionRelativePosition: WorkspacePoint = WorkspacePointZero

  /// The relative position of the previous connection, expressed as a Workspace coordinate system
  /// unit
  private var previousConnectionRelativePosition: WorkspacePoint = WorkspacePointZero

  /// The corresponding layout objects for `self.block.inputs[]`
  public private(set) var inputLayouts = [InputLayout]()

  internal override var absolutePosition: WorkspacePoint {
    didSet {
      // Update connection positions
      self.block.outputConnection?.moveToPosition(self.absolutePosition,
        withOffset: outputConnectionRelativePosition)

      self.block.nextConnection?.moveToPosition(self.absolutePosition,
        withOffset: nextConnectionRelativePosition)

      self.block.previousConnection?.moveToPosition(self.absolutePosition,
        withOffset: previousConnectionRelativePosition)
    }
  }

  /// A list of all `FieldLayout` objects belonging under this `BlockLayout`.
  public var fieldLayouts: [FieldLayout] {
    var fieldLayouts = [FieldLayout]()
    for inputLayout in inputLayouts {
      fieldLayouts += inputLayout.fieldLayouts
    }
    return fieldLayouts
  }

  /// Whether this block is the first child of its parent, which must be a `BlockGroupLayout`.
  public var topBlockInBlockLayout: Bool {
    return parentBlockGroupLayout?.blockLayouts[0] == self ?? false
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
  /// values.
  public var zIndex: CGFloat = 0 {
    didSet {
      if zIndex == oldValue {
        return
      }

      // Update the z-position for all of its block group children
      for inputLayout in self.inputLayouts {
        inputLayout.blockGroupLayout.zIndex = zIndex
      }

      // TODO:(vicng) Change this to raise a custom layout event for z-index
      self.needsRepositioning = true
    }
  }

  // MARK: - Initializers

  public required init(block: Block, workspaceLayout: WorkspaceLayout) {
    self.block = block
    super.init(workspaceLayout: workspaceLayout)

    for connection in self.block.directConnections {
      connection.listeners.add(self)

      // Automatically let the workspace's connection manager track this connection
      self.workspaceLayout.connectionManager.trackConnection(connection)

      // TODO:(vicng) Untrack these connections when the block is deleted
    }
  }

  // MARK: - Super

  public override func performLayout(includeChildren includeChildren: Bool) {
    // TODO:(vicng) Potentially move logic from this method into Block.Background to make things
    // easier to follow.

    let outputPuzzleTabXOffset = block.outputConnection != nil ?
      BlockLayout.sharedConfig.puzzleTabWidth : 0
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    var minimalFieldWidthRequired: CGFloat = 0
    var minimalStatementWidthRequired: CGFloat = 0
    var currentLineHeight: CGFloat = 0
    var previousInputLayout: InputLayout?
    var backgroundRow: BackgroundRow!

    // Set the background properties based on the block layout and remove all rows from the
    // background
    self.background.updateRenderPropertiesFromBlockLayout(self)
    self.background.removeAllRows()

    // Update relative position/size of inputs
    for inputLayout in inputLayouts {
      if backgroundRow == nil || // First row
        !block.inputsInline || // External inputs
        previousInputLayout?.input.type == .Statement || // Previous input was a statement
        inputLayout.input.type == .Statement // Current input is a statement
      {
        // Start a new row
        backgroundRow = BackgroundRow()
        background.appendRow(backgroundRow)

        // Reset values for this row
        xOffset = outputPuzzleTabXOffset
        yOffset += currentLineHeight
        currentLineHeight = 0
      }

      // Append this input layout to the current row
      backgroundRow.inputLayouts.append(inputLayout)

      // Since input layouts are dependent on each other, always re-perform their layouts
      inputLayout.performLayout(includeChildren: includeChildren)
      inputLayout.relativePosition.x = xOffset
      inputLayout.relativePosition.y = yOffset

      // Update the maximum field width used
      if inputLayout.input.type == .Statement {
        minimalStatementWidthRequired =
          max(minimalStatementWidthRequired, inputLayout.minimalStatementWidthRequired)
      } else if !block.inputsInline {
        minimalFieldWidthRequired =
          max(minimalFieldWidthRequired, inputLayout.minimalFieldWidthRequired)
      }

      // Update position coordinates for this row
      xOffset += inputLayout.totalSize.width
      currentLineHeight = max(currentLineHeight, inputLayout.totalSize.height)
      previousInputLayout = inputLayout
    }

    // Increase the amount of space used for statements and external inputs, re-layout each
    // background row based on a new maximum width, and calculate the size needed for this entire
    // BlockLayout.
    let minimalWidthRequired = max(minimalFieldWidthRequired, minimalStatementWidthRequired)
    for backgroundRow in self.background.rows {
      if backgroundRow.inputLayouts.isEmpty {
        continue
      }

      let lastInputLayout = backgroundRow.inputLayouts.last!
      if lastInputLayout.input.type == .Statement {
        // Maximize the statement width
        lastInputLayout.maximizeStatementWidthTo(minimalStatementWidthRequired)

        if !block.inputsInline {
          // Extend the right edge of the statement (ie. the top and bottom parts of the "C" shape)
          // so that it equals largest width used for this block.
          lastInputLayout.extendStatementRightEdgeBy(
            max(minimalWidthRequired - lastInputLayout.rightEdge, 0))
        }
      } else if !block.inputsInline {
        // Maximize the amount of space for fields
        lastInputLayout.maximizeFieldWidthTo(minimalWidthRequired)
      }

      // Update the background row based on the new max width
      backgroundRow.updateRenderPropertiesWithMinimalRowWidth(minimalWidthRequired)
    }

    var size = WorkspaceSizeZero
    for inputLayout in inputLayouts {
      size = LayoutHelper.sizeThatFitsLayout(inputLayout, fromInitialSize: size)
    }

    // Update connection relative positions
    let notchXOffset = outputPuzzleTabXOffset + BlockLayout.sharedConfig.notchWidth / 2

    if block.previousConnection != nil {
      previousConnectionRelativePosition =
        WorkspacePointMake(notchXOffset, BlockLayout.sharedConfig.notchHeight)
    }

    if block.nextConnection != nil {
      let blockBottomEdge = background.rows.reduce(0, combine: { $0 + $1.rowHeight})
      nextConnectionRelativePosition =
        WorkspacePointMake(notchXOffset, blockBottomEdge + BlockLayout.sharedConfig.notchHeight)

      // TODO:(vicng) Make the size.height a property of self.background
      // Create room to draw the notch height at the bottom
      size.height += BlockLayout.sharedConfig.notchHeight
    }

    if block.outputConnection != nil {
      outputConnectionRelativePosition =
        WorkspacePointMake(0, BlockLayout.sharedConfig.puzzleTabHeight / 2)
    }

    // Update the size required for this block
    self.contentSize = size

    // Force this block to be redisplayed
    self.needsDisplay = true
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

  // MARK: - Internal

  /**
  For a given input layout, returns the input layout located one cell before it within
  `inputLayouts`.

  - Parameter layout: A given input layout
  - Returns: If the given input layout is found at `inputLayouts[i]` where `i > 0`,
  `inputLayouts[i - 1]` is returned. Otherwise, nil is returned.
  */
  internal func inputLayoutBeforeLayout(layout: InputLayout) -> InputLayout? {
    for (var i = 0; i < inputLayouts.count; i++) {
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
    for (var i = 0; i < inputLayouts.count - 1; i++) {
      if inputLayouts[i] == layout {
        return inputLayouts[i + 1]
      }
    }
    return nil
  }
}

// MARK: - ConnectionListener

extension BlockLayout: ConnectionListener {
  public func didChangeHighlightForConnection(connection: Connection) {
    // Force redraw for the view
    self.needsDisplay = true
  }
}