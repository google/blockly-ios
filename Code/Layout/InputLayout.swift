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

  /**
  For inline and external value inputs, the relative x-position of where to begin rendering the
  input connector (ie. the female puzzle piece), expressed as a value in the View coordinate system.
  */
  public var viewInputConnectorStart: CGFloat {
    return self.workspaceLayout.viewUnitFromWorkspaceUnit(inputConnectorStart)
  }
  /// The Workspace coordinate system value of `viewInputConnectorStart`
  private var inputConnectorStart: CGFloat = 0

  /// For inline value inputs, the relative x-position of where to render the ending vertical
  /// edge, expressed as a value in the View coordinate system.
  public var viewInputConnectorEnd: CGFloat {
    return self.workspaceLayout.viewUnitFromWorkspaceUnit(inputConnectorEnd)
  }
  /// The Workspace coordinate system value of `viewInputConnectorEnd`
  private var inputConnectorEnd: CGFloat = 0

  /// For statement inputs, the relative x-position of where to begin rendering the inner vertical
  /// edge of the "C" shape block, expressed as a value in the View coordinate system.
  public var viewStatementIndent: CGFloat {
    return self.workspaceLayout.viewUnitFromWorkspaceUnit(statementIndent)
  }
  /// The Workspace coordinate system value of `viewStatementIndent`
  private var statementIndent: CGFloat = 0

  /// For statement inputs, the amount of x points to offset the notch from the
  /// `viewStatementIndent` value, expressed as a value in the View coordinate system.
  public var viewStatementConnectorStart: CGFloat {
    return self.workspaceLayout.viewUnitFromWorkspaceUnit(statementConnectorStart)
  }
  /// The Workspace coordinate system value of `viewStatementConnectorStart`
  private var statementConnectorStart: CGFloat = 0

  /// For statement inputs, the width of the notch, expressed as a value in the View coordinate
  /// system.
  public var viewStatementConnectorWidth: CGFloat {
    return self.workspaceLayout.viewUnitFromWorkspaceUnit(statementConnectorWidth)
  }
  /// The Workspace coordinate system value of `viewStatementConnectorWidth`
  private var statementConnectorWidth: CGFloat = 0

  /// For statement inputs, the amount of padding to include at the top of "C" shape block,
  /// expressed as a value in the View coordinate system.
  public var viewStatementRowTopPadding: CGFloat {
    return self.workspaceLayout.viewUnitFromWorkspaceUnit(statementRowTopPadding)
  }
  /// The Workspace coordinate system value of `viewStatementRowTopPadding`
  private var statementRowTopPadding: CGFloat = 0

  /// For statement inputs, the amount of padding to include at the bottom of "C" shape block,
  /// expressed as a value in the View coordinate system.
  public var viewStatementRowBottomPadding: CGFloat {
    return self.workspaceLayout.viewUnitFromWorkspaceUnit(statementRowBottomPadding)
  }
  /// The Workspace coordinate system value of `viewStatementFloorRowPaddingHeight`
  private var statementRowBottomPadding: CGFloat = 0

  /// The minimal amount of width required to render `fieldLayouts`, specified as a Workspace
  /// coordinate system unit.
  public var minimalFieldWidthRequired: CGFloat {
    // TODO:(vicng) Add inline padding to the "0" value
    return fieldLayouts.count > 0 ?
      (fieldLayouts.last!.relativePosition.x + fieldLayouts.last!.size.width) : 0
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
    var fieldMaximumYPoint: CGFloat = 0

    // Update relative position/size of fields
    for fieldLayout in fieldLayouts {
      fieldLayout.layoutChildren()

      // TODO:(vicng) Add inline x/y padding
      fieldLayout.relativePosition.x = fieldXOffset
      fieldLayout.relativePosition.y = 0

      // TODO:(vicng) Add x/y padding
      fieldXOffset += fieldLayout.size.width
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
      // TODO:(vicng) Add extra x/y padding
      blockGroupLayout.relativePosition.x = fieldXOffset
      blockGroupLayout.relativePosition.y = 0

      self.inputConnectorStart = blockGroupLayout.relativePosition.x

      let widthRequired: CGFloat
      if self.isInline {
        // TODO:(vicng) Add x padding
        self.inputConnectorEnd =
          blockGroupLayout.relativePosition.x + blockGroupLayout.size.width
        widthRequired = inputConnectorEnd
      } else {
        widthRequired = blockGroupLayout.relativePosition.x + blockGroupLayout.size.width
      }

      // TODO:(vicng) Add y padding
      let heightRequired = max(
        fieldMaximumYPoint, blockGroupLayout.relativePosition.y + blockGroupLayout.size.height)

      self.size = WorkspaceSizeMake(widthRequired, heightRequired)
    case .Statement:
      // If this is the first child for the block layout, we need to add an empty row at the top to
      // begin a "C" shape.
      if self.isFirstChild {
        self.statementRowTopPadding = BlockLayout.sharedConfig.ySeparatorSpace

        // Update field layouts to pad with extra row
        for fieldLayout in fieldLayouts {
          fieldLayout.relativePosition.y += statementRowTopPadding
        }
      }

      // Set statement render properties
      self.statementIndent = fieldXOffset + BlockLayout.sharedConfig.xSeparatorSpace
      self.statementConnectorStart = statementIndent + BlockLayout.sharedConfig.xSeparatorSpace
      self.statementConnectorWidth = BlockLayout.sharedConfig.notchWidth

      // If this is the last child for the block layout, we need to add an empty row at the bottom
      // to end the "C" shape.
      if self.isLastChild {
        self.statementRowBottomPadding = BlockLayout.sharedConfig.ySeparatorSpace
      }

      // Reposition block group layout
      self.blockGroupLayout.relativePosition.x = statementIndent
      self.blockGroupLayout.relativePosition.y = statementRowTopPadding

      // Set total size
      var size = WorkspaceSizeZero
      size.width = max(blockGroupLayout.relativePosition.x + blockGroupLayout.size.width,
        statementConnectorStart + statementConnectorWidth)
      size.height = statementRowTopPadding + statementRowBottomPadding +
        max(blockGroupLayout.relativePosition.y + blockGroupLayout.size.height,
          fieldMaximumYPoint)
      self.size = size
    case .Dummy:
      blockGroupLayout.relativePosition = WorkspacePointZero

      // TODO:(vicng) Add x/y padding
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
      self.inputConnectorStart += widthDifference
      self.blockGroupLayout.relativePosition.x += widthDifference
    }
  }

  // MARK: - Private

  /**
  Resets all render specific properties back to their default values.
  */
  private func resetRenderProperties() {
    self.inputConnectorStart = 0
    self.inputConnectorEnd = 0
    self.statementIndent = 0
    self.statementConnectorStart = 0
    self.statementConnectorWidth = 0
    self.statementRowTopPadding = 0
    self.statementRowBottomPadding = 0
  }
}

// MARK: - InputDelegate

extension InputLayout: InputDelegate {
  public func inputDidChange(input: Input) {
    // TODO:(vicng) Potentially generate an event to update the source block of this input
  }
}
