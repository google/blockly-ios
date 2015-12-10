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

/**
View for rendering a `BlockLayout`.
*/
@objc(BKYBlockView)
public class BlockView: LayoutView {
  // MARK: - Properties

  /// Layout object to render
  public var blockLayout: BlockLayout? {
    return layout as? BlockLayout
  }

  /// Manager for acquiring and recycling views.
  private let _viewManager = ViewManager.sharedInstance

  /// Layer for rendering the block's background
  private let _backgroundLayer = BezierPathLayer()

  /// Layer for rendering the block's highlight overlay
  private var _highlightLayer: BezierPathLayer?

  /// Field subviews
  private var _fieldViews = [LayoutView]()

  public private(set) final var zIndex: UInt = 0 {
    didSet {
      if zIndex != oldValue {
        if let superview = self.superview as? WorkspaceView.BlockGroupView {
          // Re-order this view within its parent BlockGroupView view
          superview.upsertBlockView(self)
        }
      }
    }
  }

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    // Enable user interaction on this view since it can be dragged around. This is needed by
    // `WorkspaceView.ScrollView` to distinguish between dragging blocks and scrolling the
    // workspace.
    self.userInteractionEnabled = true

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

  public override func internalRefreshView(forFlags flags: LayoutFlag) {
    guard let layout = self.blockLayout else {
      return
    }

    if flags.intersectsWith([BlockLayout.Flag_NeedsDisplay, BlockLayout.Flag_UpdateHighlight]) {
      // Update background
      // TODO:(vicng) Set the colours properly
      _backgroundLayer.strokeColor = (layout.highlighted ?
        UIColor.blueColor() : UIColor.darkGrayColor()).CGColor
      _backgroundLayer.lineWidth = layout.highlighted ?
        BlockLayout.sharedConfig.blockLineWidthHighlight :
        BlockLayout.sharedConfig.blockLineWidthRegular
      _backgroundLayer.fillColor = UIColor.greenColor().CGColor
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

    if flags.intersectsWith(BlockLayout.Flag_NeedsDisplay) {
      // Update field views
      for fieldLayout in layout.fieldLayouts {
        let cachedFieldView = ViewManager.sharedInstance.cachedFieldViewForLayout(fieldLayout)

        if cachedFieldView == nil {
          do {
            let fieldView = try ViewManager.sharedInstance.newFieldViewForLayout(fieldLayout)
            _fieldViews.append(fieldView)

            addSubview(fieldView)
          } catch let error as NSError {
            bky_assertionFailure("\(error)")
          }
        } else {
          // Do nothing. The field view will handle its own refreshing/repositioning.
        }
      }

      // TODO:(vicng) Remove any field views that no longer have field layouts associated with it
    }

    if flags.intersectsWith([BlockLayout.Flag_NeedsDisplay, BlockLayout.Flag_UpdateZIndex]) {
      self.zIndex = layout.zIndex
    }
  }

  public override func internalPrepareForReuse() {
    self.frame = CGRectZero

    for fieldView in _fieldViews {
      fieldView.removeFromSuperview()

      if let fieldLayout = fieldView.layout as? FieldLayout {
        _viewManager.uncacheFieldViewForLayout(fieldLayout)
      }
      _viewManager.recycleView(fieldView)
    }
    _fieldViews = []

    removeHighlightLayer()
  }

  // MARK: - Private

  private func addHighlightLayerWithPath(path: UIBezierPath) {
    guard let workspaceLayout = layout?.workspaceLayout else {
      return
    }

    if _highlightLayer == nil {
      let lineWidth =
        workspaceLayout.viewUnitFromWorkspaceUnit(BlockLayout.sharedConfig.blockLineWidthHighlight)
      let highlightLayer = BezierPathLayer()
      highlightLayer.lineWidth = lineWidth
      highlightLayer.strokeColor = UIColor.blueColor().CGColor
      highlightLayer.fillColor = nil
      // TODO:(vicng) The highlight view frame needs to be larger than this view since it uses a
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
}

// TODO(vicng): Move this code into BlockBackgroundLayer and BlockHighlightLayer classes

// MARK: - Bezier Path Builders

extension BlockView {
  private func blockBackgroundBezierPath() -> UIBezierPath? {
    guard let layout = self.layout as? BlockLayout else {
      return nil
    }

    let path = WorkspaceBezierPath(layout: layout.workspaceLayout)
    let background = layout.background
    var previousBottomPadding: CGFloat = 0
    let xLeftEdgeOffset: CGFloat // Note: this is the right edge in RTL layouts
    if background.maleOutputConnector {
      xLeftEdgeOffset = BlockLayout.sharedConfig.puzzleTabWidth
    } else {
      xLeftEdgeOffset = 0
    }

    path.moveToPoint(xLeftEdgeOffset, 0, relative: false)

    for (var i = 0; i < background.rows.count; i++) {
      let row = background.rows[i]

      // DRAW THE TOP EDGES

      if i == 0 && background.femalePreviousStatementConnector {
        // Draw previous statement connector
        addNotchToPath(path, drawLeftToRight: true)
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
          xLeftEdgeOffset + row.statementIndent + BlockLayout.sharedConfig.notchWidth,
          path.currentWorkspacePoint.y, relative: false)

        // Draw notch
        addNotchToPath(path, drawLeftToRight: false)

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
        addPuzzleTabToPath(path, drawTopToBottom: true)
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
        xLeftEdgeOffset + BlockLayout.sharedConfig.notchWidth, path.currentWorkspacePoint.y,
        relative: false)
      addNotchToPath(path, drawLeftToRight: false)
    }

    path.addLineToPoint(xLeftEdgeOffset, path.currentWorkspacePoint.y, relative: false)

    // DRAW THE LEFT EDGES

    if background.maleOutputConnector {
      // Add male connector
      path.addLineToPoint(
        0, BlockLayout.sharedConfig.puzzleTabHeight - path.currentWorkspacePoint.y, relative: true)

      addPuzzleTabToPath(path, drawTopToBottom: false)
    }

    path.closePath()

    // DRAW INLINE CONNECTORS
    path.viewBezierPath.usesEvenOddFillRule = true
    for backgroundRow in background.rows {
      for inlineConnector in backgroundRow.inlineConnectors {
        path.moveToPoint(
          inlineConnector.relativePosition.x + BlockLayout.sharedConfig.puzzleTabWidth,
          inlineConnector.relativePosition.y,
          relative: false)

        let xEdgeWidth = inlineConnector.size.width - BlockLayout.sharedConfig.puzzleTabWidth
        // Top edge
        path.addLineToPoint(xEdgeWidth, 0, relative: true)
        // Right edge
        path.addLineToPoint(0, inlineConnector.size.height, relative: true)
        // Bottom edge
        path.addLineToPoint(-xEdgeWidth, 0, relative: true)
        // Left edge
        path.addLineToPoint(0,
          -(inlineConnector.size.height - BlockLayout.sharedConfig.puzzleTabHeight), relative: true)
        // Puzzle notch
        addPuzzleTabToPath(path, drawTopToBottom: false)
      }
    }

    let viewBezierPath = path.viewBezierPath
    if layout.workspaceLayout.workspace.isRTL {
      applyRtlTransformToBezierPath(viewBezierPath, layout: layout)
    }

    return viewBezierPath
  }

  private func blockHighlightBezierPath() -> UIBezierPath? {
    guard let layout = self.layout as? BlockLayout else {
      return nil
    }

    let hasConnectionHighlight = layout.block.directConnections.filter { $0.highlighted }.count > 0
    if !hasConnectionHighlight {
      return nil
    }

    // Build path for each highlighted connection
    let path = WorkspaceBezierPath(layout: layout.workspaceLayout)

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
          WorkspacePointMake(BlockLayout.sharedConfig.puzzleTabWidth,
            -BlockLayout.sharedConfig.puzzleTabHeight / 2),
          relative: false)
        addPuzzleTabToPath(path, drawTopToBottom: true)
        break
      case .PreviousStatement, .NextStatement:
        // The connection point is set to the bottom of the notch. Move the point before drawing it.
        path.moveToPoint(connectionRelativePosition -
          WorkspacePointMake(BlockLayout.sharedConfig.notchWidth / 2,
            BlockLayout.sharedConfig.notchHeight),
          relative: false)
        addNotchToPath(path, drawLeftToRight: true)
        break
      }
    }

    let viewBezierPath = path.viewBezierPath
    if layout.workspaceLayout.workspace.isRTL {
      applyRtlTransformToBezierPath(viewBezierPath, layout: layout)
    }

    return viewBezierPath
  }

  private func applyRtlTransformToBezierPath(path: UIBezierPath, layout: BlockLayout) {
    var transform = CGAffineTransformIdentity
    transform = CGAffineTransformScale(transform, CGFloat(-1.0), CGFloat(1.0))
    // TODO(vicng): Need to store the actual block size in the layout (the layout.viewFrame is
    // sometimes larger for blocks with external values)
    transform = CGAffineTransformTranslate(transform, -layout.viewFrame.size.width, CGFloat(0))
    path.applyTransform(transform)
  }
}