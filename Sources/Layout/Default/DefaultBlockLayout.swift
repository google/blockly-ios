/*
* Copyright 2016 Google Inc. All Rights Reserved.
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

/**
 A default implementation of `BlockLayout`.
 */
@objc(BKYDefaultBlockLayout)
@objcMembers public final class DefaultBlockLayout: BlockLayout {
  // MARK: - Properties

  /// The information for rendering the background for this block.
  public let background = DefaultBlockLayout.Background()

  // TODO(#34): Consider replacing all connections/relative positions with a ConnectionLayout

  /**
   For performance reasons, create a variable that can be used to reference a `nil`
   `Connection`.

   Normally, `_outputConnection`, `_nextConnection`, and `_previousConnection` would
   be defined as optional variables, but there is an implicit objc-retain/release overhead when
   using optionals. So instead, those variables are defined as non-optionals and assigned to this
   variable if they are actually `nil`. This reduces retain/release overhead and improves
   performance.
   */
  private static let nilConnection = Connection(type: .outputValue)

  /// For performance reasons, keep a strong reference to `block.outputConnection`.
  /// If `block.outputConnection` is actually `nil`, this variable references
  /// `DefaultBlockLayout.nilConnection`.
  fileprivate let _outputConnection: Connection

  /// For performance reasons, keep a strong reference to `block.nextConnection`.
  /// If `block.nextConnection` is actually `nil`, this variable references
  /// `DefaultBlockLayout.nilConnection`.
  fileprivate let _nextConnection: Connection

  /// For performance reasons, keep a strong reference to `block.previousConnection`.
  /// If `block.previousConnection` is actually `nil`, this variable references
  /// `DefaultBlockLayout.nilConnection`.
  fileprivate let _previousConnection: Connection

  /// The relative position of the output connection, expressed as a Workspace coordinate system
  /// unit
  fileprivate var _outputConnectionRelativePosition: WorkspacePoint = WorkspacePoint.zero

  /// The relative position of the next connection, expressed as a Workspace coordinate system unit
  fileprivate var _nextConnectionRelativePosition: WorkspacePoint = WorkspacePoint.zero

  /// The relative position of the previous connection, expressed as a Workspace coordinate system
  /// unit
  fileprivate var _previousConnectionRelativePosition: WorkspacePoint = WorkspacePoint.zero

  /// The position of the block's leading edge X offset, specified as a Workspace coordinate
  /// system unit.
  public override var leadingEdgeXOffset: CGFloat {
    return background.leadingEdgeXOffset
  }

  internal override var absolutePosition: WorkspacePoint {
    didSet {
      // Update connection positions
      if _outputConnection !== DefaultBlockLayout.nilConnection {
        _outputConnection.moveToPosition(self.absolutePosition,
          withOffset: _outputConnectionRelativePosition)
      }

      if _nextConnection !== DefaultBlockLayout.nilConnection {
        _nextConnection.moveToPosition(self.absolutePosition,
          withOffset: _nextConnectionRelativePosition)
      }

      if _previousConnection !== DefaultBlockLayout.nilConnection {
        _previousConnection.moveToPosition(self.absolutePosition,
          withOffset: _previousConnectionRelativePosition)
      }
      block.position = self.absolutePosition
    }
  }

  // MARK: - Initializers

  /**
   Initializes the default block layout.

   - parameter block: The `Block` model corresponding to the layout.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   */
  public override init(block: Block, engine: LayoutEngine) {
    _outputConnection = block.outputConnection ?? DefaultBlockLayout.nilConnection
    _nextConnection = block.nextConnection ?? DefaultBlockLayout.nilConnection
    _previousConnection = block.previousConnection ?? DefaultBlockLayout.nilConnection
    super.init(block: block, engine: engine)
  }

  // MARK: - Super

  public override func performLayout(includeChildren: Bool) {
    // TODO(#41): Potentially move logic from this method into Block.Background to make things
    // easier to follow.
    // TODO(#41): Handle stroke widths for the background.

    let outputPuzzleTabXOffset = block.outputConnection != nil ?
      self.config.workspaceUnit(for: DefaultLayoutConfig.PuzzleTabWidth) : 0
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    var minimalFieldWidthRequired: CGFloat = 0
    var minimalStatementWidthRequired: CGFloat = 0
    var currentLineHeight: CGFloat = 0
    var previousInputLayout: InputLayout?
    var backgroundRow: BackgroundRow!

    // Set the background properties based on the block layout and remove all rows from the
    // background
    self.background.updateRenderProperties(fromBlockLayout: self)
    self.background.removeAllRows()

    // Account for sizing if a cap hat needs to be rendered
    if background.hat == Block.Style.hatCap {
      let blockHatSize = config.workspaceSize(for: DefaultLayoutConfig.BlockHatCapSize)
      currentLineHeight += blockHatSize.height
      minimalFieldWidthRequired = max(minimalFieldWidthRequired, blockHatSize.width)
    }

    // Account for minimum width of rendering previous/next notches
    if block.previousConnection != nil ||  block.nextConnection != nil {
      let notchXOffset = config.workspaceUnit(for: DefaultLayoutConfig.NotchXOffset)
      let notchWidth = config.workspaceUnit(for: DefaultLayoutConfig.NotchWidth)
      minimalFieldWidthRequired = max(minimalFieldWidthRequired, notchXOffset + notchWidth)
    }

    var layouts: [Layout] = inputLayouts
    if let mutatorLayout = self.mutatorLayout {
      layouts.insert(mutatorLayout, at: 0)
    }

    // Update relative position/size of inputs
    for layout in layouts {
      let inputLayout = layout as? InputLayout

      if backgroundRow == nil || // First row
        (previousInputLayout != nil &&
          (!block.inputsInline || // External inputs
          previousInputLayout?.input.type == .statement)) || // Previous input was a statement
        inputLayout?.input.type == .statement // Current input is a statement
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
      backgroundRow.layouts.append(layout)

      // Since input layouts are dependent on each other, always re-perform their layouts
      layout.performLayout(includeChildren: includeChildren)
      layout.relativePosition.x = xOffset
      layout.relativePosition.y = yOffset

      // Update minimum field/statement widths, based on this layout
      let xOffsetRelativeToLeadingEdge = layout.relativePosition.x - outputPuzzleTabXOffset
      if let defaultInputLayout = inputLayout as? DefaultInputLayout {
        // Update the maximum field width used
        if defaultInputLayout.input.type == .statement {
          minimalStatementWidthRequired =
            max(minimalStatementWidthRequired,
                xOffsetRelativeToLeadingEdge + defaultInputLayout.minimalStatementWidthRequired)
        } else if !block.inputsInline {
          minimalFieldWidthRequired =
            max(minimalFieldWidthRequired,
                xOffsetRelativeToLeadingEdge + defaultInputLayout.minimalFieldWidthRequired)
        }
      } else if let mutatorLayout = layout as? MutatorLayout,
        !block.inputsInline
      {
        minimalFieldWidthRequired =
          max(minimalFieldWidthRequired,
              xOffsetRelativeToLeadingEdge + mutatorLayout.totalSize.width)
      }

      // Update position coordinates for this row
      xOffset += layout.totalSize.width
      currentLineHeight = max(currentLineHeight, layout.totalSize.height)
      previousInputLayout = inputLayout
    }

    // Increase the amount of space used for statements and external inputs, re-layout each
    // background row based on a new maximum width, and calculate the size needed for this entire
    // BlockLayout.
    let minimalWidthRequired = max(minimalFieldWidthRequired, minimalStatementWidthRequired)
    var nextRowPositionY: CGFloat = 0
    for i in 0 ..< background.rows.count {
      let backgroundRow = background.rows[i]
      if backgroundRow.layouts.isEmpty {
        continue
      }

      if let lastInputLayout = backgroundRow.layouts.last as? DefaultInputLayout {
        let xOffsetRelativeToLeftEdge =
          lastInputLayout.relativePosition.x - outputPuzzleTabXOffset

        if lastInputLayout.input.type == .statement {
          // Maximize the statement width
          lastInputLayout.maximizeStatement(toWidth: minimalStatementWidthRequired)

          if !block.inputsInline {
            // Extend the right edge of the statement (ie. the top and bottom parts of the
            // "C" shape) so that it equals largest width used for this block.
            let trailingEdge = xOffsetRelativeToLeftEdge + lastInputLayout.rightEdge
            lastInputLayout.extendStatementRightEdgeBy(max(minimalWidthRequired - trailingEdge, 0))
          }
        } else if !block.inputsInline {
          // Maximize the amount of space for the last field
          let newFieldWidth = minimalWidthRequired - xOffsetRelativeToLeftEdge
          lastInputLayout.maximizeField(toWidth: newFieldWidth)
        }
      }

      // Determine the line height of this background row
      var lineHeight: CGFloat = 0
      for layout in backgroundRow.layouts {
        if let inputLayout = layout as? InputLayout {
          lineHeight = max(lineHeight, inputLayout.firstLineHeight)
        } else {
          lineHeight = max(lineHeight, layout.totalSize.height)
        }
      }
      if i == 0 {
        firstLineHeight = lineHeight
      }

      // Vertically align each layout to this line height.
      let currentRowPositionY = nextRowPositionY
      for layout in backgroundRow.layouts {
        if layout.relativePosition.y < currentRowPositionY {
          // This layout was pushed down from a vertical alignment adjustment from the previous row.
          // Update it to its new row position.
          layout.relativePosition.y = currentRowPositionY
        }

        if let inputLayout = layout as? DefaultInputLayout {
          inputLayout.verticallyAlignRow(toHeight: lineHeight)
        } else {
          layout.relativePosition.y += (lineHeight - layout.totalSize.height) / 2.0
        }

        // Update what the next row position should be (in case one of the valign operations changed
        // the layout position).
        nextRowPositionY =
          max(nextRowPositionY, layout.relativePosition.y + layout.totalSize.height)
      }

      // Update the background row based on the new max width
      backgroundRow.updateRenderProperties(minimalRowWidth: minimalWidthRequired,
                                           leadingEdgeOffset: outputPuzzleTabXOffset)
    }

    // Edge case: If there were no input layouts for the block, add an empty background row
    // (so an empty block is rendered).
    if background.rows.isEmpty {
      let emptyRow = BackgroundRow()
      emptyRow.rightEdge =
        max(config.workspaceUnit(for: LayoutConfig.InlineXPadding) * 2, minimalWidthRequired)
      emptyRow.topPadding = config.workspaceUnit(for: LayoutConfig.InlineYPadding)
      emptyRow.middleHeight = config.workspaceUnit(for: LayoutConfig.FieldMinimumHeight)
      emptyRow.bottomPadding = config.workspaceUnit(for: LayoutConfig.InlineYPadding)
      background.appendRow(emptyRow)
      firstLineHeight = emptyRow.rowHeight
    }

    // Update connection relative positions
    let notchXOffset = outputPuzzleTabXOffset +
      config.workspaceUnit(for: DefaultLayoutConfig.NotchXOffset) +
      config.workspaceUnit(for: DefaultLayoutConfig.NotchWidth) / 2
    let notchHeight = self.config.workspaceUnit(for: DefaultLayoutConfig.NotchHeight)

    if block.previousConnection != nil {
      _previousConnectionRelativePosition = WorkspacePoint(x: notchXOffset, y: notchHeight)
    }

    if block.nextConnection != nil {
      let blockBottomEdge = background.rows.reduce(0, { $0 + $1.rowHeight})
      _nextConnectionRelativePosition =
        WorkspacePoint(x: notchXOffset, y: blockBottomEdge + notchHeight)
    }

    if block.outputConnection != nil {
      _outputConnectionRelativePosition = WorkspacePoint(x: 0, y: firstLineHeight / 2.0)
    }

    // Update the first line height of the background so it can render the output connector properly
    background.firstLineHeight = firstLineHeight

    // Update the size required for this block
    self.contentSize = requiredContentSize()

    // Force this block to be redisplayed
    sendChangeEvent(withFlags: Layout.Flag_NeedsDisplay)
  }

  // MARK: - Private

  private func requiredContentSize() -> WorkspaceSize {
    // Calculate size required for this block layout based on child layouts and background size
    var size = WorkspaceSize.zero

    for inputLayout in inputLayouts {
      size = LayoutHelper.sizeThatFitsLayout(inputLayout, fromInitialSize: size)
    }

    if let mutatorLayout = self.mutatorLayout {
      size = LayoutHelper.sizeThatFitsLayout(mutatorLayout, fromInitialSize: size)
    }

    let maxBackgroundX =
      background.leadingEdgeXOffset + (background.rows.map({ $0.rightEdge }).max() ?? 0)
    let maxBackgroundY =
      background.leadingEdgeYOffset + background.rows.map({ $0.rowHeight }).reduce(0, +)
    size.width = max(size.width, maxBackgroundX)
    size.height = max(size.height, maxBackgroundY)

    if block.nextConnection != nil {
      // TODO(#41): Make the size.height a property of self.background
      /// Create room to draw the notch height at the bottom
      let notchHeight = config.workspaceUnit(for: DefaultLayoutConfig.NotchHeight)
      size.height += notchHeight
    }

    return size
  }
}
