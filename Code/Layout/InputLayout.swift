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

import UIKit

/*
Stores information for positioning `Input` areas on-screen.
*/
@objc(BKYInputLayout)
public class InputLayout: Layout {
  // MARK: - Properties

  /// The target `Input` to layout
  public unowned let input: Input

  internal override var absolutePosition: WorkspacePoint {
    didSet {
      // Update connection position
      guard let connection = self.input.connection else {
        return
      }

      let connectionPoint: WorkspacePoint
      if input.type == .Statement {
        connectionPoint = WorkspacePointMake(
          statementIndent + BlockLayout.sharedConfig.notchWidth / 2,
          statementRowTopPadding + BlockLayout.sharedConfig.notchHeight)
      } else if isInline {
        connectionPoint = WorkspacePointMake(
          inlineConnectorPosition.x,
          inlineConnectorPosition.y + BlockLayout.sharedConfig.puzzleTabHeight / 2)
      } else {
        connectionPoint = WorkspacePointMake(
          rightEdge - BlockLayout.sharedConfig.puzzleTabWidth,
          BlockLayout.sharedConfig.puzzleTabHeight / 2)
      }

      connection.moveToPosition(self.absolutePosition, withOffset: connectionPoint)
    }
  }

  /// The corresponding `BlockGroupLayout` object seeded by `self.input.connectedBlock`.
  public private(set) var blockGroupLayout: BlockGroupLayout

  /// The corresponding layouts for `self.input.fields[]`
  public private(set) var fieldLayouts = [FieldLayout]()

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
    let puzzleTabWidth = (!isInline && input.type == .Value) ?
      (BlockLayout.sharedConfig.puzzleTabWidth) : 0
    return fieldWidth + puzzleTabWidth
  }

  public var minimalStatementWidthRequired: CGFloat {
    return statementIndent + statementConnectorWidth
  }

  /// Flag for if this input is the first child in its parent's block layout
  public var isFirstChild: Bool {
    return (parentLayout as? BlockLayout)?.inputLayouts.first == self ?? false
  }

  /// Flag for if this input is the last child in its parent's block layout
  public var isLastChild: Bool {
    return (parentLayout as? BlockLayout)?.inputLayouts.last == self ?? false
  }

  /// Flag for if its parent block renders its inputs inline
  private var isInline: Bool {
    return (parentLayout as? BlockLayout)?.block.inputsInline ?? false
  }

  // MARK: - Initializers

  public required init(input: Input, workspaceLayout: WorkspaceLayout) {
    self.input = input
    self.blockGroupLayout = BlockGroupLayout(workspaceLayout: workspaceLayout)
    super.init(workspaceLayout: workspaceLayout)

    self.blockGroupLayout.parentLayout = self
  }

  // MARK: - Super

  public override func performLayout(includeChildren includeChildren: Bool) {
    resetRenderProperties()

    var fieldXOffset: CGFloat = 0
    var fieldMaximumHeight: CGFloat = 0
    var fieldMaximumYPoint: CGFloat = 0

    // Update relative position/size of fields
    for (var i = 0; i < fieldLayouts.count; i++) {
      let fieldLayout = fieldLayouts[i]
      if includeChildren {
        fieldLayout.performLayout(includeChildren: true)
      }

      // Position the field
      fieldLayout.relativePosition.x = fieldXOffset
      fieldLayout.relativePosition.y = 0

      // Add inline x/y padding for each field
      fieldLayout.edgeInsets.left = BlockLayout.sharedConfig.xSeparatorSpace
      fieldLayout.edgeInsets.top = BlockLayout.sharedConfig.inlineYPadding
      fieldLayout.edgeInsets.bottom = BlockLayout.sharedConfig.inlineYPadding

      if i == fieldLayouts.count - 1 {
        // Add right padding to the last field
        var addRightEdgeInset = true

        // Special case: Don't add right padding to the last field of an inline dummy input if it's
        // immediately followed by another dummy/value input.
        if self.input.type == .Dummy {
          let nextInputLayout = (parentLayout as? BlockLayout)?.inputLayoutAfterLayout(self)
          if nextInputLayout?.input.type == .Value || nextInputLayout?.input.type == .Dummy {
            addRightEdgeInset = false
          }
        }

        if addRightEdgeInset {
          fieldLayout.edgeInsets.right = BlockLayout.sharedConfig.xSeparatorSpace
        }
      }

      fieldXOffset += fieldLayout.totalSize.width
      fieldMaximumHeight = max(fieldLayout.totalSize.height, fieldMaximumHeight)
      fieldMaximumYPoint = max(fieldLayout.relativePosition.y + fieldLayout.totalSize.height,
        fieldMaximumYPoint)
    }

    // Update block group layout size
    if includeChildren {
      blockGroupLayout.performLayout(includeChildren: true)
    }

    // Reposition fields/groups based on the input type, set the render properties so
    // the UI will know how to draw the shape of a block, and set the size of the entire
    // InputLayout.
    switch (self.input.type) {
    case .Value:
      // TODO:(vicng) Handle stroke widths for the inline connector cut-out

      // Position the block group
      blockGroupLayout.relativePosition.x = fieldXOffset
      blockGroupLayout.relativePosition.y = 0

      let widthRequired: CGFloat
      var inlineConnectorMaximumYPoint: CGFloat = 0
      if self.isInline {
        blockGroupLayout.edgeInsets.top = BlockLayout.sharedConfig.inlineYPadding
        blockGroupLayout.edgeInsets.bottom = BlockLayout.sharedConfig.inlineYPadding

        self.inlineConnectorPosition = WorkspacePointMake(
          blockGroupLayout.relativePosition.x,
          blockGroupLayout.relativePosition.y + blockGroupLayout.edgeInsets.top)
        self.inlineConnectorSize = WorkspaceSizeMake(
          max(blockGroupLayout.contentSize.width,
            BlockLayout.sharedConfig.puzzleTabWidth + BlockLayout.sharedConfig.xSeparatorSpace),
          max(blockGroupLayout.contentSize.height, BlockLayout.sharedConfig.minimumBlockHeight))
        self.rightEdge = inlineConnectorPosition.x + inlineConnectorSize.width +
          BlockLayout.sharedConfig.xSeparatorSpace

        inlineConnectorMaximumYPoint = inlineConnectorPosition.y + inlineConnectorSize.height +
          blockGroupLayout.edgeInsets.bottom
        widthRequired = self.rightEdge
      } else {
        self.rightEdge =
          blockGroupLayout.relativePosition.x + BlockLayout.sharedConfig.puzzleTabWidth
        widthRequired = max(
          blockGroupLayout.relativePosition.x + blockGroupLayout.totalSize.width,
          self.rightEdge)
      }

      let heightRequired = max(
        fieldMaximumYPoint,
        inlineConnectorMaximumYPoint,
        blockGroupLayout.relativePosition.y + blockGroupLayout.totalSize.height,
        BlockLayout.sharedConfig.puzzleTabHeight)

      self.contentSize = WorkspaceSizeMake(widthRequired, heightRequired)
    case .Statement:
      // If this is the first child for the block layout or the previous input type was a statement,
      // we need to add an empty row at the top to begin a new "C" shape.
      let previousInputLayout = (parentLayout as? BlockLayout)?.inputLayoutBeforeLayout(self)

      let rowTopPadding = (self.isFirstChild || previousInputLayout?.input.type == .Statement) ?
        BlockLayout.sharedConfig.ySeparatorSpace : 0
      self.statementRowTopPadding = rowTopPadding

      // Update field layouts to pad with extra row
      for fieldLayout in fieldLayouts {
        fieldLayout.relativePosition.y += rowTopPadding
      }

      // Set statement render properties
      self.statementIndent = fieldXOffset
      self.statementConnectorWidth = BlockLayout.sharedConfig.notchWidth +
        BlockLayout.sharedConfig.xSeparatorSpace
      self.rightEdge = statementIndent + statementConnectorWidth

      // If this is the last child for the block layout, we need to add an empty row at the bottom
      // to end the "C" shape.
      self.statementRowBottomPadding = self.isLastChild ?
        BlockLayout.sharedConfig.ySeparatorSpace : 0

      // Reposition block group layout
      self.blockGroupLayout.relativePosition.x = statementIndent
      self.blockGroupLayout.relativePosition.y = statementRowTopPadding

      // TODO:(vicng) If more blocks can be added to the last block in the group, add a bit of
      // space to the bottom of the middle part to show this is possible
      self.statementMiddleHeight = max(
        blockGroupLayout.totalSize.height, fieldMaximumHeight,
        BlockLayout.sharedConfig.ySeparatorSpace)

      // Set total size
      var size = WorkspaceSizeZero
      size.width = max(blockGroupLayout.relativePosition.x + blockGroupLayout.totalSize.width,
        self.rightEdge)
      size.height = statementRowTopPadding + statementMiddleHeight + statementRowBottomPadding
      self.contentSize = size
    case .Dummy:
      blockGroupLayout.relativePosition = WorkspacePointZero

      self.rightEdge = fieldXOffset
      let widthRequired = self.rightEdge
      let heightRequired = fieldMaximumYPoint
      self.contentSize = WorkspaceSizeMake(widthRequired, heightRequired)
    }
  }

  // MARK: - Internal

  /**
  Appends a fieldLayout to `self.fieldLayouts` and sets its `parentLayout` to this instance.

  - Parameter fieldLayout: The `FieldLayout` to append.
  */
  public func appendFieldLayout(fieldLayout: FieldLayout) {
    fieldLayout.parentLayout = self
    fieldLayouts.append(fieldLayout)
  }

  /**
  Removes `self.fieldLayouts[index]`, sets its `parentLayout` to nil, and returns it.

  - Parameter index: The index to remove from `self.fieldLayouts`.
  - Returns: The `FieldLayout` that was removed.
  */
  public func removeFieldLayoutAtIndex(index: Int) -> FieldLayout {
    let fieldLayout = fieldLayouts.removeAtIndex(index)
    fieldLayout.parentLayout = nil
    return fieldLayout
  }

  /**
  Allow the input layout to use more width when rendering its field layouts.

  If the given width is larger than the minimal amount needed, the layout is resized and its
  elements are repositioned.

  If the given width is not large enough, then all elements in the layout remain unchanged.

  - Parameter width: A width value, specified in the Workspace coordinate system.
  */
  internal func maximizeFieldWidthTo(width: CGFloat) {
    let minimalFieldWidthRequired = self.minimalFieldWidthRequired
    if width <= minimalFieldWidthRequired {
      return
    }

    let widthDifference = width - minimalFieldWidthRequired
    self.contentSize.width += widthDifference
    self.rightEdge += widthDifference

    // Shift fields based on new width and alignment
    if self.input.alignment == .Centre || self.input.alignment == .Right {
      let shiftAmount = (self.input.alignment == .Centre) ?
        floor(widthDifference / 2) : widthDifference
      for fieldLayout in fieldLayouts {
        fieldLayout.relativePosition.x += shiftAmount
      }
    }

    // Update block group layout and render properties
    if self.input.type == .Statement {
      self.statementIndent += widthDifference
      self.blockGroupLayout.relativePosition.x += widthDifference
    } else if self.input.type == .Value && !self.isInline {
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
  internal func maximizeStatementWidthTo(width: CGFloat) {
    if self.input.type == .Statement {
      // Maximize the statement width by maximizing the field width
      maximizeFieldWidthTo(width - self.statementConnectorWidth)
    }
  }

  /**
  For statement inputs, extends the right edge of the input layout by a given width. As a
  consequence, the total size of input layout is increased to reflect this.

  For all other inputs, this method does nothing.

  - Parameter width: The width value to extend the right edge, specified in the Workspace coordinate
  system. If this value is less than or equal to 0, this method does nothing.
  */
  internal func extendStatementRightEdgeBy(width: CGFloat) {
    if self.input.type == .Statement && width > 0 {
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
  private func resetRenderProperties() {
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
