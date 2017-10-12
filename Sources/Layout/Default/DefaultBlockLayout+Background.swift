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

extension DefaultBlockLayout {
  /**
  Information for rendering the background of a `DefaultBlockLayout`.
  */
  @objc(BKYDefaultBlockLayoutBackground)
  @objcMembers public final class Background: NSObject {
    // MARK: - Properties

    /// Flag if the top-left corner should be square.
    public fileprivate(set) var squareTopLeftCorner: Bool = false

    /// Flag if the bottom-left corner should be rounded
    public fileprivate(set) var squareBottomLeftCorner: Bool = false

    /// Flag if a previous statement connector should be rendered at the top of the block
    public fileprivate(set) var previousStatementConnector: Bool = false

    /// Flag if a next statement connector should be rendered at the bottom of the block
    public fileprivate(set) var nextStatementConnector: Bool = false

    /// Flag if a output connector should be rendered on the left side of the block
    public fileprivate(set) var outputConnector: Bool = false

    /// The line height for the first line of content inside the block.
    /// The output connector puzzle tab should be rendered vertically centered relative to this
    /// height.
    public internal(set) var firstLineHeight: CGFloat = 0

    /// The hat the block should render.
    public fileprivate(set) var hat: Block.Style.HatType = Block.Style.hatNone

    /// The position of the block's leading X edge offset, specified as a Workspace coordinate
    /// system unit, relative to its entire bounding box.
    /// (e.g. In LTR, this is the X offset of the block's left edge.)
    public fileprivate(set) var leadingEdgeXOffset: CGFloat = 0

    /// The position of the block's top Y edge offset, specified as a Workspace coordinate
    /// system unit.
    public fileprivate(set) var leadingEdgeYOffset: CGFloat = 0

    /// The rows for this block
    public fileprivate(set) var rows = [BackgroundRow]()

    // MARK: - Public

    /**
    Updates all render properties from a given block layout.

    - parameter layout: The block layout.
    */
    public func updateRenderProperties(fromBlockLayout layout: DefaultBlockLayout) {
      self.outputConnector = (layout.block.outputConnection != nil)
      self.previousStatementConnector = (layout.block.previousConnection != nil)
      self.nextStatementConnector = (layout.block.nextConnection != nil)

      if !previousStatementConnector && !outputConnector {
        self.hat = layout.block.style.hat ?? layout.config.string(for: DefaultLayoutConfig.BlockHat)
      } else {
        self.hat = Block.Style.hatNone
      }

      self.leadingEdgeXOffset = outputConnector ?
        layout.config.workspaceUnit(for: DefaultLayoutConfig.PuzzleTabWidth) : 0
      self.leadingEdgeYOffset = (hat == Block.Style.hatCap) ?
        layout.config.workspaceSize(for: DefaultLayoutConfig.BlockHatCapSize).height : 0

      if layout.block.outputConnection != nil {
        self.squareTopLeftCorner = true
        self.squareBottomLeftCorner = true
      } else {
        self.squareTopLeftCorner = false
        self.squareBottomLeftCorner = false
        // If this block is in the middle of a stack, square the corners.
        let previousBlock = layout.block.previousConnection?.targetConnection?.sourceBlock
        if previousBlock?.nextBlock == self {
          self.squareTopLeftCorner = true
        }
        if layout.block.nextBlock != nil {
          self.squareBottomLeftCorner = true
        }
      }
      firstLineHeight = layout.firstLineHeight
    }

    /**
    Append a new row to `rows`.
    
    - parameter row: The row to append.
    */
    public func appendRow(_ row: BackgroundRow) {
      rows.append(row)
    }

    /**
    Removes all items inside `rows`.
    */
    public func removeAllRows() {
      rows.removeAll()
    }
  }

  /**
  Information for rendering a row inside a block.
  */
  @objc(BKYBlockLayoutBackgroundRow)
  @objcMembers public final class BackgroundRow: NSObject {
    // MARK: - Properties

    /// Flag if a output connector should be rendered on the right side of the row
    public var outputConnector: Bool = false

    /// Flag if this row represents a "C" shaped statement block.
    public var isStatement: Bool = false

    /// The relative x-position of where to begin rendering the right edge of the block, expressed
    /// as a Workspace coordinate system unit. Note, this is the left edge in RTL rendering.
    public var rightEdge: CGFloat = 0

    /// The amount of padding to include at the top of the row, expressed as a Workspace
    /// coordinate system unit.
    public var topPadding: CGFloat = 0

    /// The amount of padding to include at the bottom of the row, expressed as a Workspace
    /// coordinate system unit.
    public var bottomPadding: CGFloat = 0

    /// The height of the middle part of the row, expressed as a Workspace coordinate system value.
    /// If this row has a value input at the end, the connector should be vertically aligned to
    /// be in the center of this height.
    public var middleHeight: CGFloat = 0

    /// For statement inputs, the relative x-position of where to begin rendering the inner left
    /// edge of the "C" shape block, expressed as a Workspace coordinate system unit.
    public var statementIndent: CGFloat = 0

    /// For statement inputs, the width of the notch of the inner ceiling of the "C" shaped block,
    /// expressed as a Workspace coordinate system unit.
    public var statementConnectorWidth: CGFloat = 0

    /// The corresponding layouts used to render this row
    public var layouts = [Layout]()

    /// Inline connector locations
    public var inlineConnectors = [InlineConnector]()

    /// The height of this row, expressed as a Workspace coordinate system value
    public var rowHeight: CGFloat {
      return topPadding + middleHeight + bottomPadding
    }

    // MARK: - Internal

    /**
    Updates all render properties using the current state of `inputLayouts` and a given minimal row
    width.

    - parameter minimalRowWidth: The minimal width that this row should be. NOTE: This value is only
    used for inline rows.
    - parameter leadingEdgeOffset: The leading edge offset relative to the block background.
     NOTE: This value is only used for rows containing statement/non-inline value inputs.
    */
    internal func updateRenderProperties(minimalRowWidth: CGFloat, leadingEdgeOffset: CGFloat) {
      if layouts.isEmpty {
        return
      }

      resetRenderProperties()

      if let lastInputLayout = layouts.last as? DefaultInputLayout {
        if lastInputLayout.input.type == .statement {
          self.isStatement = true
          self.rightEdge =
            lastInputLayout.relativePosition.x - leadingEdgeOffset + lastInputLayout.rightEdge
          self.topPadding = lastInputLayout.statementRowTopPadding
          self.middleHeight = lastInputLayout.statementMiddleHeight
          self.bottomPadding = lastInputLayout.statementRowBottomPadding
          self.statementIndent = lastInputLayout.statementIndent
          self.statementConnectorWidth = lastInputLayout.statementConnectorWidth

          return
        } else if let block = lastInputLayout.input.sourceBlock,
          !block.inputsInline
        {
          self.rightEdge =
            lastInputLayout.relativePosition.x - leadingEdgeOffset + lastInputLayout.rightEdge
          self.outputConnector = (lastInputLayout.input.connection != nil)
          self.middleHeight = layouts.map { ($0 as? InputLayout)?.firstLineHeight ?? 0 }.max()!
          self.bottomPadding = max(layouts.map { $0.totalSize.height }.max()! - middleHeight, 0)

          return
        }
      }

      // The right edge for inline dummy/value inputs is the total width of all combined
      var rightEdge: CGFloat = 0
      for layout in layouts {
        rightEdge += layout.totalSize.width

        // Add inline connector locations
        if let inputLayout = layout as? DefaultInputLayout,
          inputLayout.input.type == .value
        {
          let firstLineHeight =
            inputLayout.blockGroupLayout.blockLayouts.first?.firstLineHeight
            ?? inputLayout.inlineConnectorSize.height
          let inlineConnector = InlineConnector(
            inputLayout.relativePosition + inputLayout.inlineConnectorPosition,
            inputLayout.inlineConnectorSize,
            firstLineHeight)
          self.inlineConnectors.append(inlineConnector)
        }
      }
      self.rightEdge = max(minimalRowWidth, rightEdge)
      self.middleHeight = layouts.map { $0.totalSize.height }.max()!
    }

    // MARK: - Private

    /**
    Resets all render properties to their default values.
    */
    fileprivate func resetRenderProperties() {
      self.outputConnector = false
      self.isStatement = false
      self.rightEdge = 0
      self.topPadding = 0
      self.bottomPadding = 0
      self.middleHeight = 0
      self.statementIndent = 0
      self.statementConnectorWidth = 0
      self.inlineConnectors = []
    }
  }

  /**
  Information on where to render an inline connector.
  */
  public struct InlineConnector {
    /// The position of where to begin rendering the inline connector, relative to the containing
    /// block.
    public var relativePosition: WorkspacePoint

    /// The line height for the first line of content inside the inline connector.
    /// The connector's puzzle tab should be rendered vertically centered relative to this height.
    public var firstLineHeight: CGFloat = 0

    /// The size of the inline connector.
    public var size: WorkspaceSize

    /// Initializer
    fileprivate init(
      _ relativePosition: WorkspacePoint, _ size: WorkspaceSize, _ firstLineHeight: CGFloat) {
      self.relativePosition = relativePosition
      self.size = size
      self.firstLineHeight = firstLineHeight
    }
  }
}
