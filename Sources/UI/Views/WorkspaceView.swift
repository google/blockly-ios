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

// MARK: - WorkspaceView Class

/**
View for rendering a `WorkspaceLayout`.
*/
@objc(BKYWorkspaceView)
@objcMembers open class WorkspaceView: LayoutView {

  // MARK: - Constants

  /// Value representing a location within the workspace view.
  @objc(BKYWorkspaceViewLocation)
  public enum Location: Int {
    /// Represents no specific location in the workspace view.
    case anywhere = 0
    /// The top-leading corner of the workspace view.
    case topLeading
    /// The top-center area of the workspace view.
    case topCenter
    /// The top-trailing corner of the workspace view.
    case topTrailing
    /// The middle-leading area of the workspace view.
    case middleLeading
    /// The center of the workspace view.
    case center
    /// The middle-trailing area of the workspace view.
    case middleTrailing
    /// The bottom-leading corner of the workspace view.
    case bottomLeading
    /// The bottom-center area of the workspace view.
    case bottomCenter
    /// The bottom-trailing corner of the workspace view.
    case bottomTrailing
  }

  // MARK: - Properties

  /// Convenience property for accessing `self.layout` as a `WorkspaceLayout`
  open var workspaceLayout: WorkspaceLayout? {
    return layout as? WorkspaceLayout
  }

  /// All top-level `BlockGroupView` instances underneath the workspace
  open fileprivate(set) var blockGroupViews = Set<BlockGroupView>()

  /// Scroll view used to render the workspace
  open lazy var scrollView: WorkspaceView.ScrollView = {
    let scrollView = WorkspaceView.ScrollView(frame: self.bounds)
    scrollView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    scrollView.autoresizesSubviews = false
    scrollView.delegate = self
    scrollView.bouncesZoom = false
    return scrollView
  }()

  /// The reference to the drag layer view.
  private var _dragLayerView: ZIndexedGroupView?

  /// Optional layer used for dragging blocks. When set, block drags are automatically moved to this
  /// layer instead of the default one provided by `WorkspaceView`.
  open var dragLayerView: ZIndexedGroupView! {
    get { return _dragLayerView ?? self.scrollView.containerView }
    set(value) { _dragLayerView = value }
  }

  /// Flag if the canvas should be padded with extra spaces around its edges via
  /// `self.canvasPadding`. If set to false, the user will only be allowed to scroll the exact
  /// amount needed to view all blocks. Note that padding is only added if there is at least one
  /// block in the workspace.
  open var allowCanvasPadding: Bool = true {
    didSet {
      updateCanvasSizeFromLayout()
    }
  }

  /// The amount of padding to apply to the edges of the workspace canvas, by percentage of view
  /// frame size
  open var canvasPaddingScale = EdgeInsets(top: 0.5, leading: 0.2, bottom: 0.95, trailing: 0.9)

  /**
   The amount of padding that should be added to the edges when automatically scrolling a
   `Block` into view or setting the viewport to a specific location.

   - note: See `scrollBlockIntoView(_:location:animated:)` and `setViewport(to:animated:)` for
   more information.
   */
  open var scrollIntoViewEdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 100, trailing: 20)

  /// Enables/disables the zooming of a workspace. Defaults to false.
  open var allowZoom = false

  /// The last known value for `workspaceLayout.contentOrigin`
  fileprivate var _lastKnownContentOrigin: WorkspacePoint = WorkspacePoint.zero

  /// The offset of the view when zooming begins
  fileprivate var _zoomBeginOffset: CGPoint = CGPoint.zero

  /// The offset between the zoom offset and the center of the zoom pinch
  fileprivate var _zoomPinchOffset: CGPoint = CGPoint.zero

  /// Keeps track of the initial scale of the scroll view before the zoom begins.
  fileprivate var _zoomInitialScale: CGFloat = 1

  /// Flag for disabling inadvertent calls to `removeExcessScrollSpace()`
  fileprivate var _disableRemoveExcessScrollSpace = false

  /// Remember the state of the vertical scroll indicator, to re-enable after turning it off
  fileprivate var _scrollViewShowedVerticalScrollIndicator: Bool = true

  /// Remember the state of the horizontal scroll indicator, to re-enable after turning it off
  fileprivate var _scrollViewShowedHorizontalScrollIndicator: Bool = true

  // MARK: - Initializers

  /// Default initializer for workspace view.
  public required init() {
    super.init(frame: CGRect.zero)

    addSubview(scrollView)
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  open override func refreshView(
    forFlags flags: LayoutFlag = LayoutFlag.All, animated: Bool = false)
  {
    super.refreshView(forFlags: flags, animated: animated)

    guard let layout = self.layout else {
      return
    }

    runAnimatableCode(animated) {
      if self.allowZoom {
        self.scrollView.minimumZoomScale = layout.engine.minimumScale / layout.engine.scale
        self.scrollView.maximumZoomScale = layout.engine.maximumScale / layout.engine.scale
      }

      if flags.intersectsWith([Layout.Flag_NeedsDisplay, WorkspaceLayout.Flag_UpdateCanvasSize]) {
        self.updateCanvasSizeFromLayout()
      }
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()

    // Remove all block group views
    for view in scrollView.containerView.subviews {
      if let blockGroupView = view as? BlockGroupView {
        removeBlockGroupView(blockGroupView)
      }
    }

    scrollView.contentSize = CGSize.zero
    scrollView.containerView.frame = CGRect.zero

    // Reset content offset to "zero". In iOS 11, we need to account for the safe area.
    if #available(iOS 11.0, *) {
      scrollView.contentOffset = CGPoint(x: -scrollView.adjustedContentInset.left,
                                         y: -scrollView.adjustedContentInset.top)
    } else {
      scrollView.contentOffset = CGPoint.zero
    }

    updateDragLayerViewFrame()
  }

  open override func layoutSubviews() {
    super.layoutSubviews()

    updateCanvasSizeFromLayout()
  }

  // MARK: - Public

  /**
   Returns the logical Workspace position of a given `BlockView` based on its position relative
   to this `WorkspaceView`.

   - parameter blockView: The `BlockView`
   - returns: The `blockView`'s corresponding workspace position.
   */
  public final func workspacePosition(fromBlockView blockView: UIView) -> WorkspacePoint {
    var blockViewPoint = CGPoint.zero
    if (workspaceLayout?.engine.rtl ?? false) {
      // In RTL, the block's workspace position is mapped to the top-right corner point (whereas
      // it is the top-left corner point in LTR)
      blockViewPoint = CGPoint(x: blockView.bounds.width, y: 0)
    }
    let workspaceViewPosition =
      blockView.convert(blockViewPoint, to: scrollView)
    return workspacePosition(fromViewPoint: workspaceViewPosition)
  }

  /**
   Automatically adjusts the workspace's scroll view to bring a given `Block` into view.

   - parameter block: The `Block` to bring into view.
   - parameter location: The area of the screen where the block should appear. If `.anywhere`
   is specified, the viewport is changed the minimal amount necessary to bring the block
   into view.
   - parameter animated: Flag determining if this scroll view adjustment should be animated.
   - note: See `scrollIntoViewEdgeInsets`.
   */
  open func scrollBlockIntoView(_ block: Block, location: Location = .anywhere, animated: Bool) {
    guard let blockLayout = block.layout,
      let blockView = ViewManager.shared.findBlockView(forLayout: blockLayout),
      let workspaceLayout = self.workspaceLayout else
    {
      return
    }

    var contentOffset = scrollView.contentOffset
    let blockViewRect = blockView.convert(blockView.bounds, to: scrollView)
    var scrollAreaInsets = UIEdgeInsets(top: scrollIntoViewEdgeInsets.top,
                                        left: scrollIntoViewEdgeInsets.left,
                                        bottom: scrollIntoViewEdgeInsets.bottom,
                                        right: scrollIntoViewEdgeInsets.right)

    // Make sure the insets accounts for the safe area
    if #available(iOS 11.0, *) {
      scrollAreaInsets.left += scrollView.safeAreaInsets.left
      scrollAreaInsets.right += scrollView.safeAreaInsets.right
      scrollAreaInsets.top += scrollView.safeAreaInsets.top
      scrollAreaInsets.bottom += scrollView.safeAreaInsets.bottom
    }

    if location == .anywhere {
      // No location was specified. Just scroll the block so it's barely in view, relative to its
      // current position.
      var scrollViewRect =
        CGRect(x: scrollView.contentOffset.x, y: scrollView.contentOffset.y,
               width: scrollView.bounds.width, height: scrollView.bounds.height)

      // Force the blockView to be inset within the scroll view rectangle
      scrollViewRect.origin.x += scrollAreaInsets.left
      scrollViewRect.size.width -= scrollAreaInsets.left + scrollAreaInsets.right
      scrollViewRect.origin.y += scrollAreaInsets.top
      scrollViewRect.size.height -= scrollAreaInsets.top + scrollAreaInsets.bottom

      if workspaceLayout.engine.rtl {
        // Check left edge (as long as the block width < visible view width)
        if blockViewRect.width <= scrollViewRect.width && blockViewRect.minX < scrollViewRect.minX {
          contentOffset.x -= (scrollViewRect.minX - blockViewRect.minX)
        }
        // Check right edge
        if blockViewRect.maxX > scrollViewRect.maxX {
          contentOffset.x += (blockViewRect.maxX - scrollViewRect.maxX)
        }
      } else {
        // Check right edge (as long as the block width < visible view width)
        if blockViewRect.width <= scrollViewRect.width && blockViewRect.maxX > scrollViewRect.maxX {
          contentOffset.x += (blockViewRect.maxX - scrollViewRect.maxX)
        }
        // Check left edge
        if blockViewRect.minX < scrollViewRect.minX {
          contentOffset.x -= (scrollViewRect.minX - blockViewRect.minX)
        }
      }

      // Check bottom edge (as long as the block height < visible view height)
      if blockViewRect.height <= scrollViewRect.height && blockViewRect.maxY > scrollViewRect.maxY {
        contentOffset.y += (blockViewRect.maxY - scrollViewRect.maxY)
      }
      // Check top edge
      if blockViewRect.minY < scrollViewRect.minY {
        contentOffset.y -= (scrollViewRect.minY - blockViewRect.minY)
      }
    } else {
      // Calculate X coordinate
      let useLeadingEdge =
        (location == .bottomLeading || location == .middleLeading || location == .topLeading)
      let useHorizontalCenter =
        (location == .topCenter || location == .center || location == .bottomCenter)
      let useTrailingEdge =
        (location == .bottomTrailing || location == .middleTrailing || location == .topTrailing)
      let rtl = workspaceLayout.engine.rtl

      if (useLeadingEdge && !rtl) || (useTrailingEdge && rtl) {
        // Use left edge
        contentOffset.x = blockViewRect.minX - scrollAreaInsets.left
      } else if (useLeadingEdge && rtl) || (useTrailingEdge && !rtl) {
        // Use right edge
        contentOffset.x =
          blockViewRect.maxX + scrollAreaInsets.right - scrollView.bounds.width
      } else if useHorizontalCenter {
        contentOffset.x = blockViewRect.midX - (scrollView.bounds.width / 2)
      }

      // Calculate Y coordinate
      switch location {
      case .topLeading, .topCenter, .topTrailing:
        // Top edge
        contentOffset.y = blockViewRect.minY - scrollAreaInsets.top
      case .bottomLeading, .bottomCenter, .bottomTrailing:
        // Bottom edge
        contentOffset.y =
          blockViewRect.maxY + scrollAreaInsets.bottom - scrollView.bounds.height
      case .middleLeading, .center, .middleTrailing:
        // Middle
        contentOffset.y = blockViewRect.midY - (scrollView.bounds.height / 2)
      case .anywhere:
        // Already handled outside of this.
        break
      }
    }

    // Finally, update the scroll view
    if scrollView.contentOffset != contentOffset {
      // The new content offset may require the content size to expand and
      // the container frame to change.
      var contentSize = scrollView.contentSize
      var containerViewFrame = scrollView.containerView.frame
      if contentOffset.x < 0 {
        contentSize.width += -contentOffset.x
        containerViewFrame.origin.x += -contentOffset.x
        contentOffset.x = 0
      } else if contentOffset.x + scrollView.bounds.size.width > contentSize.width {
        contentSize.width += contentOffset.x + scrollView.bounds.size.width - contentSize.width
      }

      if contentOffset.y < 0 {
        contentSize.height += -contentOffset.y
        containerViewFrame.origin.y += -contentOffset.y
        contentOffset.y = 0
      } else if contentOffset.y + scrollView.bounds.size.height > contentSize.height {
        contentSize.height += contentOffset.y + scrollView.bounds.size.height - contentSize.height
      }

      runAnimatableCode(animated) {
        self._disableRemoveExcessScrollSpace = true

        if self.scrollView.contentSize != contentSize {
          self.scrollView.contentSize = contentSize
        }
        if self.scrollView.containerView.frame != containerViewFrame {
          self.scrollView.containerView.frame = containerViewFrame
        }
        // Now we can safely set the content offset.
        self.scrollView.setContentOffset(contentOffset, animated: animated)

        self.updateDragLayerViewFrame()

        self._disableRemoveExcessScrollSpace = false
      }
    }
  }

  /**
   Sets the content offset of the workspace's scroll view so that a specific location in the
   workspace is visible.

   - parameter location: The `Location` that should be made visible. If `.anywhere` is specified,
   this method does nothing.
   - parameter animated: Flag determining if this scroll view adjustment should be animated.
   - note: See `scrollIntoViewEdgeInsets`.
   */
  open func setViewport(to location: Location, animated: Bool) {
    guard let workspaceLayout = self.workspaceLayout, location != .anywhere else {
      return
    }

    var contentOffset = CGPoint.zero
    var scrollAreaInsets = UIEdgeInsets(top: scrollIntoViewEdgeInsets.top,
                                        left: scrollIntoViewEdgeInsets.left,
                                        bottom: scrollIntoViewEdgeInsets.bottom,
                                        right: scrollIntoViewEdgeInsets.right)

    // Make sure the insets accounts for the safe area
    if #available(iOS 11.0, *) {
      scrollAreaInsets.left += scrollView.safeAreaInsets.left
      scrollAreaInsets.right += scrollView.safeAreaInsets.right
      scrollAreaInsets.top += scrollView.safeAreaInsets.top
      scrollAreaInsets.bottom += scrollView.safeAreaInsets.bottom
    }

    // Calculate X coordinate
    let useLeadingEdge =
      (location == .bottomLeading || location == .middleLeading || location == .topLeading)
    let useTrailingEdge =
      (location == .bottomTrailing || location == .middleTrailing || location == .topTrailing)
    let useCenter =
      (location == .topCenter || location == .center || location == .bottomCenter)
    let rtl = workspaceLayout.engine.rtl

    if (useLeadingEdge && !rtl) || (useTrailingEdge && rtl) {
      // Use left edge
      contentOffset.x = scrollView.containerView.frame.minX - scrollAreaInsets.left
    } else if (useLeadingEdge && rtl) || (useTrailingEdge && !rtl) {
      // Use right edge
      contentOffset.x =
        scrollView.containerView.frame.maxX + scrollAreaInsets.right - scrollView.bounds.width
    } else if useCenter {
      contentOffset.x = scrollView.containerView.center.x - (scrollView.bounds.width / 2)
    }

    // Calculate Y coordinate
    switch location {
    case .topLeading, .topCenter, .topTrailing:
      // Top edge
      contentOffset.y = scrollView.containerView.frame.minY - scrollAreaInsets.top
    case .bottomLeading, .bottomCenter, .bottomTrailing:
      // Bottom edge
      contentOffset.y =
        scrollView.containerView.frame.maxY + scrollAreaInsets.bottom - scrollView.bounds.height
    case .middleLeading, .center, .middleTrailing:
      // Middle
      contentOffset.y = scrollView.containerView.center.y - (scrollView.bounds.height / 2)
    case .anywhere:
      break
    }

    // Make sure the content offset is not too negative (this would cause unnecesary scrolling
    // immediately after it is set). Therefore, we must ensure that the
    // content offset >= scroll area insets.
    contentOffset.x = max(contentOffset.x, -scrollAreaInsets.left)
    contentOffset.y = max(contentOffset.y, -scrollAreaInsets.top)

    if contentOffset != scrollView.contentOffset {
      // Finally, set the content offset.
      runAnimatableCode(animated) {
        self._disableRemoveExcessScrollSpace = true
        self.scrollView.setContentOffset(contentOffset, animated: animated)
        self.updateDragLayerViewFrame()
        self._disableRemoveExcessScrollSpace = false
      }
    }
  }

  /**
  Maps a `UIView` point relative to `self.scrollView` to a logical Workspace
  position.

  - parameter point: The `UIView` point
  - returns: The corresponding `WorkspacePoint`
  */
  open func workspacePosition(fromViewPoint point: CGPoint) -> WorkspacePoint {
    guard let workspaceLayout = self.workspaceLayout else {
      return WorkspacePoint.zero
    }

    var viewPoint = scrollView.convert(point, to: scrollView.containerView)

    if workspaceLayout.engine.rtl {
      // In RTL, the workspace position is relative to the top-right corner of
      // `scrollView.containerView`
      viewPoint.x = scrollView.containerView.frame.width - viewPoint.x
    }

    // Account for the current content origin
    let viewContentOrigin =
      workspaceLayout.engine.viewPointFromWorkspacePoint(workspaceLayout.contentOrigin)
    viewPoint.x += viewContentOrigin.x
    viewPoint.y += viewContentOrigin.y

    // Scale this CGPoint (ie. `viewPoint`) into a WorkspacePoint
    return workspaceLayout.engine.scaledWorkspaceVectorFromViewVector(viewPoint)
  }

  // MARK: - Private

  fileprivate func canvasPadding() -> EdgeInsets {
    var scaled = EdgeInsets.zero

    let viewRect = bounds.size
    scaled.top = viewRect.height * canvasPaddingScale.top
    scaled.leading = viewRect.width * canvasPaddingScale.leading
    scaled.bottom = viewRect.height * canvasPaddingScale.bottom
    scaled.trailing = viewRect.width * canvasPaddingScale.trailing

    return scaled
  }

  fileprivate func updateCanvasSizeFromLayout() {
    guard let layout = self.workspaceLayout else {
      return
    }

    // Disable inadvertent calls to `removeExcessScrollSpace()`
    _disableRemoveExcessScrollSpace = true

    // Figure out the value that will be used for `scrollView.containerView.frame.size`
    let containerViewSize = layout.engine.viewSizeFromWorkspaceSize(layout.totalSize)

    // Figure out the amount that the content jumped by (based on the new content origin)
    let contentDelta = _lastKnownContentOrigin - layout.contentOrigin
    let contentViewDelta = layout.engine.viewPointFromWorkspacePoint(contentDelta)

    let canvasPadding = self.canvasPadding()

    // Calculate the extra padding to add around the content (it's only added if there is at least
    // one block in the workspace).
    var contentPadding = EdgeInsets.zero
    if layout.blockGroupLayouts.count > 0 {
      if allowCanvasPadding {
        // Content padding must be at least two full screen sizes in all directions or else
        // blocks will appear to jump whenever the total canvas size shrinks (eg. after blocks are
        // moved from higher value coordinates to lower value ones) or grows in the negative
        // direction. Any unnecessary padding is removed at the end in `removeExcessScrollSpace()`.
        contentPadding.top = scrollView.bounds.height + canvasPadding.top
        contentPadding.leading = scrollView.bounds.width + canvasPadding.leading
        contentPadding.bottom = scrollView.bounds.height + canvasPadding.bottom
        contentPadding.trailing = scrollView.bounds.width + canvasPadding.trailing
      } else if layout.engine.rtl {
        // In RTL, the canvas width needs to completely fill the entire scroll view frame to make
        // sure that content appears right-aligned.
        contentPadding.trailing = max(scrollView.bounds.width - containerViewSize.width, 0)
      }
    }

    // Figure out the value that will be used for `scrollView.contentSize`
    var newContentSize = containerViewSize
    newContentSize.width += contentPadding.leading + contentPadding.trailing
    newContentSize.height += contentPadding.top + contentPadding.bottom

    var newContentOffset = scrollView.contentOffset

    // Update the content size of the scroll view.
    if layout.engine.rtl {
      let oldContainerFrame = scrollView.containerView.frame

      // Position the contentView relative to the top-right corner
      let containerOrigin = CGPoint(
        x: newContentSize.width - containerViewSize.width - contentPadding.leading,
        y: contentPadding.top)
      scrollView.containerView.frame = CGRect(
        x: containerOrigin.x,
        y: containerOrigin.y,
        width: containerViewSize.width,
        height: containerViewSize.height)

      // The content offset must be adjusted based on the new content origin, so it doesn't
      // appear that viewport has jumped to a new location
      // NOTE: In RTL, we jump in the opposite X direction
      newContentOffset.x -= contentViewDelta.x
      newContentOffset.y += contentViewDelta.y

      // The container view origin may have changed since the last call to
      // `updateCanvasSizeFromLayout()`, so we need to adjust the content offset for this too.
      // NOTE: In RTL, `contentOffset.x` is adjusted based on the right edge, not the left edge.
      newContentOffset.x += scrollView.containerView.frame.maxX - oldContainerFrame.maxX
      newContentOffset.y += scrollView.containerView.frame.minY - oldContainerFrame.minY
    } else {
      let containerOrigin = CGPoint(x: contentPadding.leading, y: contentPadding.top)
      let oldContainerFrame = scrollView.containerView.frame
      scrollView.containerView.frame = CGRect(
        x: containerOrigin.x,
        y: containerOrigin.y,
        width: containerViewSize.width,
        height: containerViewSize.height)

      // The content offset must be adjusted based on the new content origin, so it doesn't appear
      // that viewport has jumped to a new location
      newContentOffset.x += contentViewDelta.x
      newContentOffset.y += contentViewDelta.y

      // The container view origin may have changed since the last call to
      // `updateCanvasSizeFromLayout()`, so we need to adjust the content offset for this too.
      newContentOffset.x += scrollView.containerView.frame.minX - oldContainerFrame.minX
      newContentOffset.y += scrollView.containerView.frame.minY - oldContainerFrame.minY
    }

    // NOTE: contentOffset is only set once at the end as it's expensive to do during an animation
    scrollView.contentOffset = newContentOffset

    // Set the content size of the scroll view
    // NOTE: This has to be done *after* adjusting the `scrollView.contentOffset`. `UIScrollView`
    // will automatically adjust `contentOffset` on its own if `contentSize` shrinks and the
    // the current `contentOffset` is unreachable (but it won't change if it grows, which is why we
    // adjust `contentOffset` manually first).
    scrollView.contentSize = newContentSize

    _lastKnownContentOrigin = layout.contentOrigin

    updateDragLayerViewFrame()

    // Re-enable `removeExcessScrollSpace()` and call it
    _disableRemoveExcessScrollSpace = false
    removeExcessScrollSpace()
  }

  fileprivate func removeExcessScrollSpace(ignoreRestrictions: Bool = false) {
    if !allowCanvasPadding || _disableRemoveExcessScrollSpace {
      return
    }
    if !ignoreRestrictions &&
      (scrollView.isDragging || scrollView.isDecelerating || scrollView.isTracking)
    {
      return
    }
    guard let layout = self.workspaceLayout else {
      return
    }

    // Disable this method from recursively calling itself
    _disableRemoveExcessScrollSpace = true

    let canvasPadding = self.canvasPadding()

    var contentOffset = scrollView.contentOffset
    var contentSize = scrollView.contentSize
    var containerViewFrame = scrollView.containerView.frame

    // Figure out the ideal placement for `scrollView.containerView`. This helps us figure out
    // the excess scrolling area that can be removed from the canvas.
    let idealContainerViewFrame: CGRect
    if layout.engine.rtl {
      // The container view in RTL must always appear right-aligned on-screen, so we calculate an
      // origin that takes into account the container view's width and the current scrollView width
      let originX = max(canvasPadding.trailing,
        scrollView.bounds.width - containerViewFrame.width -
        canvasPadding.leading)
      idealContainerViewFrame = CGRect(
        x: originX,
        y: canvasPadding.top,
        width: containerViewFrame.width + canvasPadding.leading,
        height: containerViewFrame.height + canvasPadding.bottom)
    } else {
      idealContainerViewFrame = CGRect(
        x: canvasPadding.leading,
        y: canvasPadding.top,
        width: containerViewFrame.width + canvasPadding.trailing,
        height: containerViewFrame.height + canvasPadding.bottom)
    }

    // Remove excess left space
    let leftExcessSpace = containerViewFrame.minX - idealContainerViewFrame.minX

    if leftExcessSpace > 0 && contentOffset.x >= 0 {
      let adjustment = min(leftExcessSpace, contentOffset.x)
      contentOffset.x -= adjustment
      contentSize.width -= adjustment
      containerViewFrame.origin.x -= adjustment
    }

    // Remove excess right space
    let rightExcessSpace = contentSize.width -
      (containerViewFrame.minX + idealContainerViewFrame.width)

    if rightExcessSpace > 0 &&
      (contentOffset.x + scrollView.bounds.width) <= contentSize.width
    {
      let adjustment = min(rightExcessSpace,
        contentSize.width - (contentOffset.x + scrollView.bounds.width))
      contentSize.width -= adjustment
    }

    // Remove excess top space
    let topExcessSpace = containerViewFrame.minY - idealContainerViewFrame.minY
    if topExcessSpace > 0 && contentOffset.y >= 0 {
      let adjustment = min(topExcessSpace, contentOffset.y)
      contentOffset.y -= adjustment
      contentSize.height -= adjustment
      containerViewFrame.origin.y -= adjustment
    }

    // Remove excess bottom space
    let bottomExcessSpace = contentSize.height -
      (containerViewFrame.origin.y + idealContainerViewFrame.height)

    if bottomExcessSpace > 0 &&
      (contentOffset.y + scrollView.bounds.height) <= contentSize.height
    {
      let adjustment = min(bottomExcessSpace,
        contentSize.height - contentOffset.y - scrollView.bounds.height)
      contentSize.height -= adjustment
    }

    // NOTE: These values are set at the end as it's expensive to continually change them during an
    // animation
    scrollView.contentOffset = contentOffset
    scrollView.contentSize = contentSize
    scrollView.containerView.frame = containerViewFrame

    updateDragLayerViewFrame()

    // Re-enable this method
    _disableRemoveExcessScrollSpace = false
  }

  /**
   Block views calculate their workspace coordinates based on their relative location to
   `scrollView.containerView`. However, block views are temporarily moved to `self.dragLayerView`
   during drags, which can cause location calculations to be incorrect.

   This method updates `self.dragLayerView.frame` to match `scrollView.containerView.frame`, in
   order to solve this problem.
   */
  fileprivate func updateDragLayerViewFrame() {
    if let dragLayer = _dragLayerView {
      let newFrame = scrollView.containerView.convert(
        scrollView.containerView.bounds, to: dragLayer.superview)
      dragLayer.frame = newFrame
    }
  }

  /**
   Returns `if a given block layout should be rendered within this workspace view.

   - parameter blockLayout: The `BlockLayout`.
   - returns: `true` if a given block layout should be rendered within this workspace view.
   `false` otherwise.
  */
  fileprivate func shouldRenderBlockLayout(_ blockLayout: BlockLayout) -> Bool {
    // Allow blocks within a 1/2 screen away to be rendered
    let xDelta = scrollView.contentSize.width / 2
    let yDelta = scrollView.contentSize.height / 2
    let minX = scrollView.contentOffset.x - xDelta
    let maxX = scrollView.contentOffset.x + scrollView.contentSize.width + xDelta
    let minY = scrollView.contentOffset.y - yDelta
    let maxY = scrollView.contentOffset.y + scrollView.contentSize.height + yDelta
    let leftMostEdge = blockLayout.viewFrame.minX
    let rightMostEdge = blockLayout.viewFrame.maxX
    let topMostEdge = blockLayout.viewFrame.minY
    let bottomMostEdge = blockLayout.viewFrame.maxY

    return
      ((minX <= leftMostEdge && leftMostEdge <= maxX) ||
      (minX <= rightMostEdge && rightMostEdge <= maxX)) &&
      ((minY <= topMostEdge && topMostEdge <= maxY) ||
      (minY <= bottomMostEdge && bottomMostEdge <= maxY))
  }
}

// MARK: - Block Group View Management

extension WorkspaceView: BlockGroupViewDelegate {
  /**
   Adds a `BlockGroupView` to the workspace's scrollview.

   - parameter blockGroupView: The given `BlockGroupView`
   */
  open func addBlockGroupView(_ blockGroupView: BlockGroupView) {
    blockGroupView.delegate = self
    upsertBlockGroupView(blockGroupView)
    blockGroupViews.insert(blockGroupView)
  }

  /**
   Removes a given `BlockGroupView` from the workspace's scrollview and recycles it.

   - parameter blockGroupView: The given `BlockGroupView`
   */
  open func removeBlockGroupView(_ blockGroupView: BlockGroupView) {
    blockGroupView.delegate = nil
    blockGroupViews.remove(blockGroupView)
    blockGroupView.removeFromSuperview()
  }

  /**
   Upserts a given `BlockGroupView` to either `self.scrollView.containerView` or
   `self.dragLayerView`, depending on if its being dragged.

   - parameter blockGroupView: The `BlockGroupView` to upsert.
   */
  internal func upsertBlockGroupView(_ blockGroupView: BlockGroupView) {
    if blockGroupView.dragging && blockGroupView.superview != dragLayerView {
      dragLayerView.upsertView(blockGroupView)
    } else if !blockGroupView.dragging && blockGroupView.superview != scrollView.containerView {
      scrollView.containerView.upsertView(blockGroupView)
    }
  }

  open func blockGroupViewDidUpdateDragging(_ blockGroupView: BlockGroupView) {
    upsertBlockGroupView(blockGroupView)
  }
}

// MARK: - UIScrollViewDelegate Implementation

extension WorkspaceView: UIScrollViewDelegate {
  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    removeExcessScrollSpace()
  }

  public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)
  {
    removeExcessScrollSpace()
  }

  public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return self.scrollView.containerView
  }

  public func scrollViewWillBeginZooming(_ zoomScrollView: UIScrollView, with view: UIView?) {
    _scrollViewShowedVerticalScrollIndicator = scrollView.showsVerticalScrollIndicator
    _scrollViewShowedHorizontalScrollIndicator = scrollView.showsHorizontalScrollIndicator

    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false

    // Save the offset of the zoom pinch from the content's offset, so we can zoom on the pinch.
    _zoomPinchOffset = offsetOfPinch(scrollView, withView: scrollView.containerView)
    var offset = scrollView.contentOffset + _zoomPinchOffset
    offset.x = offset.x * scrollView.zoomScale
    offset.y = offset.y * scrollView.zoomScale

    // Save the contentOffset + the offset from the pinch, so we can zoom on the pinch point.
    _zoomBeginOffset = offset

    // Keep track of the initial scale so we can fix the "jumping" problem in RTL.
    _zoomInitialScale = scrollView.zoomScale
  }

  public func scrollViewDidZoom(_ zoomScrollView: UIScrollView) {
    // Reset the offset while zooming, so we stay centered on the same point.
    var offset = _zoomBeginOffset
    offset.x = offset.x * scrollView.zoomScale
    offset.y = offset.y * scrollView.zoomScale

    scrollView.contentOffset = offset - _zoomPinchOffset
  }

  public func scrollViewDidEndZooming(_ scrollView: UIScrollView,
                                      with view: UIView?, atScale scale: CGFloat) {
    guard let workspaceLayout = self.workspaceLayout else {
      return
    }

    // Scale the content by the zoom level, and reset the zoom. Also, save the current offset, since
    // changing the zoomScale resets the contentOffset, which causes an apparent jump.
    var resetOffset = scrollView.contentOffset
    if workspaceLayout.engine.rtl {
      // In RTL, we need to account for the scaled change in width or else jumping will occur.
      resetOffset.x -=
        (self.scrollView.containerView.frame.width * (scale - _zoomInitialScale) / scale)
    }
    scrollView.zoomScale = 1
    scrollView.contentOffset = resetOffset
    scrollView.minimumZoomScale /= scale
    scrollView.maximumZoomScale /= scale

    // Ensure the excess scroll space will be trimmed, so there won't be
    // excess padding after a zoom
    workspaceLayout.engine.scale *= scale
    workspaceLayout.updateLayoutDownTree()
    removeExcessScrollSpace(ignoreRestrictions: true)

    scrollView.showsVerticalScrollIndicator = _scrollViewShowedVerticalScrollIndicator
    scrollView.showsHorizontalScrollIndicator = _scrollViewShowedHorizontalScrollIndicator
  }

  fileprivate func offsetOfPinch(_ zoomScrollView: UIScrollView, withView view:UIView?) -> CGPoint {
    if scrollView.panGestureRecognizer.numberOfTouches < 2 {
      return CGPoint.zero
    }

    let panGesture = scrollView.panGestureRecognizer
    let touch1 = panGesture.location(ofTouch: 0, in: scrollView.containerView)
    let touch2 = panGesture.location(ofTouch: 1, in: scrollView.containerView)

    var pinchCenter = CGPoint.zero
    pinchCenter.x = (max(touch1.x, touch2.x) + min(touch1.x, touch2.x)) / 2
    pinchCenter.y = (max(touch1.y, touch2.y) + min(touch1.y, touch2.y)) / 2

    return pinchCenter - scrollView.contentOffset
  }

  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // Scrolling the workspace updates the `scrollView.containerView.frame`. We need to update
    // the drag layer to match its new coordinates.
    updateDragLayerViewFrame()
  }
}

// MARK: - WorkspaceView.ScrollView Class

extension WorkspaceView {
  /**
   The scroll view used by `WorkspaceView`.
   */
  @objc(BKYWorkspaceScrollView)
  @objcMembers open class ScrollView: UIScrollView, UIGestureRecognizerDelegate {
    /// View which holds all content in the Workspace
    fileprivate var containerView: ZIndexedGroupView = {
      let view = ZIndexedGroupView(frame: CGRect.zero)
      view.autoresizesSubviews = false
      return view
    }()

    /// Flag indicating if this scroll view is zooming, zoom-bouncing, dragging, or decelerating.
    /// - note: It does not indicate if this scroll view is currently tracking touches.
    public var isInMotion: Bool {
      return isDragging || isDecelerating || isZooming || isZoomBouncing
    }

    // MARK: - Initializers

    /**
     Initializer for the scroll view inside the workspace view.

     - parameter frame: The frame for the workspace view.
     */
    fileprivate override init(frame: CGRect) {
      super.init(frame: frame)

      addSubview(containerView)

      delaysContentTouches = false
    }

    /**
     :nodoc:
     - Warning: This is currently unsupported.
     */
    public required init?(coder aDecoder: NSCoder) {
      fatalError("Called unsupported initializer")
    }
  }
}
