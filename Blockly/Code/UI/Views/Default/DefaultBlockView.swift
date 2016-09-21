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

@objc(BKYDefaultBlockView)
public final class DefaultBlockView: BlockView {

  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `DefaultBlockLayout`
  public var defaultBlockLayout: DefaultBlockLayout? {
    return self.layout as? DefaultBlockLayout
  }

  /// Flag determining if layer changes should be animated
  fileprivate var _disableLayerChangeAnimations: Bool = true

  /// Layer for rendering the block's background
  fileprivate let _backgroundLayer = BezierPathLayer()

  /// Layer for rendering the block's highlight overlay
  fileprivate var _highlightLayer: BezierPathLayer?

  // MARK: - Initializers

  public required init() {
    super.init()

    // Add background layer
    self.layer.addSublayer(_backgroundLayer)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hitTestView = super.hitTest(point, with: event)

    if hitTestView == self {
      // Only return this view if the hitTest touches a visible portion of the block.
      if let bezierPath = _backgroundLayer.bezierPath , bezierPath.contains(point) {
        return self
      } else {
        return nil
      }
    }

    return hitTestView
  }

  open override func refreshView(
    forFlags flags: LayoutFlag = LayoutFlag.All, animated: Bool = false)
  {
    super.refreshView(forFlags: flags, animated: animated)

    guard let layout = self.blockLayout else {
      return
    }

    runAnimatableCode(animated) {
      CATransaction.begin()
      CATransaction.setDisableActions(self._disableLayerChangeAnimations || !animated)

      if flags.intersectsWith([Layout.Flag_NeedsDisplay, Layout.Flag_UpdateViewFrame]) {
        // Update the view frame
        self.frame = layout.viewFrame
      }

      if flags.intersectsWith(BlockLayout.Flag_NeedsDisplay) {
        // Set its user interaction
        self.isUserInteractionEnabled = layout.userInteractionEnabled
      }

      if flags.intersectsWith([BlockLayout.Flag_NeedsDisplay, BlockLayout.Flag_UpdateVisible]) {
        self.isHidden = !layout.visible
      }

      if flags.intersectsWith([BlockLayout.Flag_NeedsDisplay, BlockLayout.Flag_UpdateViewFrame]) {
        self.alpha = layout.block.disabled ?
          layout.config.floatFor(DefaultLayoutConfig.BlockDisabledAlpha) :
          layout.config.floatFor(DefaultLayoutConfig.BlockDefaultAlpha)
      }

      // Special case for determining if we need to force a bezier path redraw. The reason is that
      // in RTL, when the bezier path is calculated, it does a transform at the end where it scales
      // the x-axis by -1 and then translates the path by the width of the view frame. So basically,
      // if the view frame width has changed in this case, we need to force a bezier path
      // recalculation.
      let forceBezierPathRedraw =
        flags.intersectsWith(BlockLayout.Flag_UpdateViewFrame) &&
        layout.engine.rtl &&
        self._backgroundLayer.frame.size.width != layout.viewFrame.size.width

      if flags.intersectsWith([BlockLayout.Flag_NeedsDisplay, BlockLayout.Flag_UpdateHighlight]) ||
        forceBezierPathRedraw
      {
        // Figure out the stroke and fill colors of the block
        var strokeColor = UIColor.clear
        var fillColor = UIColor.clear

        if layout.block.disabled {
          strokeColor =
            layout.config.colorFor(DefaultLayoutConfig.BlockStrokeDisabledColor) ?? strokeColor
          fillColor =
            layout.config.colorFor(DefaultLayoutConfig.BlockFillDisabledColor) ?? fillColor
        } else {
          strokeColor = (layout.highlighted ?
            layout.config.colorFor(DefaultLayoutConfig.BlockStrokeHighlightColor) :
            layout.config.colorFor(DefaultLayoutConfig.BlockStrokeDefaultColor)) ??
            UIColor.clear
          fillColor = layout.block.color

          if layout.block.shadow {
            strokeColor = self.shadowColor(forColor: strokeColor, config: layout.config)
            fillColor = self.shadowColor(forColor: fillColor, config: layout.config)
          }
        }

        // Update the background layer
        let backgroundLayer = self._backgroundLayer
        backgroundLayer.strokeColor = strokeColor.cgColor
        backgroundLayer.fillColor = fillColor.cgColor
        backgroundLayer.lineWidth = layout.highlighted ?
          layout.config.viewUnitFor(DefaultLayoutConfig.BlockLineWidthHighlight) :
          layout.config.viewUnitFor(DefaultLayoutConfig.BlockLineWidthRegular)
        backgroundLayer.animationDuration =
          layout.config.doubleFor(LayoutConfig.ViewAnimationDuration)
        backgroundLayer.setBezierPath(self.blockBackgroundBezierPath(), animated: animated)
        backgroundLayer.frame = self.bounds
      }

      if flags.intersectsWith(
        [BlockLayout.Flag_NeedsDisplay,
          BlockLayout.Flag_UpdateHighlight,
          BlockLayout.Flag_UpdateConnectionHighlight]) || forceBezierPathRedraw
      {
        // Update highlight
        if let path = self.blockHighlightBezierPath() {
          self.addHighlightLayer(withPath: path, animated: animated)
        } else {
          self.removeHighlightLayer()
        }
      }

      CATransaction.commit()

      // Re-enable layer animations for any future changes
      self._disableLayerChangeAnimations = false
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    // Disable animating layer changes, so that the next block layout that uses this view instance
    // isn't animated into view based on the previous block layout.
    _disableLayerChangeAnimations = true

    _backgroundLayer.setBezierPath(nil, animated: false)
    removeHighlightLayer()
  }

  // MARK: - Private

  fileprivate func addHighlightLayer(withPath path: UIBezierPath, animated: Bool) {
    guard let layout = self.defaultBlockLayout else {
      return
    }

    // TODO:(#170) Connection highlights need to be animated into position. Currently, they always
    // just appear in their final destination position.

    // Use existing _highlightLayer or create a new one
    let highlightLayer = _highlightLayer ?? BezierPathLayer()
    layer.addSublayer(highlightLayer)
    _highlightLayer = highlightLayer

    // Configure highlight
    highlightLayer.lineWidth =
      layout.config.viewUnitFor(DefaultLayoutConfig.BlockLineWidthHighlight)
    highlightLayer.strokeColor =
      layout.config.colorFor(DefaultLayoutConfig.BlockStrokeHighlightColor)?.cgColor ??
      UIColor.clear.cgColor
    highlightLayer.fillColor = nil
    // TODO:(#41) The highlight view frame needs to be larger than this view since it uses a
    // larger line width
    // Set the zPosition to 1 so it's higher than most other layers (all layers default to 0)
    highlightLayer.zPosition = 1
    highlightLayer.animationDuration = layout.config.doubleFor(LayoutConfig.ViewAnimationDuration)
    highlightLayer.setBezierPath(path, animated: animated)
    highlightLayer.frame = bounds
  }

  fileprivate func removeHighlightLayer() {
    if let highlightLayer = _highlightLayer {
      highlightLayer.removeFromSuperlayer()
      _highlightLayer = nil
    }
  }

  fileprivate func blockBackgroundBezierPath() -> UIBezierPath? {
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
        addNotch(
          toPath: path, drawLeftToRight: true, notchWidth: notchWidth, notchHeight: notchHeight)
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
        addNotch(
          toPath: path, drawLeftToRight: false, notchWidth: notchWidth, notchHeight: notchHeight)

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
        addPuzzleTab(toPath: path, drawTopToBottom: true,
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
      addNotch(toPath: path, drawLeftToRight: false, notchWidth: notchWidth, notchHeight: notchHeight)
    }

    path.addLineToPoint(xLeftEdgeOffset, path.currentWorkspacePoint.y, relative: false)

    // DRAW THE LEFT EDGES

    if background.maleOutputConnector {
      // Add male connector
      path.addLineToPoint(0, puzzleTabHeight - path.currentWorkspacePoint.y, relative: true)

      addPuzzleTab(toPath: path, drawTopToBottom: false,
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
        addPuzzleTab(toPath: path, drawTopToBottom: false,
          puzzleTabWidth: puzzleTabWidth, puzzleTabHeight: puzzleTabHeight)
      }
    }

    let viewBezierPath = path.viewBezierPath
    if layout.engine.rtl {
      applyRtlTransform(toBezierPath: viewBezierPath, layout: layout)
    }

    return viewBezierPath
  }

  fileprivate func blockHighlightBezierPath() -> UIBezierPath? {
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
      case .inputValue, .outputValue:
        // The connection point is set to the apex of the puzzle tab's curve. Move the point before
        // drawing it.
        path.moveToPoint(connectionRelativePosition +
          WorkspacePointMake(puzzleTabWidth, -puzzleTabHeight / 2),
          relative: false)
        addPuzzleTab(toPath: path, drawTopToBottom: true,
          puzzleTabWidth: puzzleTabWidth, puzzleTabHeight: puzzleTabHeight)
        break
      case .previousStatement, .nextStatement:
        // The connection point is set to the bottom of the notch. Move the point before drawing it.
        path.moveToPoint(connectionRelativePosition -
          WorkspacePointMake(notchWidth / 2, notchHeight),
          relative: false)
        addNotch(
          toPath: path, drawLeftToRight: true, notchWidth: notchWidth, notchHeight: notchHeight)
        break
      }
    }

    let viewBezierPath = path.viewBezierPath
    if layout.engine.rtl {
      applyRtlTransform(toBezierPath: viewBezierPath, layout: layout)
    }

    return viewBezierPath
  }

  fileprivate func applyRtlTransform(toBezierPath path: UIBezierPath, layout: BlockLayout) {
    var transform = CGAffineTransform.identity
    transform = transform.scaledBy(x: CGFloat(-1.0), y: CGFloat(1.0))
    transform = transform.translatedBy(x: -layout.viewFrame.size.width, y: CGFloat(0))
    path.apply(transform)
  }

  fileprivate func shadowColor(forColor color: UIColor, config: LayoutConfig) -> UIColor {
    var hsba = color.bky_hsba()
    hsba.saturation *= config.floatFor(DefaultLayoutConfig.BlockShadowSaturationMultiplier)
    hsba.brightness =
      max(hsba.brightness * config.floatFor(DefaultLayoutConfig.BlockShadowBrightnessMultiplier), 1)
    return UIColor(
      hue: hsba.hue, saturation: hsba.saturation, brightness: hsba.brightness, alpha: hsba.alpha)
  }
}
