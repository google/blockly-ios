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
  public let input: Input

  /// The corresponding `BlockGroupLayout` object seeded by `self.input.connectedBlock`.
  public var blockGroupLayout: BlockGroupLayout {
    didSet {
      blockGroupLayout.parentLayout = self
    }
  }

  /// The corresponding layouts for `self.input.fields[]`
  public private(set) var fieldLayouts = [FieldLayout]()

  // Properties used for rendering

  /// The relative x-position of where to begin rendering the right edge of the block, expressed as
  /// a Workspace coordinate system unit.
  public var rightEdge: CGFloat = 0

  /// For inline value inputs, the relative x-position of where to begin rendering the input
  /// connector (ie. the female puzzle piece), expressed as a Workspace coordinate system unit.
  public var inlineConnectorStart: CGFloat = 0

  /// For inline value inputs, the relative x-position of where to finish rendering the input
  /// connector (ie. the female puzzle piece), expressed as a Workspace coordinate system unit.
  public var inlineConnectorEnd: CGFloat = 0

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
    // TODO:(vicng) Add inline padding to the "0" value
    let puzzleTabWidth = (!isInline && input.type == .Value) ?
      BlockLayout.sharedConfig.puzzleTabWidth : 0
    return fieldLayouts.count > 0 ?
      (fieldLayouts.last!.relativePosition.x + fieldLayouts.last!.size.width + puzzleTabWidth) : 0
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

  public required init(input: Input, workspaceLayout: WorkspaceLayout!,
    parentLayout: BlockLayout) {
      self.input = input
      self.blockGroupLayout = BlockGroupLayout(workspaceLayout: workspaceLayout, parentLayout: nil)
      super.init(workspaceLayout: workspaceLayout, parentLayout: parentLayout)
      self.input.delegate = self
      self.blockGroupLayout.parentLayout = self
  }

  // MARK: - Super

  public override var childLayouts: [Layout] {
    return ([blockGroupLayout] as [Layout]) + (fieldLayouts as [Layout])
  }

  public override func layoutChildren() {
    resetRenderProperties()

    var fieldXOffset: CGFloat = 0
    var fieldMaximumHeight: CGFloat = 0
    var fieldMaximumYPoint: CGFloat = 0

    // Update relative position/size of fields
    for fieldLayout in fieldLayouts {
      fieldLayout.layoutChildren()

      // TODO:(vicng) Add inline x/y padding
      fieldLayout.relativePosition.x = fieldXOffset
      fieldLayout.relativePosition.y = 0

      // TODO:(vicng) Add x/y padding
      fieldXOffset += fieldLayout.size.width
      fieldMaximumHeight = max(fieldLayout.size.height, fieldMaximumHeight)
      fieldMaximumYPoint = max(fieldLayout.relativePosition.y + fieldLayout.size.height,
        fieldMaximumYPoint)
    }

    // Update block group layout size
    blockGroupLayout.layoutChildren()

    // Reposition fields/groups based on the input type, set the render properties so
    // the UI will know how to draw the shape of a block, and set the size of the entire
    // InputLayout.
    switch (self.input.type) {
    case .Value:
      // TODO:(vicng) Add extra x/y padding and handle stroke widths of block
      blockGroupLayout.relativePosition.x = fieldXOffset
      blockGroupLayout.relativePosition.y = 0

      let widthRequired: CGFloat
      if self.isInline {
        // TODO:(vicng) Add x padding and handle stroke widths
        self.inlineConnectorStart = blockGroupLayout.relativePosition.x
        self.inlineConnectorEnd =
          blockGroupLayout.relativePosition.x + blockGroupLayout.size.width
        self.rightEdge = blockGroupLayout.relativePosition.x + blockGroupLayout.size.width
        widthRequired = self.rightEdge
      } else {
        // TODO:(vicng) Add x padding and handle stroke widths
        self.rightEdge =
          blockGroupLayout.relativePosition.x + BlockLayout.sharedConfig.puzzleTabWidth
        widthRequired = max(
          blockGroupLayout.relativePosition.x + blockGroupLayout.size.width,
          self.rightEdge)
      }

      // TODO:(vicng) Add y padding
      let heightRequired = max(
        fieldMaximumYPoint,
        blockGroupLayout.relativePosition.y + blockGroupLayout.size.height,
        BlockLayout.sharedConfig.puzzleTabHeight)

      self.size = WorkspaceSizeMake(widthRequired, heightRequired)
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
      self.statementIndent = fieldXOffset + BlockLayout.sharedConfig.xSeparatorSpace
      self.statementConnectorWidth = BlockLayout.sharedConfig.notchWidth
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
        blockGroupLayout.size.height, fieldMaximumHeight, BlockLayout.sharedConfig.ySeparatorSpace)

      // Set total size
      var size = WorkspaceSizeZero
      size.width = max(blockGroupLayout.relativePosition.x + blockGroupLayout.size.width,
        statementIndent + statementConnectorWidth)
      size.height = statementRowTopPadding + statementMiddleHeight + statementRowBottomPadding
      self.size = size
    case .Dummy:
      blockGroupLayout.relativePosition = WorkspacePointZero

      // TODO:(vicng) Add x/y padding
      self.rightEdge = fieldXOffset
      let widthRequired = fieldXOffset
      let heightRequired = max(
        fieldMaximumYPoint, blockGroupLayout.relativePosition.y + blockGroupLayout.size.height)
      self.size = WorkspaceSizeMake(widthRequired, heightRequired)
    }
  }

  // MARK: - Public

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

  // MARK: - Internal

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
    self.size.width += widthDifference
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
      maximizeFieldWidthTo(
        width - self.statementConnectorWidth - BlockLayout.sharedConfig.xSeparatorSpace)
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
      self.size.width += width
      self.rightEdge += width
    }
  }

  // MARK: - Private

  /**
  Resets all render specific properties back to their default values.
  */
  private func resetRenderProperties() {
    self.rightEdge = 0
    self.inlineConnectorStart = 0
    self.inlineConnectorEnd = 0
    self.statementIndent = 0
    self.statementConnectorWidth = 0
    self.statementRowTopPadding = 0
    self.statementRowBottomPadding = 0
    self.statementMiddleHeight = 0
  }
}

// MARK: - InputDelegate

extension InputLayout: InputDelegate {
  public func inputDidChange(input: Input) {
    // TODO:(vicng) Potentially generate an event to update the source block of this input
  }
}
