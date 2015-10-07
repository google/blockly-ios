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
public class BlockView: UIView {
  // MARK: - Properties

  /// Layout object to render
  public var layout: BlockLayout? {
    didSet {
      if layout != oldValue {
        oldValue?.delegate = nil
        layout?.delegate = self
        refresh()
      }
    }
  }

  /// Manager for acquiring and recycling views.
  private let _viewManager = ViewManager.sharedInstance

  /// View for rendering the block's background
  private let _blockBackgroundView: BezierPathView = {
    return ViewManager.sharedInstance.viewForType(BezierPathView.self)
    }()

  /// View for rendering the block's highlight overly
  private lazy var _highlightOverlayView: BezierPathView = {
    return ViewManager.sharedInstance.viewForType(BezierPathView.self)
    }()

  /// Field subviews
  private var _fieldViews = [UIView]()

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    self.translatesAutoresizingMaskIntoConstraints = false

    // Configure background
    _blockBackgroundView.frame = self.bounds
    _blockBackgroundView.backgroundColor = UIColor.clearColor()
    _blockBackgroundView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    addSubview(_blockBackgroundView)
    sendSubviewToBack(_blockBackgroundView)
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Public

  /**
  Refreshes the view based on the current layout.
  */
  public func refresh() {
    // Remove and recycle field subviews
    recycleFieldViews()

    guard let layout = self.layout else {
      self.frame = CGRectZero
      self.backgroundColor = UIColor.clearColor()
      return
    }

    self.frame = layout.viewFrame
    self.layer.zPosition = layout.zPosition

    // TODO:(vicng) Set the colours properly
    _blockBackgroundView.strokeColour = UIColor.grayColor()
    _blockBackgroundView.fillColour = UIColor.yellowColor()
    _blockBackgroundView.bezierPath = blockBackgroundBezierPath()

    // TODO:(vicng) Optimize this so this view only needs is created/added when the user
    // highlights the block.
    _highlightOverlayView.strokeColour = UIColor.orangeColor()
    _highlightOverlayView.fillColour = UIColor.orangeColor()
    _highlightOverlayView.frame = self.bounds
    _highlightOverlayView.backgroundColor = UIColor.clearColor()
    _highlightOverlayView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    _highlightOverlayView.bezierPath = blockHighlightBezierPath()
    addSubview(_highlightOverlayView)
    sendSubviewToBack(_highlightOverlayView)

    // Add field views
    for fieldLayout in layout.fieldLayouts {
      if let fieldView = ViewManager.sharedInstance.fieldViewForLayout(fieldLayout) {
        _fieldViews.append(fieldView)

        addSubview(fieldView)
      }
    }
  }
}

// MARK: - Recyclable implementation

extension BlockView: Recyclable {
  public func recycle() {
    self.layout = nil

    recycleFieldViews()

    _blockBackgroundView.removeFromSuperview()
    ViewManager.sharedInstance.recycleView(_blockBackgroundView)

    _highlightOverlayView.removeFromSuperview()
    ViewManager.sharedInstance.recycleView(_highlightOverlayView)
  }

  private func recycleFieldViews() {
    for fieldView in _fieldViews {
      fieldView.removeFromSuperview()

      if fieldView is Recyclable {
        ViewManager.sharedInstance.recycleView(fieldView)
      }
    }
    _fieldViews = []
  }
}

// MARK: - LayoutDelegate implementation

extension BlockView: LayoutDelegate {
  public func layoutDidChange(layout: Layout) {
    refresh()
  }
}

// MARK: - Bezier Path Builders

extension BlockView {
  private func blockBackgroundBezierPath() -> UIBezierPath? {
    guard let layout = self.layout else {
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

    return path.viewBezierPath
  }
  
  private func blockHighlightBezierPath() -> UIBezierPath? {
    guard let layout = self.layout else {
      return nil
    }
    
    // TODO:(vicng) Build highlight bezier path
    return nil
  }
}
