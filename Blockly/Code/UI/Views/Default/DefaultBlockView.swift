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

public class DefaultBlockView: BlockView {

  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `DefaultBlockLayout`
  public var defaultBlockLayout: DefaultBlockLayout? {
    return self.layout as? DefaultBlockLayout
  }

  /// Layer for rendering the block's background
  private let _backgroundLayer = BezierPathLayer()

  /// Layer for rendering the block's highlight overlay
  private var _highlightLayer: BezierPathLayer?

  // MARK: - Initializers

  public required init() {
    super.init()

    // Add background layer
    self.layer.addSublayer(_backgroundLayer)
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
    // Override this method so that this only returns true if the point is inside the
    // block background bezier path
    if let bezierPath = _backgroundLayer.bezierPath {
      return bezierPath.containsPoint(point)
    } else {
      return false
    }
  }

  public override func refreshBackgroundUI(forFlags flags: LayoutFlag) {
    guard let layout = self.defaultBlockLayout else {
      return
    }

    if flags.intersectsWith(
      [BlockLayout.Flag_NeedsDisplay,
        BlockLayout.Flag_UpdateHighlight,
        BlockLayout.Flag_UpdateDragging])
    {
      // Update background
      let strokeColor = (layout.highlighted ?
        layout.config.colorFor(DefaultLayoutConfig.BlockStrokeHighlightColor) :
        layout.config.colorFor(DefaultLayoutConfig.BlockStrokeDefaultColor)) ??
        UIColor.clearColor()
      _backgroundLayer.strokeColor = layout.dragging ?
        strokeColor.colorWithAlphaComponent(0.8).CGColor : strokeColor.CGColor
      _backgroundLayer.lineWidth = layout.highlighted ?
        layout.config.viewUnitFor(DefaultLayoutConfig.BlockLineWidthHighlight) :
        layout.config.viewUnitFor(DefaultLayoutConfig.BlockLineWidthRegular)
      let fillColor = layout.block.color
      _backgroundLayer.fillColor = layout.dragging ?
        fillColor.colorWithAlphaComponent(0.7).CGColor : fillColor.CGColor
      _backgroundLayer.bezierPath = blockBackgroundBezierPath()
      _backgroundLayer.frame = self.bounds
    }

    if flags.intersectsWith(
      [BlockLayout.Flag_NeedsDisplay,
        BlockLayout.Flag_UpdateHighlight,
        BlockLayout.Flag_UpdateConnectionHighlight])
    {
      // Update highlight
      if let path = blockHighlightBezierPath() {
        addHighlightLayerWithPath(path)
      } else {
        removeHighlightLayer()
      }
    }
  }

  public override func internalPrepareForReuse() {
    super.internalPrepareForReuse()

    removeHighlightLayer()
  }

  // MARK: - Private

  private func addHighlightLayerWithPath(path: UIBezierPath) {
    guard let layout = self.defaultBlockLayout else {
      return
    }

    if _highlightLayer == nil {
      let highlightLayer = BezierPathLayer()
      highlightLayer.lineWidth = layout.config.viewUnitFor(DefaultLayoutConfig.BlockLineWidthHighlight)
      highlightLayer.strokeColor =
        layout.config.colorFor(DefaultLayoutConfig.BlockStrokeHighlightColor)?.CGColor ??
        UIColor.clearColor().CGColor
      highlightLayer.fillColor = nil
      // TODO:(#41) The highlight view frame needs to be larger than this view since it uses a
      // larger line width
      highlightLayer.frame = self.bounds
      // Set the zPosition to 1 so it's higher than most other layers (all layers default to 0)
      highlightLayer.zPosition = 1
      layer.addSublayer(highlightLayer)
      _highlightLayer = highlightLayer
    }
    _highlightLayer!.bezierPath = path
  }

  private func removeHighlightLayer() {
    if let highlightLayer = _highlightLayer {
      highlightLayer.removeFromSuperlayer()
      _highlightLayer = nil
    }
  }

  private func blockBackgroundBezierPath() -> UIBezierPath? {
    guard let layout = self.defaultBlockLayout else {
      return nil
    }

    let path = WorkspaceBezierPath(engine: layout.engine)
    let background = layout.background
    var previousBottomPadding: CGFloat = 0
    let xLeftEdgeOffset = background.leadingEdgeXOffset // Note: this is the right edge in RTL
    let notchWidth = layout.config.workspaceUnitFor(DefaultLayoutConfig.NotchWidth)
    let notchHeight = layout.config.workspaceUnitFor(DefaultLayoutConfig.NotchHeight)
    let puzzleTabWidth = layout.config.workspaceUnitFor(DefaultLayoutConfig.PuzzleTabWidth)
    let puzzleTabHeight = layout.config.workspaceUnitFor(DefaultLayoutConfig.PuzzleTabHeight)

    path.moveToPoint(xLeftEdgeOffset, 0, relative: false)

    for i in 0 ..< background.rows.count {
      let row = background.rows[i]

      // DRAW THE TOP EDGES

      if i == 0 && background.femalePreviousStatementConnector {
        // Draw previous statement connector
        addNotchToPath(
          path, drawLeftToRight: true, notchWidth: notchWidth, notchHeight: notchHeight)
      }

      path.addLineToPoint(
        xLeftEdgeOffset + row.rightEdge, path.currentWorkspacePoint.y, relative: false)

      // Draw top padding
      let topPadding = row.topPadding + previousBottomPadding
      if topPadding > 0 {
        path.addLineToPoint(0, topPadding, relative: true)
      }

      // DRAW THE RIGHT EDGES

      if row.isStatement {
        // Draw the "C" part of a statement block

        // Inner-ceiling of "C"
        path.addLineToPoint(
          xLeftEdgeOffset + row.statementIndent + notchWidth,
          path.currentWorkspacePoint.y, relative: false)

        // Draw notch
        addNotchToPath(
          path, drawLeftToRight: false, notchWidth: notchWidth, notchHeight: notchHeight)

        path.addLineToPoint(
          xLeftEdgeOffset + row.statementIndent, path.currentWorkspacePoint.y, relative: false)

        // Inner-left side of "C"
        path.addLineToPoint(0, row.middleHeight, relative: true)

        if i == (background.rows.count - 1) {
          // If there is no other row after this, draw the inner-floor of the "C".
          path.addLineToPoint(
            xLeftEdgeOffset + row.rightEdge, path.currentWorkspacePoint.y,
            relative: false)
        } else {
          // If there is another row after this, the inner-floor of the "C" is drawn by the
          // right edge of the next row.
        }
      } else if row.femaleOutputConnector {
        // Draw female output connector and then the rest of the middle height
        let startingY = path.currentWorkspacePoint.y
        addPuzzleTabToPath(path, drawTopToBottom: true,
          puzzleTabWidth: puzzleTabWidth, puzzleTabHeight: puzzleTabHeight)
        let restOfVerticalEdge = startingY + row.middleHeight - path.currentWorkspacePoint.y
        bky_assert(restOfVerticalEdge >= 0,
          message: "Middle height for the block layout is less than the space needed")
        path.addLineToPoint(0, restOfVerticalEdge, relative: true)
      } else {
        // Simply draw the middle height for the vertical edge
        path.addLineToPoint(0, row.middleHeight, relative: true)
      }

      // Store bottom padding (to draw into the the top padding of the next row)
      previousBottomPadding = row.bottomPadding
    }

    if previousBottomPadding > 0 {
      path.addLineToPoint(0, previousBottomPadding, relative: true)
    }

    // DRAW THE BOTTOM EDGES

    if background.maleNextStatementConnector {
      path.addLineToPoint(
        xLeftEdgeOffset + notchWidth, path.currentWorkspacePoint.y, relative: false)
      addNotchToPath(path, drawLeftToRight: false, notchWidth: notchWidth, notchHeight: notchHeight)
    }

    path.addLineToPoint(xLeftEdgeOffset, path.currentWorkspacePoint.y, relative: false)

    // DRAW THE LEFT EDGES

    if background.maleOutputConnector {
      // Add male connector
      path.addLineToPoint(0, puzzleTabHeight - path.currentWorkspacePoint.y, relative: true)

      addPuzzleTabToPath(path, drawTopToBottom: false,
        puzzleTabWidth: puzzleTabWidth, puzzleTabHeight: puzzleTabHeight)
    }

    path.closePath()

    // DRAW INLINE CONNECTORS
    path.viewBezierPath.usesEvenOddFillRule = true
    for backgroundRow in background.rows {
      for inlineConnector in backgroundRow.inlineConnectors {
        path.moveToPoint(
          inlineConnector.relativePosition.x + puzzleTabWidth,
          inlineConnector.relativePosition.y,
          relative: false)

        let xEdgeWidth = inlineConnector.size.width - puzzleTabWidth
        // Top edge
        path.addLineToPoint(xEdgeWidth, 0, relative: true)
        // Right edge
        path.addLineToPoint(0, inlineConnector.size.height, relative: true)
        // Bottom edge
        path.addLineToPoint(-xEdgeWidth, 0, relative: true)
        // Left edge
        path.addLineToPoint(0, -(inlineConnector.size.height - puzzleTabHeight), relative: true)
        // Puzzle notch
        addPuzzleTabToPath(path, drawTopToBottom: false,
          puzzleTabWidth: puzzleTabWidth, puzzleTabHeight: puzzleTabHeight)
      }
    }

    let viewBezierPath = path.viewBezierPath
    if layout.engine.rtl {
      applyRtlTransformToBezierPath(viewBezierPath, layout: layout)
    }

    return viewBezierPath
  }

  private func blockHighlightBezierPath() -> UIBezierPath? {
    guard let layout = self.defaultBlockLayout else {
      return nil
    }

    let hasConnectionHighlight = layout.block.directConnections.filter { $0.highlighted }.count > 0
    if !hasConnectionHighlight {
      return nil
    }

    let notchWidth = layout.config.workspaceUnitFor(DefaultLayoutConfig.NotchWidth)
    let notchHeight = layout.config.workspaceUnitFor(DefaultLayoutConfig.NotchHeight)
    let puzzleTabWidth = layout.config.workspaceUnitFor(DefaultLayoutConfig.PuzzleTabWidth)
    let puzzleTabHeight = layout.config.workspaceUnitFor(DefaultLayoutConfig.PuzzleTabHeight)

    // Build path for each highlighted connection
    let path = WorkspaceBezierPath(engine: layout.engine)

    for connection in layout.block.directConnections {
      if !connection.highlighted {
        continue
      }

      let connectionRelativePosition = connection.position - layout.absolutePosition

      // Highlight specific connection
      switch connection.type {
      case .InputValue, .OutputValue:
        // The connection point is set to the apex of the puzzle tab's curve. Move the point before
        // drawing it.
        path.moveToPoint(connectionRelativePosition +
          WorkspacePointMake(puzzleTabWidth, -puzzleTabHeight / 2),
          relative: false)
        addPuzzleTabToPath(path, drawTopToBottom: true,
          puzzleTabWidth: puzzleTabWidth, puzzleTabHeight: puzzleTabHeight)
        break
      case .PreviousStatement, .NextStatement:
        // The connection point is set to the bottom of the notch. Move the point before drawing it.
        path.moveToPoint(connectionRelativePosition -
          WorkspacePointMake(notchWidth / 2, notchHeight),
          relative: false)
        addNotchToPath(
          path, drawLeftToRight: true, notchWidth: notchWidth, notchHeight: notchHeight)
        break
      }
    }

    let viewBezierPath = path.viewBezierPath
    if layout.engine.rtl {
      applyRtlTransformToBezierPath(viewBezierPath, layout: layout)
    }

    return viewBezierPath
  }

  private func applyRtlTransformToBezierPath(path: UIBezierPath, layout: BlockLayout) {
    var transform = CGAffineTransformIdentity
    transform = CGAffineTransformScale(transform, CGFloat(-1.0), CGFloat(1.0))
    transform = CGAffineTransformTranslate(transform, -layout.viewFrame.size.width, CGFloat(0))
    path.applyTransform(transform)
  }

}