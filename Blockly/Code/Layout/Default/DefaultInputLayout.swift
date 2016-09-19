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

/*
 A default implementation of `InputLayout`.
 */
@objc(BKYDefaultInputLayout)
public final class DefaultInputLayout: InputLayout {
  // MARK: - Properties

  // TODO:(#34) Consider replacing all connections/relative positions with a ConnectionLayout

  /// For performance reasons, keep a strong reference to the input.connection
  fileprivate var _connection: Connection!

  internal override var absolutePosition: WorkspacePoint {
    didSet {
      // TODO:(#29) This is method is eating into performance. During method execution,
      // "swift_unknownRetainUnowned", "objc_loadWeakRetained", and "objc_...release" are called
      // often and take about 15% of CPU time.

      // Update connection position
      if _connection == nil {
        return
      }

      let connectionPoint: WorkspacePoint
      if input.type == .statement {
        connectionPoint = WorkspacePointMake(
          statementIndent + self.config.workspaceUnitFor(DefaultLayoutConfig.NotchWidth) / 2,
          statementRowTopPadding +
            self.config.workspaceUnitFor(DefaultLayoutConfig.NotchHeight))
      } else if isInline {
        connectionPoint = WorkspacePointMake(
          inlineConnectorPosition.x,
          inlineConnectorPosition.y +
            self.config.workspaceUnitFor(DefaultLayoutConfig.PuzzleTabHeight) / 2)
      } else {
        connectionPoint = WorkspacePointMake(
          rightEdge - self.config.workspaceUnitFor(DefaultLayoutConfig.PuzzleTabWidth),
          self.config.workspaceUnitFor(DefaultLayoutConfig.PuzzleTabHeight) / 2)
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
  public var inlineConnectorPosition: WorkspacePoint = WorkspacePointZero

  /// For inline value inputs, the size of the input connector (ie. the female puzzle piece),
  /// expressed as a Workspace coordinate system unit.
  public var inlineConnectorSize: WorkspaceSize = WorkspaceSizeZero

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
    let puzzleTabWidth = (!isInline && input.type == .value) ?
      (self.config.workspaceUnitFor(DefaultLayoutConfig.PuzzleTabWidth)) : 0
    return fieldWidth + puzzleTabWidth
  }

  public var minimalStatementWidthRequired: CGFloat {
    return statementIndent + statementConnectorWidth
  }

  // MARK: - Initializers

  public override init(input: Input, engine: LayoutEngine, factory: LayoutFactory) throws {
    self._connection = input.connection
    try super.init(input: input, engine: engine, factory: factory)
  }

  // MARK: - Super

  public override func performLayout(includeChildren: Bool) {
    resetRenderProperties()

    // Figure out which block group to render
    let targetBlockGroupLayout = self.blockGroupLayout as BlockGroupLayout

    var fieldXOffset: CGFloat = 0
    var fieldMaximumHeight: CGFloat = 0
    var fieldMaximumYPoint: CGFloat = 0

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
      fieldLayout.edgeInsets.left =
        self.config.workspaceUnitFor(DefaultLayoutConfig.InlineXPadding)
      fieldLayout.edgeInsets.top =
        self.config.workspaceUnitFor(DefaultLayoutConfig.InlineYPadding)
      fieldLayout.edgeInsets.bottom =
        self.config.workspaceUnitFor(DefaultLayoutConfig.InlineYPadding)

      if i == fieldLayouts.count - 1 {
        // Add right padding to the last field
        var addRightEdgeInset = true

        // Special case: Don't add right padding to the last field of an inline dummy input if it's
        // immediately followed by another dummy/value input.
        if self.input.type == .dummy {
          let nextInputLayout = (parentLayout as? BlockLayout)?.inputLayout(after: self)
          if nextInputLayout?.input.type == .value || nextInputLayout?.input.type == .dummy {
            addRightEdgeInset = false
          }
        }

        if addRightEdgeInset {
          fieldLayout.edgeInsets.right =
            self.config.workspaceUnitFor(DefaultLayoutConfig.InlineXPadding)
        }
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
      // TODO:(#41) Handle stroke widths for the inline connector cut-out

      // Position the block group
      targetBlockGroupLayout.relativePosition.x = fieldXOffset
      targetBlockGroupLayout.relativePosition.y = 0

      let widthRequired: CGFloat
      var inlineConnectorMaximumYPoint: CGFloat = 0
      if self.isInline {
        targetBlockGroupLayout.edgeInsets.top =
          self.config.workspaceUnitFor(DefaultLayoutConfig.InlineYPadding)
        targetBlockGroupLayout.edgeInsets.bottom =
          self.config.workspaceUnitFor(DefaultLayoutConfig.InlineYPadding)

        self.inlineConnectorPosition = WorkspacePointMake(
          targetBlockGroupLayout.relativePosition.x,
          targetBlockGroupLayout.relativePosition.y + targetBlockGroupLayout.edgeInsets.top)

        let minimumInlineConnectorSize =
          self.config.workspaceSizeFor(DefaultLayoutConfig.MinimumInlineConnectorSize)
        let inlineConnectorWidth = max(targetBlockGroupLayout.contentSize.width,
          self.config.workspaceUnitFor(DefaultLayoutConfig.PuzzleTabWidth) +
          minimumInlineConnectorSize.width)
        let inlineConnectorHeight =
          max(targetBlockGroupLayout.contentSize.height, minimumInlineConnectorSize.height)
        self.inlineConnectorSize = WorkspaceSizeMake(inlineConnectorWidth, inlineConnectorHeight)
        self.rightEdge = inlineConnectorPosition.x + inlineConnectorSize.width +
          self.config.workspaceUnitFor(DefaultLayoutConfig.InlineXPadding)

        inlineConnectorMaximumYPoint = inlineConnectorPosition.y + inlineConnectorSize.height +
          targetBlockGroupLayout.edgeInsets.bottom
        widthRequired = self.rightEdge
      } else {
        self.rightEdge = targetBlockGroupLayout.relativePosition.x +
          self.config.workspaceUnitFor(DefaultLayoutConfig.PuzzleTabWidth)
        widthRequired = max(
          targetBlockGroupLayout.relativePosition.x + targetBlockGroupLayout.totalSize.width,
          self.rightEdge)
      }

      let heightRequired = max(
        fieldMaximumYPoint,
        inlineConnectorMaximumYPoint,
        targetBlockGroupLayout.relativePosition.y + targetBlockGroupLayout.totalSize.height,
        self.config.workspaceUnitFor(DefaultLayoutConfig.PuzzleTabHeight))

      self.contentSize = WorkspaceSizeMake(widthRequired, heightRequired)
    case .statement:
      // If this is the first child for the block layout or the previous input type was a statement,
      // we need to add an empty row at the top to begin a new "C" shape.
      let previousInputLayout = (parentLayout as? BlockLayout)?.inputLayout(before: self)

      let rowTopPadding = (self.isFirstChild || previousInputLayout?.input.type == .statement) ?
        self.config.workspaceUnitFor(DefaultLayoutConfig.StatementSectionHeight) : 0
      self.statementRowTopPadding = rowTopPadding

      // Update field layouts to pad with extra row
      for fieldLayout in fieldLayouts {
        fieldLayout.relativePosition.y += rowTopPadding
      }

      // Make sure there's some space for the statement indent (eg. if there were no fields
      // specified)
      fieldXOffset = max(fieldXOffset,
        self.config.workspaceUnitFor(DefaultLayoutConfig.InlineXPadding))

      // Set statement render properties
      self.statementIndent = fieldXOffset
      self.statementConnectorWidth =
        self.config.workspaceUnitFor(DefaultLayoutConfig.NotchWidth) +
        self.config.workspaceUnitFor(DefaultLayoutConfig.StatementMinimumConnectorWidth)
      self.rightEdge = statementIndent + statementConnectorWidth

      // If this is the last child for the block layout, we need to add an empty row at the bottom
      // to end the "C" shape.
      self.statementRowBottomPadding = self.isLastChild ?
        self.config.workspaceUnitFor(DefaultLayoutConfig.StatementSectionHeight) : 0

      // Reposition block group layout
      targetBlockGroupLayout.relativePosition.x = statementIndent
      targetBlockGroupLayout.relativePosition.y = statementRowTopPadding

      // TODO:(#41) If more blocks can be added to the last block in the group, add a bit of
      // space to the bottom of the middle part to show this is possible
      self.statementMiddleHeight = max(
        targetBlockGroupLayout.totalSize.height, fieldMaximumHeight,
        self.config.workspaceUnitFor(DefaultLayoutConfig.StatementSectionHeight))

      // Set total size
      var size = WorkspaceSizeZero
      size.width =
        max(targetBlockGroupLayout.relativePosition.x + targetBlockGroupLayout.totalSize.width,
        self.rightEdge)
      size.height = statementRowTopPadding + statementMiddleHeight + statementRowBottomPadding
      self.contentSize = size
    case .dummy:
      targetBlockGroupLayout.relativePosition = WorkspacePointZero

      self.rightEdge = fieldXOffset
      let widthRequired = self.rightEdge
      let heightRequired = fieldMaximumYPoint
      self.contentSize = WorkspaceSizeMake(widthRequired, heightRequired)
    }
  }


  // MARK: - Internal

  /**
  Allow the input layout to use more width when rendering its field layouts.

  If the given width is larger than the minimal amount needed, the layout is resized and its
  elements are repositioned.

  If the given width is not large enough, then all elements in the layout remain unchanged.

  - Parameter width: A width value, specified in the Workspace coordinate system.
  */
  internal func maximizeFieldWidthTo(_ width: CGFloat) {
    let minimalFieldWidthRequired = self.minimalFieldWidthRequired
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
    } else if self.input.type == .value && !self.isInline {
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

   - Parameter width: A width value, specified in the Workspace coordinate system.
   */
  internal func maximizeStatementWidthTo(_ width: CGFloat) {
    if self.input.type == .statement {
      // Maximize the statement width by maximizing the field width
      maximizeFieldWidthTo(width - self.statementConnectorWidth)
    }
  }

  /**
   For statement inputs, extends the right edge of the input layout by a given width. As a
   consequence, the total size of input layout is increased to reflect this.

   For all other inputs, this method does nothing.

   - Parameter width: The width value to extend the right edge, specified in the Workspace
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

  // MARK: - Private

  /**
  Resets all render specific properties back to their default values.
  */
  fileprivate func resetRenderProperties() {
    self.rightEdge = 0
    self.inlineConnectorPosition = WorkspacePointZero
    self.inlineConnectorSize = WorkspaceSizeZero
    self.statementIndent = 0
    self.statementConnectorWidth = 0
    self.statementRowTopPadding = 0
    self.statementRowBottomPadding = 0
    self.statementMiddleHeight = 0
  }
}
