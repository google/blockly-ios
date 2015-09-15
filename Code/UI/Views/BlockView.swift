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

    path.moveToPoint(0, 0, relative: false)

    for (var i = 0; i < background.rows.count; i++) {
      let row = background.rows[i]

      // DRAW THE TOP EDGES

      if i == 0 && background.femalePreviousStatementConnector {
        // Draw previous statement connector
        addNotchToPath(path, drawLeftToRight: true)
      }

      path.addLineToPoint(row.rightEdge, path.currentWorkspacePoint.y, relative: false)

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
          row.statementIndent + row.statementConnectorWidth,
          path.currentWorkspacePoint.y, relative: false)

        // TODO:(vicng) Draw notch

        path.addLineToPoint(row.statementIndent, path.currentWorkspacePoint.y, relative: false)

        // Inner-left side of "C"
        path.addLineToPoint(0, row.middleHeight, relative: true)

        // Inner-floor of "C"
        path.addLineToPoint(row.rightEdge, path.currentWorkspacePoint.y, relative: false)
      } else if row.femaleOutputConnector {
        // TODO:(vicng) Draw female output connector and then the rest of the middle height
        path.addLineToPoint(0, row.middleHeight, relative: true)
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
        BlockLayout.sharedConfig.notchWidth, path.currentWorkspacePoint.y, relative: true)
      addNotchToPath(path, drawLeftToRight: false)
    }

    path.addLineToPoint(0, path.currentWorkspacePoint.y, relative: false)

    // DRAW THE LEFT EDGES

    if background.maleOutputConnector {
      // TODO:(vicng) Draw male output connector
      addPuzzleTabToPath(path)
    }

    path.closePath()

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
