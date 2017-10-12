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
 A default implementation of `BlockView`.
 */
@objc(BKYDefaultBlockView)
@objcMembers public final class DefaultBlockView: BlockView {

  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `DefaultBlockLayout`
  public var defaultBlockLayout: DefaultBlockLayout? {
    return self.layout as? DefaultBlockLayout
  }

  /// Flag determining if layer changes should be animated
  fileprivate var _disableLayerChangeAnimations: Bool = true

  /// Layer for rendering the block's background
  fileprivate let _backgroundLayer: BezierPathLayer = {
    var layer = BezierPathLayer()
    layer.lineCap = kCALineCapRound
    // Set z-position so it renders below most other layers (all layers default to 0).
    layer.zPosition = -1
    return layer
  }()

  /// Layer for rendering the block's connection highlight overlay.
  fileprivate let _connectionHighlightLayer: BezierPathLayer = {
    var layer = BezierPathLayer()
    layer.lineCap = kCALineCapRound
    layer.fillColor = nil
    // Set z-position so it renders above most other layers (all layers default to 0).
    layer.zPosition = 1
    return layer
  }()

  /// Layer for rendering the block's highlight overlay
  fileprivate let _blockHighlightLayer: BezierPathLayer = {
    var layer = BezierPathLayer()
    layer.lineCap = kCALineCapRound
    layer.fillColor = nil
    // Set z-position so it renders above most other layers (all layers default to 0).
    layer.zPosition = 2
    return layer
  }()

  /// Number of animations that are currently running `refreshView(forFlags:animated:)`.
  private var runningRefreshViewCodeCounter = 0

  // MARK: - Initializers

  /// Initializes the default block view.
  public required init() {
    super.init()

    // Add background/highlight layers
    layer.addSublayer(_backgroundLayer)
    layer.addSublayer(_connectionHighlightLayer)
    layer.addSublayer(_blockHighlightLayer)
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  /**
   Returns the farthest descendant of the receiver in the view hierarchy that contains a specified
   `point`. Unlike the default implementation, default block view will only return itself if the
   `point` lies within the bezier curve of the block.

   - parameter point: A point specified in the receiver’s local coordinate system (bounds).
   - parameter event: The event that warranted a call to this method. If you are calling this method
     from outside your event-handling code, you may specify nil.
   - returns: The view object that is the farthest descendent the current view and contains `point`.
  */
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

    runAnimatableCode(animated, code: {
      // Increment the number of blocks that are running this animation part of the code.
      self.runningRefreshViewCodeCounter += 1

      // Note: This code isn't wrapped inside an explicit CATransaction since that will render the
      // changes immediately. The problem with this is that all other views use the implicit
      // CATransaction that is created for every run loop. If we use a different CATransaction,
      // views may render in a non-synchronous way.

      // Potentially disable animations from running. Store the previous value so it can be restored
      // later.
      let disabledActions = CATransaction.disableActions()
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
          layout.config.float(for: DefaultLayoutConfig.BlockDisabledAlpha) :
          layout.config.float(for: DefaultLayoutConfig.BlockDefaultAlpha)
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
        var strokeColor: UIColor?
        var fillColor: UIColor?
        if layout.block.disabled {
          strokeColor = layout.config.color(for: DefaultLayoutConfig.BlockStrokeDisabledColor)
          fillColor = layout.config.color(for: DefaultLayoutConfig.BlockFillDisabledColor)
        } else {
          let defaultStrokeColor =
            layout.config.color(for: DefaultLayoutConfig.BlockStrokeDefaultColor) ?? .clear
          strokeColor = defaultStrokeColor
          fillColor = layout.block.color

          if layout.block.shadow {
            strokeColor = self.shadowColor(forColor: defaultStrokeColor, config: layout.config)
            fillColor = self.shadowColor(forColor: layout.block.color, config: layout.config)
          }
        }

        // Construct the block's bezier path
        let blockBezierPath = self.blockBackgroundBezierPath()

        // Update the background layer
        let backgroundLayer = self._backgroundLayer
        backgroundLayer.strokeColor = strokeColor?.cgColor
        backgroundLayer.fillColor = fillColor?.cgColor
        backgroundLayer.lineWidth =
          layout.config.viewUnit(for: DefaultLayoutConfig.BlockLineWidthRegular)
        backgroundLayer.animationDuration =
          layout.config.double(for: LayoutConfig.ViewAnimationDuration)
        backgroundLayer.setBezierPath(blockBezierPath, animated: animated)
        backgroundLayer.frame = self.bounds

        // Update the block highlight layer
        if layout.highlighted {
          let blockHighlightLayer = self._blockHighlightLayer
          blockHighlightLayer.strokeColor =
            layout.config.color(for: DefaultLayoutConfig.BlockStrokeHighlightColor)?.cgColor
          blockHighlightLayer.fillColor =
            layout.config.color(for: DefaultLayoutConfig.BlockMaskHighlightColor)?.cgColor
          blockHighlightLayer.lineWidth =
            layout.config.viewUnit(for: DefaultLayoutConfig.BlockLineWidthHighlight)
          blockHighlightLayer.animationDuration =
            layout.config.double(for: LayoutConfig.ViewAnimationDuration)
          blockHighlightLayer.setBezierPath(blockBezierPath, animated: animated)
          blockHighlightLayer.frame = self.bounds

          // If this block is highlighted, bring it to the top so its highlight layer doesn't get
          // covered by other sibling blocks.
          self.superview?.bringSubview(toFront: self)
        } else {
          self._blockHighlightLayer.setBezierPath(nil, animated: false)
        }
      }

      if flags.intersectsWith([
          BlockLayout.Flag_NeedsDisplay,
          BlockLayout.Flag_UpdateHighlight,
          BlockLayout.Flag_UpdateConnectionHighlight]) || forceBezierPathRedraw
      {
        // Remove connection highlights (they will be potentially re-added in the completion block).
        self._connectionHighlightLayer.setBezierPath(nil, animated: false)
      }

      // Restore disabled actions to previous value
      CATransaction.setDisableActions(disabledActions)

      // Re-enable layer animations for any future changes
      self._disableLayerChangeAnimations = false
    }, completion: { _ in
      // Decrement the number of blocks that are running the animatable part of the code.
      self.runningRefreshViewCodeCounter -= 1

      // Once all animatable code blocks have finished running, re-add connection highlights,
      // if necessary.
      if self.runningRefreshViewCodeCounter == 0,
        let path = self.blockHighlightBezierPath() {
        // Configure highlight layer
        let connectionHighlightLayer = self._connectionHighlightLayer
        connectionHighlightLayer.lineWidth =
          layout.config.viewUnit(for: DefaultLayoutConfig.BlockConnectionLineWidthHighlight)
        connectionHighlightLayer.strokeColor =
          layout.config.color(for: DefaultLayoutConfig.BlockConnectionHighlightStrokeColor)?.cgColor
        connectionHighlightLayer.setBezierPath(path, animated: false)
        connectionHighlightLayer.frame = self.bounds

        // Bring this block to the top so its connection highlight doesn't get covered by
        // sibling blocks.
        self.superview?.bringSubview(toFront: self)
      }
    })
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    // Disable animating layer changes, so that the next block layout that uses this view instance
    // isn't animated into view based on the previous block layout.
    _disableLayerChangeAnimations = true

    _backgroundLayer.setBezierPath(nil, animated: false)
    _connectionHighlightLayer.setBezierPath(nil, animated: false)
    _blockHighlightLayer.setBezierPath(nil, animated: false)
  }

  // MARK: - Private

  fileprivate func blockBackgroundBezierPath() -> UIBezierPath? {
    guard let layout = self.defaultBlockLayout else {
      return nil
    }

    let path = WorkspaceBezierPath(engine: layout.engine)
    let background = layout.background
    var previousBottomPadding: CGFloat = 0
    let xLeftEdgeOffset = background.leadingEdgeXOffset // Note: this is the right edge in RTL
    let topEdgeOffset = background.leadingEdgeYOffset
    let notchXOffset = layout.config.workspaceUnit(for: DefaultLayoutConfig.NotchXOffset)
    let notchWidth = layout.config.workspaceUnit(for: DefaultLayoutConfig.NotchWidth)
    let notchHeight = layout.config.workspaceUnit(for: DefaultLayoutConfig.NotchHeight)
    let puzzleTabWidth = layout.config.workspaceUnit(for: DefaultLayoutConfig.PuzzleTabWidth)
    let puzzleTabHeight = layout.config.workspaceUnit(for: DefaultLayoutConfig.PuzzleTabHeight)
    let capHatSize = layout.config.workspaceSize(for: DefaultLayoutConfig.BlockHatCapSize)
    let cornerRadius = layout.config.workspaceUnit(for: DefaultLayoutConfig.BlockCornerRadius)
    let topLeftCornerRadius = (background.hat == Block.Style.hatCap) ? 0 : cornerRadius

    path.moveTo(x: xLeftEdgeOffset + topLeftCornerRadius, y: topEdgeOffset, relative: false)

    for i in 0 ..< background.rows.count {
      let row = background.rows[i]

      // DRAW THE TOP EDGES

      if i == 0 {
        if background.previousStatementConnector {
          // Draw previous statement connector
          path.addLineTo(x: xLeftEdgeOffset + notchXOffset, y: topEdgeOffset, relative: false)
          PathHelper.addNotch(
            toPath: path, drawLeftToRight: true, notchWidth: notchWidth, notchHeight: notchHeight)
        } else if background.hat == Block.Style.hatCap {
          // Draw a cap on top of the block
          PathHelper.addHatCap(toPath: path, hatSize: capHatSize)
        }
      }

      let rowYOffset = path.currentWorkspacePoint.y
      let nextRightEdge = xLeftEdgeOffset + row.rightEdge - cornerRadius
      if nextRightEdge > path.currentWorkspacePoint.x {
        path.addLineTo(x: nextRightEdge, y: path.currentWorkspacePoint.y, relative: false)

        // Add top-right corner
        PathHelper.addCorner(.topRight, toPath: path, radius: cornerRadius, clockwise: true)
      }

      // DRAW THE RIGHT EDGES

      if row.isStatement {
        // Draw the "C" part of a statement block

        // Draw top padding (which includes the bottom padding from the previous row)
        let topPadding = row.topPadding + previousBottomPadding - cornerRadius
        path.addLineTo(x: path.currentWorkspacePoint.x, y: rowYOffset + topPadding, relative: false)
        previousBottomPadding = 0

        // Bottom-right corner
        PathHelper.addCorner(.bottomRight, toPath: path, radius: cornerRadius, clockwise: true)

        // Inner-ceiling of "C"
        path.addLineTo(
          x: xLeftEdgeOffset + row.statementIndent + notchXOffset + notchWidth,
          y: path.currentWorkspacePoint.y,
          relative: false)

        // Draw notch
        PathHelper.addNotch(
          toPath: path, drawLeftToRight: false, notchWidth: notchWidth, notchHeight: notchHeight)

        path.addLineTo(
          x: xLeftEdgeOffset + row.statementIndent + cornerRadius,
          y: path.currentWorkspacePoint.y,
          relative: false)

        // Add top-left corner
        PathHelper.addCorner(.topLeft, toPath: path, radius: cornerRadius, clockwise: false)

        // Inner-left side of "C"
        path.addLineTo(x: 0, y: row.middleHeight - cornerRadius * 2, relative: true)

        // Add bottom-left corner
        PathHelper.addCorner(.bottomLeft, toPath: path, radius: cornerRadius, clockwise: false)

        if i == (background.rows.count - 1) {
          // If there is no other row after this, draw the inner-floor of the "C".
          path.addLineTo(
            x: xLeftEdgeOffset + row.rightEdge - cornerRadius, y: path.currentWorkspacePoint.y,
            relative: false)

          // Add top-left corner of the bottom part.
          PathHelper.addCorner(.topRight, toPath: path, radius: cornerRadius, clockwise: true)

          // Store bottom padding that will get drawn at the end, but subtract the corner radius
          // amount that was just drawn for the top-left corner.
          previousBottomPadding = row.bottomPadding - cornerRadius
        } else {
          // The inner-floor of the "C" is drawn by the right edge of the next row.
          // Store bottom padding, to draw into the the top padding of the next row.
          previousBottomPadding = row.bottomPadding
        }
      } else {
        let rightLine = row.middleHeight - (row.outputConnector ? puzzleTabHeight : 0)

        // Draw top portion of the line (which includes the bottom padding from the previous row)
        path.addLineTo(
          x: path.currentWorkspacePoint.x,
          y: rowYOffset + row.topPadding + previousBottomPadding + rightLine / 2.0,
          relative: false)

        if row.outputConnector {
          // Draw the puzzle tab
          PathHelper.addPuzzleTab(toPath: path, drawTopToBottom: true,
                                  puzzleTabWidth: puzzleTabWidth, puzzleTabHeight: puzzleTabHeight)
        }

        // Store bottom padding, to draw into the the top padding of the next row.
        previousBottomPadding = rightLine / 2.0 + row.bottomPadding
      }
    }

    // If needed, draw the last remaining bottom line.
    if previousBottomPadding - cornerRadius > 0 {
      path.addLineTo(x: 0, y: previousBottomPadding - cornerRadius, relative: true)
    }

    // Add the bottom-right corner of the block
    PathHelper.addCorner(.bottomRight, toPath: path, radius: cornerRadius, clockwise: true)

    // DRAW THE BOTTOM EDGES

    if background.nextStatementConnector {
      path.addLineTo(
        x: xLeftEdgeOffset + notchXOffset + notchWidth,
        y: path.currentWorkspacePoint.y,
        relative: false)
      PathHelper.addNotch(
        toPath: path, drawLeftToRight: false, notchWidth: notchWidth, notchHeight: notchHeight)
    }

    path.addLineTo(
      x: xLeftEdgeOffset + cornerRadius, y: path.currentWorkspacePoint.y, relative: false)

    // ADD BOTTOM LEFT CORNER
    PathHelper.addCorner(.bottomLeft, toPath: path, radius: cornerRadius, clockwise: true)

    // DRAW THE LEFT EDGES

    if background.outputConnector {
      let leftLineExtension = (background.firstLineHeight - puzzleTabHeight) / 2.0

      // Add output connector
      path.addLineTo(
        x: xLeftEdgeOffset, y: topEdgeOffset + leftLineExtension + puzzleTabHeight, relative: false)

      PathHelper.addPuzzleTab(toPath: path, drawTopToBottom: false,
        puzzleTabWidth: puzzleTabWidth, puzzleTabHeight: puzzleTabHeight)

      path.addLineTo(x: 0, y: -(leftLineExtension - topLeftCornerRadius), relative: true)
    } else {
      path.addLineTo(x: xLeftEdgeOffset, y: topEdgeOffset + topLeftCornerRadius, relative: false)
    }

    // ADD TOP LEFT CORNER
    PathHelper.addCorner(.topLeft, toPath: path, radius: topLeftCornerRadius, clockwise: true)

    path.closePath()

    // DRAW INLINE CONNECTORS
    let cornerRadiusX2 = cornerRadius * 2.0
    path.viewBezierPath.usesEvenOddFillRule = true
    for backgroundRow in background.rows {
      for inlineConnector in backgroundRow.inlineConnectors {
        path.moveTo(
          x: inlineConnector.relativePosition.x + puzzleTabWidth + cornerRadius,
          y: inlineConnector.relativePosition.y,
          relative: false)

        let xEdgeWidth = inlineConnector.size.width - puzzleTabWidth
        // Top edge
        path.addLineTo(x: xEdgeWidth - cornerRadiusX2, y: 0, relative: true)
        PathHelper.addCorner(.topRight, toPath: path, radius: cornerRadius, clockwise: true)
        // Right edge
        path.addLineTo(x: 0, y: inlineConnector.size.height - cornerRadiusX2, relative: true)
        PathHelper.addCorner(.bottomRight, toPath: path, radius: cornerRadius, clockwise: true)
        // Bottom edge
        path.addLineTo(x: -(xEdgeWidth - cornerRadiusX2), y: 0, relative: true)
        PathHelper.addCorner(.bottomLeft, toPath: path, radius: cornerRadius, clockwise: true)
        // Start left edge
        path.addLineTo(
          x: path.currentWorkspacePoint.x,
          y: inlineConnector.relativePosition.y + inlineConnector.firstLineHeight - cornerRadius,
          relative: false)

        let puzzleLineExtension = (inlineConnector.firstLineHeight - puzzleTabHeight) / 2.0
        path.addLineTo(
          x: path.currentWorkspacePoint.x,
          y: inlineConnector.relativePosition.y + puzzleLineExtension + puzzleTabHeight,
          relative: false)
        // Puzzle notch
        PathHelper.addPuzzleTab(toPath: path, drawTopToBottom: false,
          puzzleTabWidth: puzzleTabWidth, puzzleTabHeight: puzzleTabHeight)
        // Finish left edge
        path.addLineTo(x: 0, y: -(puzzleLineExtension - cornerRadius), relative: true)
        PathHelper.addCorner(.topLeft, toPath: path, radius: cornerRadius, clockwise: true)
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

    if !layout.hasHighlightedConnections() {
      return nil
    }

    let notchWidth = layout.config.workspaceUnit(for: DefaultLayoutConfig.NotchWidth)
    let notchHeight = layout.config.workspaceUnit(for: DefaultLayoutConfig.NotchHeight)
    let puzzleTabWidth = layout.config.workspaceUnit(for: DefaultLayoutConfig.PuzzleTabWidth)
    let puzzleTabHeight = layout.config.workspaceUnit(for: DefaultLayoutConfig.PuzzleTabHeight)
    let cornerRadius = layout.config.workspaceUnit(for: DefaultLayoutConfig.BlockCornerRadius)
    let xLeftEdgeOffset = layout.background.leadingEdgeXOffset
    let topEdgeOffset = layout.background.leadingEdgeYOffset

    // Build path for each highlighted connection
    let path = WorkspaceBezierPath(engine: layout.engine)

    for connection in layout.block.directConnections {
      if !layout.isConnectionHighlighted(connection) {
        continue
      }

      let connectionRelativePosition = connection.position - layout.absolutePosition

      // Highlight specific connection
      switch connection.type {
      case .inputValue, .outputValue:
        // The connection is in the shape of the puzzle tab. Figure out the starting draw position.
        let connectionStartPosition = WorkspacePoint(
          x: connectionRelativePosition.x + puzzleTabWidth,
          y: connectionRelativePosition.y - puzzleTabHeight / 2)
        var lineStartY = connectionStartPosition.y
        var lineEndY = connectionStartPosition.y + puzzleTabHeight

        // Figure out if there can be line extensions drawn on the top and bottom of the puzzle tab.
        if connection.type == .inputValue,
          let inputLayout = connection.sourceInput?.layout as? DefaultInputLayout {
          if layout.inputsInline {
            lineStartY = inputLayout.inlineConnectorPosition.y + cornerRadius
            lineEndY = inputLayout.inlineConnectorPosition.y +
              inputLayout.inlineConnectorSize.height - cornerRadius
          } else {
            lineStartY = inputLayout.relativePosition.y + cornerRadius
            lineEndY =
              inputLayout.relativePosition.y + inputLayout.contentSize.height - cornerRadius
          }
        } else if connection.sourceBlock == layout.block && connection.type == .outputValue {
          // Use block size to figure out line extensions
          lineStartY = topEdgeOffset + cornerRadius
          lineEndY = topEdgeOffset + layout.contentSize.height - cornerRadius
        }

        // Draw top line extension, puzzle tab, and then bottom line extension.
        path.move(to: WorkspacePoint(x: connectionStartPosition.x, y: lineStartY), relative: false)
        path.addLine(to: connectionStartPosition, relative: false)
        PathHelper.addPuzzleTab(
          toPath: path,
          drawTopToBottom: true,
          puzzleTabWidth: puzzleTabWidth,
          puzzleTabHeight: puzzleTabHeight)
        path.addLineTo(x: path.currentWorkspacePoint.x, y: lineEndY, relative: false)

      case .previousStatement, .nextStatement:
        // The connection is in the shape of a notch. Figure out the starting draw position.
        let connectionStartPosition = WorkspacePoint(
          x: connectionRelativePosition.x - notchWidth / 2,
          y: connectionRelativePosition.y - notchHeight)
        var lineStartX = connectionStartPosition.x
        var lineEndX = connectionStartPosition.x + puzzleTabWidth

        // Figure out if there can be line extensions drawn to the left and right of the notch.
        if let inputLayout = connection.sourceInput?.layout as? DefaultInputLayout,
          let rowIndex = layout.background.rows.index(where: { $0.layouts.contains(inputLayout) }) {
          // Use input row information to figure out line extensions
          let backgroundRow = layout.background.rows[rowIndex]

          lineStartX = xLeftEdgeOffset + backgroundRow.statementIndent + cornerRadius
          lineEndX = backgroundRow.rightEdge - cornerRadius

          if connection.type == .nextStatement && rowIndex > 0 {
            // For next statements, their top edge is the maximum of the previous row's right edge
            // and its own row's right edge.
            lineEndX = max(lineEndX, layout.background.rows[rowIndex - 1].rightEdge - cornerRadius)
          }
        } else if connection.sourceBlock == layout.block {
          // Use block information to figure out line extensions
          lineStartX = xLeftEdgeOffset + cornerRadius

          if connection.type == .previousStatement,
            let firstBackgroundRow = layout.background.rows.first {
            lineEndX = firstBackgroundRow.rightEdge - cornerRadius
          } else if connection.type == .nextStatement,
            let lastBackgroundRow = layout.background.rows.last {
            lineEndX = lastBackgroundRow.rightEdge - cornerRadius
          }
        }

        // Draw left line extension, notch, and then right line extension.
        path.move(to: WorkspacePoint(x: lineStartX, y: connectionStartPosition.y), relative: false)
        path.addLine(to: connectionStartPosition, relative: false)
        PathHelper.addNotch(
          toPath: path, drawLeftToRight: true, notchWidth: notchWidth, notchHeight: notchHeight)
        path.addLineTo(x: lineEndX, y: path.currentWorkspacePoint.y, relative: false)
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
    hsba.saturation *= config.float(for: DefaultLayoutConfig.BlockShadowSaturationMultiplier)
    hsba.brightness = min(
      hsba.brightness * config.float(for: DefaultLayoutConfig.BlockShadowBrightnessMultiplier), 1)
    return UIColor(
      hue: hsba.hue, saturation: hsba.saturation, brightness: hsba.brightness, alpha: hsba.alpha)
  }
}
