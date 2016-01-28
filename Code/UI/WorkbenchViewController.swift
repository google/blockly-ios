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

import UIKit

/**
 View controller for editing a workspace.
 */
@objc(BKYWorkbenchViewController)
public class WorkbenchViewController: UIViewController {

  /// Defines possible UI states that the view controller may be in
  public struct UIState : OptionSetType {
    private static let Default = UIState(rawValue: 0)
    private static let TrashCanOpen = UIState(value: Value.TrashCanOpen)
    private static let TrashCanHighlighted = UIState(value: Value.TrashCanHighlighted)
    private static let CategoryOpen = UIState(value: Value.CategoryOpen)
    private static let EditingTextField = UIState(value: Value.EditingTextField)
    private static let DraggingBlock = UIState(value: Value.DraggingBlock)
    private static let PresentingPopover = UIState(value: Value.PresentingPopover)

    public enum Value: Int {
      case TrashCanOpen = 0,
        TrashCanHighlighted,
        CategoryOpen,
        EditingTextField,
        DraggingBlock,
        PresentingPopover
    }
    public let rawValue : Int
    public init(rawValue:Int) {
      self.rawValue = rawValue
    }
    public init(value: Value) {
      self.init(rawValue: 1 << value.rawValue)
    }

    public func intersectsWith(other: UIState) -> Bool {
      return intersect(other) != .Default
    }
  }

  // MARK: - Properties

  /// The main workspace view
  @IBOutlet public var workspaceView: WorkspaceView! {
    didSet {
      oldValue?.delegate = nil
      workspaceView?.delegate = self
    }
  }

  // The toolbox view
  @IBOutlet public var toolboxView: ToolboxView? {
    didSet {
      // We need to listen for when block views are added/removed from the block list
      // so we can attach pan gesture recognizers to those blocks (for dragging them onto
      // the workspace)
      oldValue?.blockListView.delegate = nil
      toolboxView?.blockListView.delegate = self
    }
  }

  // Trash can view
  @IBOutlet public var trashCanView: UIButton?

  /// The workspace layout
  public var workspaceLayout: WorkspaceLayout?
  /// The underlying toolbox
  public var toolbox: Toolbox?
  /// Flag for enabling trash can functionality
  public var enableTrashCan: Bool = true {
    didSet {
      setTrashCanButtonVisible(self.enableTrashCan)

      if !enableTrashCan {
        // Hide trash can folder
        setTrashCanFolderVisible(false)
      }
    }
  }

  /// Controls logic for dragging blocks around in the workspace
  private var _dragger = Dragger()
  /// Controller for managing the trash can workspace
  private var _trashCanViewController = TrashCanViewController()
  /// Flag indicating if the `self._trashCanViewController` is being shown
  private var _trashCanVisible: Bool = false
  /// The current state of the UI
  private var _state = UIState.Default

  // MARK: - Initializers

  public convenience init() {
    self.init(nibName: nil, bundle: nil)
  }

  public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    // Register for keyboard notifications
    NSNotificationCenter.defaultCenter().addObserver(self,
      selector: "keyboardWillShowNotification:", name: UIKeyboardWillShowNotification, object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self,
      selector: "keyboardWillHideNotification:", name: UIKeyboardWillHideNotification, object: nil)
  }

  deinit {
    // Unregister all notifications
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }

  // MARK: - Super

  public override func loadView() {
    super.loadView()

    self.view.backgroundColor = UIColor.whiteColor()
    self.view.autoresizesSubviews = true
    self.view.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]

    // Create views if ones weren't supplied by a xib file
    let toolboxView = ToolboxView()
    self.toolboxView = toolboxView

    workspaceView = WorkspaceView()
    workspaceView.scrollView.panGestureRecognizer.addTarget(self, action: "didPanWorkspaceView:")
    let tapGesture = UITapGestureRecognizer(target: self, action: "didTapWorkspaceView:")
    workspaceView.scrollView.addGestureRecognizer(tapGesture)
    workspaceView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)

    let trashCanView = UIButton(type: .Custom)
    trashCanView.addTarget(self, action: "didTapTrashCan:", forControlEvents: .TouchUpInside)
    trashCanView.contentMode = .ScaleAspectFit
    if let image =
      ImageLoader.loadImage(named: "trash_can", forClass: WorkbenchViewController.self)
    {
      trashCanView.setImage(image, forState: .Normal)
      trashCanView.sizeToFit()
    }
    self.trashCanView = trashCanView

    // Set up auto-layout constraints
    let views = [
      "toolboxView": toolboxView,
      "workspaceView": workspaceView,
      "trashCanView": trashCanView,
    ]
    let metrics = ["toolboxWidth": ToolboxView.CategoryListViewWidth]
    let constraints = [
      "H:|[toolboxView]",
      "V:|[toolboxView]|",
      "H:|-toolboxWidth-[workspaceView]|",
      "V:|[workspaceView]|",
      "H:[trashCanView(50)]-25-|",
      "V:[trashCanView(50)]-25-|",
    ]

    self.view.bky_addSubviews(Array(views.values))
    self.view.bky_addVisualFormatConstraints(constraints, metrics: metrics, views: views)

    self.view.sendSubviewToBack(workspaceView)
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    // We need to listen for when block views are added/removed from the block list
    // so we can attach pan gesture recognizers to those blocks (for dragging them onto
    // the workspace)
    self._trashCanViewController.workspaceView.delegate = self

    // Hide/show trash can
    setTrashCanButtonVisible(self.enableTrashCan)
  }

  // MARK: - Public

  private dynamic func didPanWorkspaceView(gesture: UIPanGestureRecognizer) {
    resetUIState()
  }

  private dynamic func didTapWorkspaceView(gesture: UITapGestureRecognizer) {
    resetUIState()
  }

  /**
  Refreshes the UI based on the current version of `self.workspace` and `self.toolbox`.
  */
  public func refreshView() {
    workspaceView.layout = workspaceLayout
    workspaceView.refreshView()

    toolboxView?.toolbox = toolbox
    toolboxView?.refreshView()

    resetUIState()
  }
}

// MARK: - State Handling

extension WorkbenchViewController {
  // MARK: - Private

  /**
   Appends a state to the current state of the UI. This call should be matched a future call to
   removeUIState(state:animated:).

   - Parameter state: The state to append to `self.state`.
   - Parameter animated: True if changes in UI state should be animated. False, if not.
   */
  private func addUIStateValue(stateValue: UIState.Value, animated: Bool = true) {
    let state = UIState(value: stateValue)
    let newState: UIState

    // When adding a new state, check for compatability with existing states.

    switch stateValue {
    case .TrashCanHighlighted:
      // This state can co-exist with anything, simply add it to the current state
      newState = _state.union(state)
    case .EditingTextField, .PresentingPopover:
      // Allow .EditingTextField and .PresentingPopover to co-exist with each other, but nothing
      // else
      newState = _state.union(state).intersect([.PresentingPopover, .EditingTextField])
    case .CategoryOpen, .TrashCanOpen, .DraggingBlock:
      // Don't allow these states to co-exist with others. Simply set the new state to this state
      // value.
      newState = UIState(value: stateValue)
    }

    _setUIState(newState, animated: animated)
  }

  /**
   Removes a state to the current state of the UI. This call should have matched a previous call to
   addUIState(state:animated:).

   - Parameter state: The state to remove from `self.state`.
   - Parameter animated: True if changes in UI state should be animated. False, if not.
   */
  private func removeUIStateValue(stateValue: UIState.Value, animated: Bool = true) {
    // When subtracting a state value, there is no need to check for compatability.
    // Simply set the new state, minus the given state value.
    let newState = _state.subtract(UIState(value: stateValue))
    _setUIState(newState, animated: animated)
  }

  /**
   Resets to the UI back to its default state.

   - Parameter animated: True if changes in UI state should be animated. False, if not.
   */
  private func resetUIState(animated: Bool = true) {
    _setUIState(.Default, animated: animated)
  }

  /**
   Sets the UI based on a given state.

   - Parameter state: The state to set the UI
   - Parameter animated: True if changes in UI state should be animated. False, if not.
   - Note: This method should not be called directly. Instead, you should call addUIState(...),
   removeUIState(...), or resetUIState(...).
   */
  private func _setUIState(state: UIState, animated: Bool = true) {
    if _state == state {
      return
    }

    _state = state

    setTrashCanFolderVisible(state.intersectsWith(.TrashCanOpen))

    setTrashCanButtonHighlight(state.intersectsWith(.TrashCanHighlighted))

    if !state.intersectsWith(.CategoryOpen) {
      // Hide the toolbox category
      toolboxView?.hideCategory(animated: animated)
    }

    if !state.intersectsWith(.EditingTextField) {
      // Force all child text fields to end editing (which essentially dismisses the keyboard if
      // it's currently visible)
      self.view.endEditing(true)
    }

    if !state.intersectsWith(.PresentingPopover) && self.presentedViewController != nil {
      self.dismissViewControllerAnimated(animated, completion: nil)
    }
  }
}

// MARK: - Trash Can

extension WorkbenchViewController {
  // MARK: - Public

  /**
   Event that is fired when the trash can is tapped on.

   - Parameter sender: The trash can button that sent the event.
   */
  public func didTapTrashCan(sender: UIButton) {
    // Toggle trash can visibility
    if !_trashCanVisible {
      addUIStateValue(.TrashCanOpen)
    } else {
      removeUIStateValue(.TrashCanOpen)
    }
  }

  // MARK: - Private

  private func setTrashCanButtonVisible(visible: Bool) {
    trashCanView?.hidden = !visible
  }

  private func setTrashCanButtonHighlight(open: Bool) {
    // For now, simply change the opacity of the trash can to indicate if it's open
    trashCanView?.layer.opacity = open ? 0.7 : 1.0
  }

  private func setTrashCanFolderVisible(visible: Bool) {
    if _trashCanVisible == visible && trashCanView != nil {
      return
    }

    if visible {
      addChildViewController(_trashCanViewController)

      var views: [String: UIView] = [
        "trashCanFolderView": _trashCanViewController.workspaceView,
        "trashCanView": trashCanView!
      ]
      var constraints = [
        "V:[trashCanFolderView(300)]|"
      ]

      if let toolboxView = self.toolboxView {
        // Horizontally constrain the left edge to where the toolbox ends
        views["toolboxView"] = toolboxView
        constraints.append("H:[toolboxView]-[trashCanFolderView]-[trashCanView]")
      } else {
        // Horizontally constrain the left edge to its parent view
        constraints.append("H:|-[trashCanFolderView]-[trashCanView]")
      }

      self.view.bky_addSubviews([_trashCanViewController.view])
      self.view.bky_addVisualFormatConstraints(constraints, metrics: nil, views: views)
      _trashCanVisible = true
    } else {
      _trashCanViewController.view.removeConstraints(_trashCanViewController.view.constraints)
      _trashCanViewController.view.removeFromSuperview()
      _trashCanViewController.removeFromParentViewController()
      _trashCanVisible = false
    }
  }
}

// MARK: - WorkspaceViewDelegate

extension WorkbenchViewController: WorkspaceViewDelegate {
  public func workspaceView(workspaceView: WorkspaceView, didAddBlockView blockView: BlockView) {
    if workspaceView == self.workspaceView {
      addGestureTrackingForBlockView(blockView)
    } else if workspaceView == toolboxView?.blockListView ||
        workspaceView == _trashCanViewController.workspaceView
    {
      addGestureTrackingForWorkspaceFolderBlockView(blockView)
    }

    blockView.delegate = self
  }

  public func workspaceView(
    workspaceView: WorkspaceView, willRemoveBlockView blockView: BlockView)
  {
    if workspaceView == self.workspaceView {
      removeGestureTrackingForBlockView(blockView)
    } else if workspaceView == toolboxView?.blockListView ||
        workspaceView == _trashCanViewController.workspaceView
    {
      removeGestureTrackingForWorkspaceFolderBlockView(blockView)
    }

    blockView.delegate = nil
  }
}

// MARK: - Toolbox Gesture Tracking

extension WorkbenchViewController {
  /**
   Adds a pan gesture recognizer to a block view that is part of a workspace "folder" (ie. trash
   can or toolbox).

   - Parameter blockView: A given block view.
   */
  private func addGestureTrackingForWorkspaceFolderBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()

    let panGesture = UIPanGestureRecognizer(
      target: self, action: "didRecognizeWorkspaceFolderPanGesture:")
    panGesture.maximumNumberOfTouches = 1
    blockView.addGestureRecognizer(panGesture)
  }

  /**
   Removes all gesture recognizers from a block view that is part of a workspace "folder" (ie. trash
   can or toolbox).

   - Parameter blockView: A given block view.
   */
  private func removeGestureTrackingForWorkspaceFolderBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()
  }

  /**
   Pan gesture event handler for a block view inside `self.toolboxView`.
  */
  private dynamic func didRecognizeWorkspaceFolderPanGesture(gesture: UIPanGestureRecognizer) {
    guard let aBlockView = gesture.view as? BlockView else {
      return
    }

    if gesture.state == UIGestureRecognizerState.Began {
      // The block the user is dragging out of the toolbox/trash may be a child of a large nested
      // block. We want to do a deep copy on the root block (not just the current block).
      let rootBlockLayout = aBlockView.blockLayout?.rootBlockGroupLayout?.blockLayouts[0]
      let rootBlockView: BlockView! =
        ViewManager.sharedInstance.cachedBlockViewForLayout(rootBlockLayout!)

      // Copy the block view into the workspace view
      let newBlockView: BlockView
      do {
        newBlockView = try workspaceView.copyBlockView(rootBlockView)
      } catch let error as NSError {
        bky_assertionFailure("Could not copy toolbox block view into workspace view: \(error)")
        return
      }

      // Transfer this gesture recognizer from the original block view to the new block view
      gesture.removeTarget(self, action: "didRecognizeWorkspaceFolderPanGesture:")
      aBlockView.removeGestureRecognizer(gesture)
      gesture.addTarget(self, action: "didRecognizeWorkspacePanGesture:")
      newBlockView.addGestureRecognizer(gesture)

      // Start the first step of dragging the block layout
      let touchPosition = workspaceView.workspacePositionFromGestureTouchLocation(gesture)
      _dragger.startDraggingBlockLayout(newBlockView.blockLayout!, touchPosition: touchPosition)

      if rootBlockView.blockLayout?.workspaceLayout ==
        _trashCanViewController.workspaceView.workspaceLayout
      {
        // Remove this block view from the trash can
        _trashCanViewController.workspace?.removeBlockTree(rootBlockView.blockLayout!.block)
      } else {
        // Re-add gesture tracking to the original block view for future drags
        addGestureTrackingForWorkspaceFolderBlockView(aBlockView)
      }

      addUIStateValue(.DraggingBlock)
    }
  }
}

// MARK: - Workspace Gesture Tracking

extension WorkbenchViewController {
  /**
   Adds pan and tap gesture recognizers to a block view.

   - Parameter blockView: A given block view.
   */
  private func addGestureTrackingForBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()

    let panGesture =
      UIPanGestureRecognizer(target: self, action: "didRecognizeWorkspacePanGesture:")
    panGesture.maximumNumberOfTouches = 1
    blockView.addGestureRecognizer(panGesture)

    let tapGesture =
      UITapGestureRecognizer(target: self, action: "didRecognizeWorkspaceTapGesture:")
    blockView.addGestureRecognizer(tapGesture)
  }

  /**
   Removes all gesture recognizers and any on-going gesture data from a block view.

   - Parameter blockView: A given block view.
   */
  private func removeGestureTrackingForBlockView(blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()

    if let blockLayout = blockView.blockLayout {
      _dragger.clearGestureDataForBlockLayout(blockLayout)
    }
  }

  /**
   Pan gesture event handler for a block view inside `self.workspaceView`.
   */
  private dynamic func didRecognizeWorkspacePanGesture(gesture: UIPanGestureRecognizer) {
    guard let blockView = gesture.view as? BlockView,
      blockLayout = blockView.blockLayout else {
        return
    }

    let touchPosition = self.workspaceView.workspacePositionFromGestureTouchLocation(gesture)
    let touchingTrashCan = trashCanView != nil && !trashCanView!.hidden &&
      CGRectContainsPoint(trashCanView!.bounds, gesture.locationInView(trashCanView!))

    // TODO:(vicng) Handle screen rotations (either lock the screen during drags or stop any
    // on-going drags when the screen is rotated).

    if gesture.state == .Began {
      addUIStateValue(.DraggingBlock)
      _dragger.startDraggingBlockLayout(blockLayout, touchPosition: touchPosition)
    } else if gesture.state == .Changed || gesture.state == .Cancelled || gesture.state == .Ended {
      addUIStateValue(.DraggingBlock)
      _dragger.continueDraggingBlockLayout(blockLayout, touchPosition: touchPosition)

      if touchingTrashCan {
        addUIStateValue(.TrashCanHighlighted)
      }
    }

    if gesture.state == .Cancelled || gesture.state == .Ended || gesture.state == .Failed {
      if touchingTrashCan {
        // This block is being "deleted" -- cancel the drag and copy the block into the trash can
        _dragger.clearGestureDataForBlockLayout(blockLayout)

        do {
          try _trashCanViewController.workspace?.copyBlockTree(blockLayout.block)
          blockLayout.workspaceLayout.workspace.removeBlockTree(blockLayout.block)
        } catch let error as NSError {
          bky_assertionFailure("Could not copy block to trash can: \(error)")
        }
      } else {
        _dragger.finishDraggingBlockLayout(blockLayout)
      }

      // HACK: Re-add gesture tracking for the block view, as there is a problem re-recognizing
      // them when dragging multiple blocks simultaneously
      addGestureTrackingForBlockView(blockView)

      // Update the UI state
      removeUIStateValue(.DraggingBlock)
      removeUIStateValue(.TrashCanHighlighted)
    }
  }

  /**
   Tap gesture event handler for a block view inside `self.workspaceView`.
   */
  private dynamic func didRecognizeWorkspaceTapGesture(gesture: UITapGestureRecognizer) {
    guard let blockView = gesture.view as? BlockView else {
      return
    }

    // TODO:(vicng) Set this block as "selected" within the workspace
  }
}

// MARK: - UIKeyboard notifications

extension WorkbenchViewController {
  private dynamic func keyboardWillShowNotification(notification: NSNotification) {
    addUIStateValue(.EditingTextField)

    if let keyboardEndSize = notification.userInfo?[UIKeyboardFrameEndUserInfoKey]?.CGRectValue {
      // Increase the canvas' bottom padding so the text field isn't hidden by the keyboard (when
      // the user edits a text field, it is automatically scrolled into view by the system as long
      // as there is enough scrolling space in its container scroll view).
      // Note: workspaceView.scrollView.scrollIndicatorInsets isn't changed here since there
      // doesn't seem to be a reliable way to check when the keyboard has been split or not (which
      // would makes it hard for us to figure out where to place the scroll indicators)
      let contentInsets = UIEdgeInsetsMake(0, 0, keyboardEndSize.height, 0)
      workspaceView.scrollView.contentInset = contentInsets
    }
  }

  private dynamic func keyboardWillHideNotification(notification: NSNotification) {
    removeUIStateValue(.EditingTextField)

    // Reset the canvas padding of the scroll view (when the keyboard was initially shown)
    let contentInsets = UIEdgeInsetsZero
    workspaceView.scrollView.contentInset = contentInsets
  }
}

// MARK: - BlockViewDelegate

extension WorkbenchViewController: BlockViewDelegate {
  public func blockView(blockView: BlockView,
    requestedToPresentPopoverViewController viewController: UIViewController,
    fromView: UIView) -> Bool
  {
    guard !workspaceView.scrollView.dragging && !workspaceView.scrollView.decelerating &&
      !(self.presentedViewController?.isBeingPresented() ?? false) else
    {
      // Don't present anything if the scroll view is being dragged or is decelerating, or if
      // another view controller is being presented
      return false
    }

    if self.presentedViewController != nil {
      // Dismiss any other view controller that's being presented
      self.dismissViewControllerAnimated(true, completion: nil)
    }

    addUIStateValue(.PresentingPopover)

    viewController.modalPresentationStyle = .Popover
    viewController.popoverPresentationController?.sourceView = self.view
    viewController.popoverPresentationController?.sourceRect =
      self.view.convertRect(fromView.frame, fromView: fromView.superview)
    viewController.popoverPresentationController?.permittedArrowDirections = .Any
    viewController.popoverPresentationController?.delegate = self
    viewController.popoverPresentationController?.passthroughViews = [self.view]

    presentViewController(viewController, animated: true, completion: nil)

    return true
  }
}

extension WorkbenchViewController: UIPopoverPresentationControllerDelegate {
  public func adaptivePresentationStyleForPresentationController(
    controller: UIPresentationController) -> UIModalPresentationStyle
  {
    // Force this view controller to always show up in a popover
    return UIModalPresentationStyle.None
  }

  public func popoverPresentationControllerDidDismissPopover(
    popoverPresentationController: UIPopoverPresentationController)
  {
    removeUIStateValue(.PresentingPopover)
  }

  public override func dismissViewControllerAnimated(flag: Bool, completion: (() -> Void)?) {
    super.dismissViewControllerAnimated(flag, completion: completion)

    removeUIStateValue(.PresentingPopover)
  }
}
