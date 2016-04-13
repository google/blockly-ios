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

  // TODO:(#34) Consider replacing all connections/relative positions with a ConnectionLayout

  /// For performance reasons, keep a strong reference to the block.outputConnection
  private var _outputConnection: Connection!

  /// For performance reasons, keep a strong reference to the block.nextConnection
  private var _nextConnection: Connection!

  /// For performance reasons, keep a strong reference to the block.previousConnection
  private var _previousConnection: Connection!

  /// The relative position of the output connection, expressed as a Workspace coordinate system
  /// unit
  private var _outputConnectionRelativePosition: WorkspacePoint = WorkspacePointZero

  /// The relative position of the next connection, expressed as a Workspace coordinate system unit
  private var _nextConnectionRelativePosition: WorkspacePoint = WorkspacePointZero

  /// The relative position of the previous connection, expressed as a Workspace coordinate system
  /// unit
  private var _previousConnectionRelativePosition: WorkspacePoint = WorkspacePointZero

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
      // TODO:(#28) Scale and offset correctly into the workspace
      block.position = self.absolutePosition
    }
  }

  // MARK: - Initializers

  public override init(block: Block, engine: LayoutEngine) {
    _outputConnection = block.outputConnection
    _nextConnection = block.nextConnection
    _previousConnection = block.previousConnection
    super.init(block: block, engine: engine)
  }

  // MARK: - Super

  public override func performLayout(includeChildren includeChildren: Bool) {
    // TODO:(#41) Potentially move logic from this method into Block.Background to make things
    // easier to follow.
    // TODO:(#41) Handle stroke widths for the background.

    let outputPuzzleTabXOffset = block.outputConnection != nil ?
      self.config.puzzleTabWidth.workspaceUnit : 0
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
    for inputLayout in (inputLayouts as! [DefaultInputLayout]) {
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

      let lastInputLayout = backgroundRow.inputLayouts.last! as! DefaultInputLayout
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
    let notchXOffset = outputPuzzleTabXOffset + self.config.notchWidth.workspaceUnit / 2

    if block.previousConnection != nil {
      _previousConnectionRelativePosition =
        WorkspacePointMake(notchXOffset, self.config.notchHeight.workspaceUnit)
    }

    if block.nextConnection != nil {
      let blockBottomEdge = background.rows.reduce(0, combine: { $0 + $1.rowHeight})
      _nextConnectionRelativePosition =
        WorkspacePointMake(notchXOffset, blockBottomEdge + self.config.notchHeight.workspaceUnit)

      // TODO:(#41) Make the size.height a property of self.background
      // Create room to draw the notch height at the bottom
      size.height += self.config.notchHeight.workspaceUnit
    }

    if block.outputConnection != nil {
      _outputConnectionRelativePosition =
        WorkspacePointMake(0, self.config.puzzleTabHeight.workspaceUnit / 2)
    }

    // Update the size required for this block
    self.contentSize = size

    // Force this block to be redisplayed
    scheduleChangeEventWithFlags(Layout.Flag_NeedsDisplay)
  }
}
