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

extension BlockLayout {
  /**
  Information for rendering a block.
  */
  @objc(BKYBlockLayoutBackground)
  public final class Background: NSObject {
    // MARK: - Properties

    /// Flag if the top-left corner should be square.
    public private(set) var squareTopLeftCorner: Bool = false

    /// Flag if the bottom-left corner should be rounded
    public private(set) var squareBottomLeftCorner: Bool = false

    /// Flag if a female previous statement connector should be rendered at the top of the block
    public private(set) var femalePreviousStatementConnector: Bool = false

    /// Flag if a male next statement connector should be rendered at the bottom of the block
    public private(set) var maleNextStatementConnector: Bool = false

    /// Flag if a male output connector should be rendered on the left side of the block
    public private(set) var maleOutputConnector: Bool = false

    /// The rows for this block
    public private(set) var rows = [BackgroundRow]()

    // MARK: - Public

    /**
    Updates all render properties from a given block layout.
    
    - Parameter layout: The block layout.
    */
    public func updateRenderPropertiesFromBlockLayout(layout: BlockLayout) {
      self.maleOutputConnector = (layout.block.outputConnection != nil)
      self.femalePreviousStatementConnector = (layout.block.previousConnection != nil)
      self.maleNextStatementConnector = (layout.block.nextConnection != nil)

      if layout.block.outputConnection != nil {
        self.squareTopLeftCorner = true
        self.squareBottomLeftCorner = true
      } else {
        self.squareTopLeftCorner = false
        self.squareBottomLeftCorner = false
        // If this block is in the middle of a stack, square the corners.
        let previousBlock = layout.block.previousConnection?.targetConnection?.sourceBlock
        if previousBlock?.nextBlock == self {
          self.squareTopLeftCorner = true;
        }
        if layout.block.nextBlock != nil {
          self.squareBottomLeftCorner = true;
        }
      }
    }

    /**
    Append a new row to `rows`.
    
    - Parameter row: The row to append.
    */
    public func appendRow(row: BackgroundRow) {
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
  public final class BackgroundRow: NSObject {
    // MARK: - Properties

    /// Flag if a female output connector should be rendered on the right side of the row
    public var femaleOutputConnector: Bool = false

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
    public var middleHeight: CGFloat = 0

    /// For statement inputs, the relative x-position of where to begin rendering the inner left
    /// edge of the "C" shape block, expressed as a Workspace coordinate system unit.
    public var statementIndent: CGFloat = 0

    /// For statement inputs, the width of the notch of the inner ceiling of the "C" shaped block,
    /// expressed as a Workspace coordinate system unit.
    public var statementConnectorWidth: CGFloat = 0

    /// The corresponding input layouts used to render this row
    public var inputLayouts = [InputLayout]()

    /// Inline connector locations
    public var inlineConnectors = [InlineConnector]()

    /// The height of this row, expressed as a Workspace coordinate system value
    public var rowHeight: CGFloat {
      return topPadding + middleHeight + bottomPadding
    }

    // MARK: - Public

    /**
    Updates all render properties using the current state of `inputLayouts` and a given minimal row
    width.

    - Parameter minimalRowWidth: The minimal width that this row should be. NOTE: This value is only
    used for inline rows.
    */
    public func updateRenderPropertiesWithMinimalRowWidth(minimalRowWidth: CGFloat) {
      if inputLayouts.isEmpty {
        return
      }

      resetRenderProperties()

      let lastInputLayout = inputLayouts.last!

      if lastInputLayout.input.type == .Statement {
        self.isStatement = true
        self.rightEdge = lastInputLayout.rightEdge
        self.topPadding = lastInputLayout.statementRowTopPadding
        self.middleHeight = lastInputLayout.statementMiddleHeight
        self.bottomPadding = lastInputLayout.statementRowBottomPadding
        self.statementIndent = lastInputLayout.statementIndent
        self.statementConnectorWidth = lastInputLayout.statementConnectorWidth
      } else if !lastInputLayout.input.sourceBlock.inputsInline {
        self.rightEdge = lastInputLayout.rightEdge
        self.femaleOutputConnector = (lastInputLayout.input.connection != nil)
        self.middleHeight = lastInputLayout.totalSize.height
      } else {
        // The right edge for inline dummy/value inputs is the total width of all combined
        var rightEdge: CGFloat = 0
        for inputLayout in inputLayouts {
          rightEdge += inputLayout.totalSize.width

          // Add inline connector locations
          if inputLayout.input.type == .Value {
            let inlineConnector = InlineConnector(
              inputLayout.relativePosition + inputLayout.inlineConnectorPosition,
              inputLayout.inlineConnectorSize)
            self.inlineConnectors.append(inlineConnector)
          }
        }
        self.rightEdge = max(minimalRowWidth, rightEdge, lastInputLayout.rightEdge)
        self.middleHeight = inputLayouts.map { $0.totalSize.height }.maxElement()!
      }
    }

    // MARK: - Private

    /**
    Resets all render properties to their default values.
    */
    private func resetRenderProperties() {
      self.femaleOutputConnector = false
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

    /// The size of the inline connector.
    public var size: WorkspaceSize

    /// Initializer
    private init(_ relativePosition: WorkspacePoint, _ size: WorkspaceSize) {
      self.relativePosition = relativePosition
      self.size = size
    }
  }
}
