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
View for rendering a |WorkspaceLayout|.
*/
@objc(BKYWorkspaceView)
public class WorkspaceView: UIScrollView {

  // MARK: - Properties

  /** Layout object to render */
  public var layout: WorkspaceLayout! {
    didSet {
      self.frame = (layout != nil) ? layout.viewFrameAtScale(1.0) : CGRectZero
      // TODO:(vicng) Re-draw this view too
    }
  }

  private let _viewManager = ViewManager.sharedInstance

  /** Gesture recognizer to handle moving blocks around. */
  private var blockPanGestureRecognizer: UIPanGestureRecognizer!

  /** Gesture recognizer to handle selecting blocks. */
  private var blockTapGestureRecognizer: UITapGestureRecognizer!

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    blockPanGestureRecognizer =
      UIPanGestureRecognizer(target: self, action: "didRecognizePanGesture:")
    blockTapGestureRecognizer =
      UITapGestureRecognizer(target: self, action: "didRecognizeTapGesture:")
  }

  // MARK: - Public

  /** Re-refreshes blocks that are currently visible in the viewport. */
  public func refresh() {
    // TODO:(vicng) Figure out a good amount to pad the workspace by
    self.contentSize = CGSizeMake(
      layout.size.width + UIScreen.mainScreen().bounds.size.width,
      layout.size.height + UIScreen.mainScreen().bounds.size.height)

    // Get blocks that are in the current viewport
    for descendantLayout in layout.allBlockLayoutDescendants() {
      if !shouldRenderLayout(descendantLayout) {
        return
      }

      let descendantView = _viewManager.blockViewForLayout(descendantLayout)
      descendantView.addGestureRecognizer(blockPanGestureRecognizer)
      descendantView.addGestureRecognizer(blockTapGestureRecognizer)

      if descendantView.superview != nil {
        descendantView.removeFromSuperview()
      }
      self.addSubview(descendantView)
    }
  }

  // MARK: - Gesture Recognizers

  internal func didRecognizePanGesture(gesture: UIPanGestureRecognizer) {
    guard let blockView = gesture.view as? BlockView else {
      return
    }

    // TODO:(vicng) Polish this implementation (for now, it is here as proof-of-concept). Also,
    // do not modify blockView.frame directly -- instead modify blockView.layout.relativePosition,
    // which should generate an event to update blockView.frame.
    blockView.frame.origin = gesture.locationInView(self)
  }

  internal func didRecognizeTapGesture(gesture: UITapGestureRecognizer) {
    guard let blockView = gesture.view as? BlockView else {
      return
    }

    // TODO:(vicng) Set this block as "selected" within the workspace
  }

  // MARK: - Private

  private func shouldRenderLayout(layout: Layout) -> Bool {
    // TODO:(vicng) Implement this method
    return true
  }
}
