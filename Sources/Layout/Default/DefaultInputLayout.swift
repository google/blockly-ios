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

import UIKit

/**
 A default implementation of `InputLayout`.
 */
@objc(BKYDefaultInputLayout)
@objcMembers public final class DefaultInputLayout: InputLayout {
  // MARK: - Properties

  // TODO(#34): Consider replacing all connections/relative positions with a ConnectionLayout

  /**
   For performance reasons, create a variable that can be used to reference a `nil`
   `Connection`.

   Normally, `_connection` would be defined as an optional variable, but there is an
   implicit objc-retain/release overhead when using optionals. So instead, `_connection` is defined
   as a non-optional and assigned to this variable if it is actually `nil`. This reduces
   retain/release overhead and improves performance.
   */
  private static let nilConnection = Connection(type: .outputValue)

  /// For performance reasons, keep a strong reference to the input.connection
  fileprivate let _connection: Connection

  /// The amount which the notch should be offset from the left edge, in the Workspace
  // coordinate system.
  private var notchXOffset: CGFloat = 0

  /// The notch width that this input should use, in the Workspace coordinate system.
  private var notchWidth: CGFloat = 0

  /// The notch height that this input should use, in the Workspace coordinate system.
  private var notchHeight: CGFloat = 0

  /// The puzzle tab height that this input should use, in the Workspace coordinate system.
  private var puzzleTabHeight: CGFloat = 0

  /// The puzzle tab height that this input should use, in the Workspace coordinate system.
  private var puzzleTabWidth: CGFloat = 0

  internal override var absolutePosition: WorkspacePoint {
    didSet {
      if _connection === DefaultInputLayout.nilConnection {
        return
      }

      // Update connection position
      let connectionPoint: WorkspacePoint
      if input.type == .statement {
        connectionPoint = WorkspacePoint(
          x: statementIndent + notchXOffset + notchWidth / 2,
          y: statementRowTopPadding + notchHeight)
      } else if input.inline {
        connectionPoint = WorkspacePoint(x: inlineConnectorPosition.x, y: firstLineHeight / 2.0)
      } else {
        connectionPoint = WorkspacePoint(x: rightEdge - puzzleTabWidth, y: firstLineHeight / 2.0)
      }

      _connection.moveToPosition(self.absolutePosition, withOffset: connectionPoint)
    }
  }

  // Properties used for rendering

  /// The relative x-position of where to begin rendering the right edge of the block, expressed as
  /// a Workspace coordinate system unit.
  public var rightEdge: CGFloat = 0

  /// For inline value inputs, the relative position of where to begin rendering the input
  /// connector (ie. the female puzzle piece), expressed as a Workspace coordinate system unit.
  public var inlineConnectorPosition: WorkspacePoint = WorkspacePoint.zero

  /// For inline value inputs, the size of the input connector (ie. the female puzzle piece),
  /// expressed as a Workspace coordinate system unit.
  public var inlineConnectorSize: WorkspaceSize = WorkspaceSize.zero

  /// For statement inputs, the relative x-position of where to begin rendering the inner left
  /// edge of the "C" shaped block, expressed as a Workspace coordinate system unit.
  public var statementIndent: CGFloat = 0

  /// For statement inputs, the width of the notch of the inner ceiling of the "C" shaped block,
  /// expressed as a Workspace coordinate system unit.
  public var statementConnectorWidth: CGFloat = 0

  /// For statement inputs, the amount of padding to include at the top of "C" shaped block,
  /// expressed as a Workspace coordinate system unit.
  public var statementRowTopPadding: CGFloat = 0

  /// For statement inputs, the amount of padding to include at the bottom of "C" shaped block,
  /// expressed as a Workspace coordinate system unit.
  public var statementRowBottomPadding: CGFloat = 0

  /// For statement inputs, the height of the middle part of the "C" shaped block,
  /// expressed as a Workspace coordinate system unit.
  public var statementMiddleHeight: CGFloat = 0

  /// The minimal amount of width required to render `fieldLayouts`, specified as a Workspace
  /// coordinate system unit.
  public var minimalFieldWidthRequired: CGFloat {
    let fieldWidth = fieldLayouts.count > 0 ?
      (fieldLayouts.last!.relativePosition.x + fieldLayouts.last!.totalSize.width) : 0
    let puzzleTabWidth = (!input.inline && input.type == .value) ?
      (self.config.workspaceUnit(for: DefaultLayoutConfig.PuzzleTabWidth)) : 0
    // Special case where field padding is added for statements in case no fields were added
    let statementPaddingWidth = (input.type == .statement && fieldLayouts.isEmpty) ?
      config.workspaceUnit(for: LayoutConfig.InlineXPadding) : 0

    return fieldWidth + puzzleTabWidth + statementPaddingWidth
  }

  /// The minimal amount of width required to render the child statements of the input, specified as
  /// a Workspace coordinate system unit.
  public var minimalStatementWidthRequired: CGFloat {
    return statementIndent + statementConnectorWidth
  }

  // MARK: - Initializers

  /**
   Initializes the default input layout.

   - parameter input: The `Input` model object associated with this layout.
   - parameter engine: The `LayoutEngine` to associate with the new layout.
   - parameter factory: The `BlockFactory` to use to build blocks.
   - throws:
     `BlocklyError`: Occurs if the `LayoutFactory` cannot build a block.
   */
  public override init(input: Input, engine: LayoutEngine, factory: LayoutFactory) throws {
    self._connection = input.connection ?? DefaultInputLayout.nilConnection
    try super.init(input: input, engine: engine, factory: factory)
  }

  // MARK: - Super

  public override func performLayout(includeChildren: Bool) {
    resetRenderProperties()

    // Update render values
    notchXOffset = config.workspaceUnit(for: DefaultLayoutConfig.NotchXOffset)
    notchWidth = config.workspaceUnit(for: DefaultLayoutConfig.NotchWidth)
    notchHeight = config.workspaceUnit(for: DefaultLayoutConfig.NotchHeight)
    puzzleTabHeight = config.workspaceUnit(for: DefaultLayoutConfig.PuzzleTabHeight)
    puzzleTabWidth = config.workspaceUnit(for: DefaultLayoutConfig.PuzzleTabWidth)
    let lineWidth = config.workspaceUnit(for: DefaultLayoutConfig.BlockLineWidthRegular)

    // Figure out which block group to render
    let targetBlockGroupLayout = self.blockGroupLayout as BlockGroupLayout

    var fieldXOffset: CGFloat = 0
    var fieldMaximumHeight: CGFloat = 0
    var fieldMaximumYPoint: CGFloat = 0
    var inlineConnectorMaximumYPoint: CGFloat = 0

    // Update relative position/size of fields
    for i in 0 ..< fieldLayouts.count {
      let fieldLayout = fieldLayouts[i]
      if includeChildren {
        fieldLayout.performLayout(includeChildren: true)
      }

      // Position the field
      fieldLayout.relativePosition.x = fieldXOffset
      fieldLayout.relativePosition.y = 0

      // Add inline x/y padding for each field
      fieldLayout.edgeInsets.leading =
        self.config.workspaceUnit(for: DefaultLayoutConfig.InlineXPadding)
      fieldLayout.edgeInsets.top =
        self.config.workspaceUnit(for: DefaultLayoutConfig.InlineYPadding)
      fieldLayout.edgeInsets.bottom =
        self.config.workspaceUnit(for: DefaultLayoutConfig.InlineYPadding)

      if i == fieldLayouts.count - 1 && isLastInputOfBlockRow() {
        // Add right padding to the last field if it's at the end of the row
        fieldLayout.edgeInsets.trailing =
          self.config.workspaceUnit(for: DefaultLayoutConfig.InlineXPadding)
      }

      fieldXOffset += fieldLayout.totalSize.width
      fieldMaximumHeight = max(fieldLayout.totalSize.height, fieldMaximumHeight)
      fieldMaximumYPoint = max(fieldLayout.relativePosition.y + fieldLayout.totalSize.height,
        fieldMaximumYPoint)
    }

    // Update block group layout size
    if includeChildren {
      targetBlockGroupLayout.performLayout(includeChildren: true)
    }

    // Reposition fields/groups based on the input type, set the render properties so
    // the UI will know how to draw the shape of a block, and set the size of the entire
    // InputLayout.
    switch (self.input.type) {
    case .value:
      // Position the block group
      targetBlockGroupLayout.relativePosition.x = fieldXOffset
      targetBlockGroupLayout.relativePosition.y = 0

      let widthRequired: CGFloat
      if input.inline {
        // Don't account for top/bottom line widths, to reduce unnecessary vertical height.
        targetBlockGroupLayout.edgeInsets.top =
          self.config.workspaceUnit(for: DefaultLayoutConfig.InlineConnectorYPadding)
        targetBlockGroupLayout.edgeInsets.bottom =
          self.config.workspaceUnit(for: DefaultLayoutConfig.InlineConnectorYPadding)
        targetBlockGroupLayout.edgeInsets.leading =
          self.config.workspaceUnit(for: DefaultLayoutConfig.InlineConnectorXPadding) + lineWidth

        // Add trailing padding if this is the end of the row
        let nextInputLayout = (parentLayout as? BlockLayout)?.inputLayout(after: self)
        if nextInputLayout == nil || nextInputLayout?.input.type == .statement {
          targetBlockGroupLayout.edgeInsets.trailing =
            config.workspaceUnit(for: DefaultLayoutConfig.InlineConnectorXPadding) + lineWidth
        } else {
          targetBlockGroupLayout.edgeInsets.trailing = lineWidth
        }

        self.inlineConnectorPosition = WorkspacePoint(
          x: targetBlockGroupLayout.relativePosition.x + targetBlockGroupLayout.edgeInsets.leading,
          y: targetBlockGroupLayout.relativePosition.y + targetBlockGroupLayout.edgeInsets.top)

        let minimumInlineConnectorSize =
          self.config.workspaceSize(for: DefaultLayoutConfig.InlineConnectorMinimumSize)
        let inlineConnectorWidth = max(targetBlockGroupLayout.contentSize.width,
          puzzleTabWidth + minimumInlineConnectorSize.width)
        let inlineConnectorHeight =
          max(targetBlockGroupLayout.contentSize.height, minimumInlineConnectorSize.height)
        self.inlineConnectorSize = WorkspaceSize(width: inlineConnectorWidth,
                                                 height: inlineConnectorHeight)
        self.rightEdge = inlineConnectorPosition.x + inlineConnectorSize.width +
          targetBlockGroupLayout.edgeInsets.trailing

        inlineConnectorMaximumYPoint = inlineConnectorPosition.y + inlineConnectorSize.height +
          targetBlockGroupLayout.edgeInsets.bottom
        widthRequired = self.rightEdge
      } else {
        self.rightEdge = targetBlockGroupLayout.relativePosition.x + puzzleTabWidth
        widthRequired = max(
          targetBlockGroupLayout.relativePosition.x + targetBlockGroupLayout.totalSize.width,
          self.rightEdge)
      }

      let heightRequired = max(
        fieldMaximumYPoint,
        inlineConnectorMaximumYPoint,
        targetBlockGroupLayout.relativePosition.y + targetBlockGroupLayout.totalSize.height,
        puzzleTabHeight)

      self.contentSize = WorkspaceSize(width: widthRequired, height: heightRequired)
    case .statement:
      // If this is the first child for the block layout or the previous input type was a statement,
      // we need to add an empty row at the top to begin a new "C" shape.
      let previousInputLayout = (parentLayout as? BlockLayout)?.inputLayout(before: self)

      let rowTopPadding = (self.isFirstChild || previousInputLayout?.input.type == .statement) ?
        self.config.workspaceUnit(for: DefaultLayoutConfig.StatementSectionHeight) : 0
      self.statementRowTopPadding = rowTopPadding

      // Update field layouts to pad with extra row
      for fieldLayout in fieldLayouts {
        fieldLayout.relativePosition.y += rowTopPadding
      }

      // Make sure there's some space for the statement indent (eg. if there were no fields
      // specified)
      fieldXOffset = max(fieldXOffset,
        self.config.workspaceUnit(for: DefaultLayoutConfig.StatementMinimumSectionWidth))

      // Set statement render properties
      self.statementIndent = fieldXOffset
      self.statementConnectorWidth =
        notchXOffset + notchWidth +
        self.config.workspaceUnit(for: DefaultLayoutConfig.StatementMinimumConnectorWidth)
      self.rightEdge = statementIndent + statementConnectorWidth

      // If this is the last child for the block layout, we need to add an empty row at the bottom
      // to end the "C" shape.
      self.statementRowBottomPadding = self.isLastChild ?
        self.config.workspaceUnit(for: DefaultLayoutConfig.StatementSectionHeight) : 0

      // Reposition block group layout
      targetBlockGroupLayout.relativePosition.x = statementIndent
      targetBlockGroupLayout.relativePosition.y = statementRowTopPadding

      // TODO(#41): If more blocks can be added to the last block in the group, add a bit of
      // space to the bottom of the middle part to show this is possible
      self.statementMiddleHeight = max(
        targetBlockGroupLayout.totalSize.height, fieldMaximumHeight,
        self.config.workspaceUnit(for: DefaultLayoutConfig.StatementSectionHeight))

      // Set total size
      var size = WorkspaceSize.zero
      size.width =
        max(targetBlockGroupLayout.relativePosition.x + targetBlockGroupLayout.totalSize.width,
        self.rightEdge)
      size.height = statementRowTopPadding + statementMiddleHeight + statementRowBottomPadding
      self.contentSize = size
    case .dummy:
      targetBlockGroupLayout.relativePosition = WorkspacePoint.zero

      self.rightEdge = fieldXOffset
      let widthRequired = self.rightEdge
      let heightRequired = fieldMaximumYPoint
      self.contentSize = WorkspaceSize(width: widthRequired, height: heightRequired)
    }

    // Figure out the height of the first line
    if let firstBlockLayout = targetBlockGroupLayout.blockLayouts.first {
      if input.inline {
        let blockLayoutFirstLine =
          targetBlockGroupLayout.relativePosition.y + targetBlockGroupLayout.edgeInsets.top +
            firstBlockLayout.firstLineHeight + targetBlockGroupLayout.edgeInsets.bottom
        firstLineHeight = max(fieldMaximumYPoint, blockLayoutFirstLine)
      } else {
        firstLineHeight = max(fieldMaximumYPoint, firstBlockLayout.firstLineHeight)
      }
    } else if input.inline {
      firstLineHeight = max(fieldMaximumYPoint, inlineConnectorMaximumYPoint)
    } else {
      firstLineHeight = fieldMaximumYPoint
    }
  }


  // MARK: - Internal

  /**
  Allow the input layout to use more width when rendering its field layouts.

  If the given width is larger than the minimal amount needed, the layout is resized and its
  elements are repositioned.

  If the given width is not large enough, then all elements in the layout remain unchanged.

  - parameter width: A width value, specified in the Workspace coordinate system.
  */
  internal func maximizeField(toWidth width: CGFloat) {
    if width <= minimalFieldWidthRequired {
      return
    }

    let widthDifference = width - minimalFieldWidthRequired
    self.contentSize.width += widthDifference
    self.rightEdge += widthDifference

    // Shift fields based on new width and alignment
    if self.input.alignment == .center || self.input.alignment == .right {
      let shiftAmount = (self.input.alignment == .center) ?
        floor(widthDifference / 2) : widthDifference
      for fieldLayout in fieldLayouts {
        fieldLayout.relativePosition.x += shiftAmount
      }
    }

    // Update block group layout and render properties
    if self.input.type == .statement {
      self.statementIndent += widthDifference
      self.blockGroupLayout.relativePosition.x += widthDifference
    } else if self.input.type == .value && !input.inline {
      self.blockGroupLayout.relativePosition.x += widthDifference
    }
  }

  /**
   For statement inputs, allow the input layout to use more width when rendering its
   statement.
   For all other inputs, this method does nothing.

   If the given width is larger than the minimal amount needed, the layout is resized and its
   elements are repositioned.

   If the given width is not large enough, then all elements in the layout remain unchanged.

   - parameter width: A width value, specified in the Workspace coordinate system.
   */
  internal func maximizeStatement(toWidth width: CGFloat) {
    if self.input.type == .statement {
      // Maximize the statement width by maximizing the field width
      maximizeField(toWidth: width - self.statementConnectorWidth)
    }
  }

  /**
   For statement inputs, extends the right edge of the input layout by a given width. As a
   consequence, the total size of input layout is increased to reflect this.

   For all other inputs, this method does nothing.

   - parameter width: The width value to extend the right edge, specified in the Workspace
   coordinate system. If this value is less than or equal to 0, this method does nothing.
   */
  internal func extendStatementRightEdgeBy(_ width: CGFloat) {
    if self.input.type == .statement && width > 0 {
      // Extend the right edge
      self.rightEdge += width

      // Update the content size to account for this change
      self.contentSize.width = max(self.contentSize.width, self.rightEdge)
    }
  }

  /**
   Vertically aligns the first line of content inside the input layout, using a given row height.

   - parameter rowHeight: The height that should be used for the first line of content.
   */
  internal func verticallyAlignRow(toHeight rowHeight: CGFloat) {
    guard rowHeight >= firstLineHeight else { return }

    firstLineHeight = rowHeight

    // Update all fields to align to this new line height
    for fieldLayout in fieldLayouts {
      fieldLayout.relativePosition.y += max((rowHeight - fieldLayout.totalSize.height) / 2.0, 0)
    }

    if input.type == .value {
      // Check the block group layout or inline connector to see if they need to adjust to their
      // positions to match the new line height.
      var relativePositionDelta: CGFloat = 0
      if let firstBlockLayout = blockGroupLayout.blockLayouts.first {
        let blockLayoutFirstLineHeight = blockGroupLayout.edgeInsets.top +
          firstBlockLayout.firstLineHeight + blockGroupLayout.edgeInsets.bottom
        relativePositionDelta =
          (rowHeight - blockLayoutFirstLineHeight) / 2.0 - blockGroupLayout.relativePosition.y
      } else if input.inline {
        relativePositionDelta =
          (rowHeight - inlineConnectorSize.height) / 2.0 - inlineConnectorPosition.y
      }

      if relativePositionDelta > 0 {
        blockGroupLayout.relativePosition.y += relativePositionDelta
        if input.inline {
          inlineConnectorPosition.y += relativePositionDelta
        }
        contentSize =
          LayoutHelper.sizeThatFitsLayout(blockGroupLayout, fromInitialSize: contentSize)
      }
    }
  }

  // MARK: - Private

  fileprivate func isLastInputOfBlockRow() -> Bool {
    if let block = input.sourceBlock, !block.inputsInline {
      // This is the last input for the row since inputs are not inline
      return true
    }
    if input.type == .statement {
      // Statements are always the last input for their row
      return true
    }
    if input.type == .dummy {
      let nextInputLayout = (parentLayout as? BlockLayout)?.inputLayout(after: self)
      if nextInputLayout == nil || nextInputLayout?.input.type == .statement {
        // This is the last dummy input or the next input is a statement, so we're at the end
        return true
      }
    }
    return false
  }

  /**
  Resets all render specific properties back to their default values.
  */
  fileprivate func resetRenderProperties() {
    self.rightEdge = 0
    self.inlineConnectorPosition = WorkspacePoint.zero
    self.inlineConnectorSize = WorkspaceSize.zero
    self.statementIndent = 0
    self.statementConnectorWidth = 0
    self.statementRowTopPadding = 0
    self.statementRowBottomPadding = 0
    self.statementMiddleHeight = 0
    firstLineHeight = 0
  }
}
