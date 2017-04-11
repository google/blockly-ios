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
public final class DefaultBlockLayout: BlockLayout {
  // MARK: - Properties

  /// The information for rendering the background for this block.
  public let background = DefaultBlockLayout.Background()

  // TODO(#34): Consider replacing all connections/relative positions with a ConnectionLayout

  /// For performance reasons, keep a strong reference to the block.outputConnection
  fileprivate var _outputConnection: Connection!

  /// For performance reasons, keep a strong reference to the block.nextConnection
  fileprivate var _nextConnection: Connection!

  /// For performance reasons, keep a strong reference to the block.previousConnection
  fileprivate var _previousConnection: Connection!

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
      if _outputConnection != nil {
        _outputConnection.moveToPosition(self.absolutePosition,
          withOffset: _outputConnectionRelativePosition)
      }

      if _nextConnection != nil {
        _nextConnection.moveToPosition(self.absolutePosition,
          withOffset: _nextConnectionRelativePosition)
      }

      if _previousConnection != nil {
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
    _outputConnection = block.outputConnection
    _nextConnection = block.nextConnection
    _previousConnection = block.previousConnection
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

    // Account for sizing if a start hat needs to be rendered
    if background.startHat {
      let blockHatSize = config.workspaceSize(for: DefaultLayoutConfig.BlockStartHatSize)
      currentLineHeight += blockHatSize.height
      minimalFieldWidthRequired = max(minimalFieldWidthRequired, blockHatSize.width)
    }

    // Account for minimum width of rendering previous/next notches
    if block.previousConnection != nil ||  block.nextConnection != nil {
      let notchWidth = config.workspaceUnit(for: DefaultLayoutConfig.NotchWidth)
      minimalFieldWidthRequired = max(minimalFieldWidthRequired, notchWidth)
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
    for backgroundRow in background.rows {
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
    }

    // Update connection relative positions
    let notchXOffset = outputPuzzleTabXOffset +
      self.config.workspaceUnit(for: DefaultLayoutConfig.NotchWidth) / 2
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
      _outputConnectionRelativePosition = WorkspacePoint(
        x: 0, y: self.config.workspaceUnit(for: DefaultLayoutConfig.PuzzleTabHeight) / 2)
    }

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
