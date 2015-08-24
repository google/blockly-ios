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
View for rendering a |BlockLayout|.
*/
@objc(BKYBlockView)
public class BlockView: UIView {

  // MARK: - Properties

  /** Layout object to render */
  public var layout: BlockLayout? {
    didSet {
      refresh()
    }
  }

  /** Manager for recyclable views. */
  private let _viewManager = ViewManager.sharedInstance

  /** View for rendering the block's background */
  private let _blockBackgroundView: BezierPathView = ViewManager.sharedInstance.bezierPathView()

  /** View for rendering the block's highlight overly */
  private lazy var _highlightOverlayView: BezierPathView =
    ViewManager.sharedInstance.bezierPathView()

  /** Field subviews */
  private var _fieldViews = [UIView]()

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    self.translatesAutoresizingMaskIntoConstraints = false

    // Configure background

    _blockBackgroundView.frame = self.bounds
    _blockBackgroundView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    addSubview(_blockBackgroundView)
    sendSubviewToBack(_blockBackgroundView)
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func layoutSubviews() {
    super.layoutSubviews()

    // TODO:(vicng) Layout block background

    // TODO:(vicng) Layout fields
  }

  // MARK: - Private

  private func refresh() {
    // Remove all subviews and recycle
    for view in self.subviews {
      // TODO:(vicng) Recycle view
      view.removeFromSuperview()
    }

    guard let layout = self.layout else {
      self.frame = CGRectZero
      self.backgroundColor = UIColor.clearColor()
      return
    }

    self.frame = layout.viewFrameAtScale(1.0)
    // TODO:(vicng) Set the background colour properly
    self.backgroundColor = UIColor.redColor()

    // TODO:(vicng) Re-draw this view too

    // TODO:(vicng) Add field views
  }
}

// MARK: - Protocol - Recyclable

extension BlockView: Recyclable {
  public func recycle() {
    // TODO: (vicng) Release all resources held by this object and recycle any subviews if necessary
  }
}
