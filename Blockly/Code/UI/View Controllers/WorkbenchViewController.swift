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

 TODO:(#61) Refactor this view controller into smaller pieces.
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
  public private(set) var workspaceView: WorkspaceView! {
    didSet {
      oldValue?.delegate = nil
      workspaceView?.delegate = self
    }
  }

  // Button for viewing the trash can
  public private(set) var trashCanButton: TrashCanButton?

  // The toolbox category view
  public private(set) var toolboxCategoryView: ToolboxCategoryView? {
    didSet {
      // We need to listen for when block views are added/removed from the block list
      // so we can attach pan gesture recognizers to those blocks (for dragging them onto
      // the workspace)
      oldValue?.delegate = nil
      toolboxCategoryView?.delegate = self
    }
  }

  /// The layout engine to use for all views
  public private(set) final var engine: LayoutEngine!
  /// The layout builder to create layout hierarchies
  public private(set) final var layoutBuilder: LayoutBuilder!
  /// The workspace that has been loaded via `loadWorkspace(:)`
  public var workspace: Workspace? {
    return _workspaceLayout?.workspace
  }
  /// The toolbox that has been loaded via `loadToolbox(:)`
  public var toolbox: Toolbox? {
    return _toolboxLayout?.toolbox
  }
  /// The underlying workspace layout
  private var _workspaceLayout: WorkspaceLayout?
  /// The underlying toolbox layout
  private var _toolboxLayout: ToolboxLayout?

  /// Flag for enabling trash can functionality
  public var enableTrashCan: Bool = true {
    didSet {
      setTrashCanButtonVisible(self.enableTrashCan)

      if !enableTrashCan {
        // Hide trash can folder
        removeUIStateValue(.TrashCanOpen, animated: false)
      }
    }
  }

  /// Controls logic for dragging blocks around in the workspace
  private var _dragger = Dragger()
  /// Controller for listing the toolbox categories
  private var _toolboxCategoryListViewController: ToolboxCategoryListViewController!
  /// Controller for managing the trash can workspace
  private var _trashCanViewController: TrashCanViewController!
  /// Flag indicating if the `self._trashCanViewController` is being shown
  private var _trashCanVisible: Bool = false
  /// The current state of the UI
  private var _state = UIState.Default

  // MARK: - Initializers

  public init(engine: LayoutEngine, layoutBuilder: LayoutBuilder) {
    self.engine = engine
    self.layoutBuilder = layoutBuilder
    super.init(nibName: nil, bundle: nil)
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    // TODO:(#52) Support the ability to create view controllers from XIBs.
    // Note: Both the layoutEngine and layoutBuilder need to be initialized somehow.
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    // Set up trash can folder view controller
    _trashCanViewController = TrashCanViewController(
      engine: self.engine, layoutBuilder: layoutBuilder, layoutDirection: .Horizontal)
    addChildViewController(_trashCanViewController)

    // Set up toolbox category list view controller
    _toolboxCategoryListViewController = ToolboxCategoryListViewController()
    _toolboxCategoryListViewController.delegate = self
    addChildViewController(_toolboxCategoryListViewController)

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

    self.view.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
    self.view.autoresizesSubviews = true
    self.view.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]

    // Create toolbox views
    let toolboxCategoryView = ToolboxCategoryView()
    self.toolboxCategoryView = toolboxCategoryView

    // Create main workspace view
    workspaceView = WorkspaceView()
    workspaceView.scrollView.panGestureRecognizer.addTarget(self, action: "didPanWorkspaceView:")
    let tapGesture = UITapGestureRecognizer(target: self, action: "didTapWorkspaceView:")
    workspaceView.scrollView.addGestureRecognizer(tapGesture)
    workspaceView.backgroundColor = UIColor.clearColor()

    // Create trash can button
    let trashCanButton = TrashCanButton(imageNamed: "trash_can")
    trashCanButton.addTarget(self, action: "didTapTrashCan:", forControlEvents: .TouchUpInside)
    self.trashCanButton = trashCanButton

    // Set up auto-layout constraints
    let views: [String: UIView] = [
      "toolboxCategoriesListView": _toolboxCategoryListViewController.view,
      "toolboxCategoryView": toolboxCategoryView,
      "workspaceView": workspaceView,
      "trashCanButton": trashCanButton,
      "trashCanFolderView": _trashCanViewController.workspaceView,
    ]
    let constraints = [
      // Position the toolbox category list along the leading margin, and let the workspace view
      // fill the rest of the space
      "H:|[toolboxCategoriesListView(35)][workspaceView]|",
      "V:|[toolboxCategoriesListView]|",
      "V:|[workspaceView]|",
      // Position the toolbox category view beside the category list
      "H:[toolboxCategoriesListView][toolboxCategoryView]",
      "V:|[toolboxCategoryView]|",
      // Position the trash can button along the bottom-trailing margin
      "H:[trashCanButton]-25-|",
      "V:[trashCanButton]-25-|",
      // Position the trash can folder view on the bottom of the view, between the toolbox category
      // list and trash can button
      "H:[toolboxCategoriesListView]-[trashCanFolderView]-[trashCanButton]",
      "V:[trashCanFolderView]|",
    ]
    self.view.bky_addSubviews(Array(views.values))
    self.view.bky_addVisualFormatConstraints(constraints, metrics: nil, views: views)

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

    refreshView()
  }

  // MARK: - Public

  /**
  Automatically creates a `WorkspaceLayout` for a given `Workspace` (using both the `self.engine`
  and `self.layoutBuilder` instances) and loads it into the view controller.

   - Parameter workspace: The `Workspace` to load
   - Throws:
   `BlocklyError`: Thrown if an associated `WorkspaceLayout` could not be created for the workspace.
   */
  public func loadWorkspace(workspace: Workspace) throws {
    guard let layoutEngine = self.engine,
      let layoutBuilder = self.layoutBuilder else
    {
      throw BlocklyError(.IllegalState,
        "`self.layoutEngine` and `self.layoutBuilder` need to be set before loading the workspace")
    }

    // Create a layout for the workspace, which is required for viewing the workspace
    let workspaceLayout = try WorkspaceLayout(workspace: workspace, engine: layoutEngine,
      layoutBuilder: layoutBuilder)
    _workspaceLayout = workspaceLayout

    refreshView()
  }

  /**
   Automatically creates a `ToolboxLayout` for a given `Toolbox` (using both the `self.engine`
   and `self.layoutBuilder` instances) and loads it into the view controller.

   - Parameter toolbox: The `Toolbox` to load
   - Throws:
   `BlocklyError`: Thrown if an associated `ToolboxLayout` could not be created for the toolbox.
   */
  public func loadToolbox(toolbox: Toolbox) throws {
    guard let layoutEngine = self.engine,
      let layoutBuilder = self.layoutBuilder else
    {
      throw BlocklyError(.IllegalState,
        "`self.layoutEngine` and `self.layoutBuilder` need to be set before loading the toolbox")
    }

    let toolboxLayout = ToolboxLayout(toolbox: toolbox, layoutDirection: .Vertical,
      engine: layoutEngine, layoutBuilder: layoutBuilder)
    _toolboxLayout = toolboxLayout

    refreshView()
  }

  /**
   Refreshes the UI based on the current version of `self.workspace` and `self.toolbox`.
   */
  public func refreshView() {
    workspaceView?.layout = _workspaceLayout
    workspaceView?.refreshView()

    _toolboxCategoryListViewController?.toolboxLayout = _toolboxLayout
    _toolboxCategoryListViewController?.refreshView()

    resetUIState()
  }

  // MARK: - Private

  private dynamic func didPanWorkspaceView(gesture: UIPanGestureRecognizer) {
    resetUIState()
  }

  private dynamic func didTapWorkspaceView(gesture: UITapGestureRecognizer) {
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
    case .DraggingBlock:
      // Dragging a block can only co-exist with highlighting the trash can
      newState = _state.union(state).intersect([.DraggingBlock, .TrashCanHighlighted])
    case .TrashCanHighlighted:
      // This state can co-exist with anything, simply add it to the current state
      newState = _state.union(state)
    case .EditingTextField:
      // Allow .EditingTextField to co-exist with .PresentingPopover and .CategoryOpen, but nothing
      // else
      newState = _state.union(state).intersect(
        [.PresentingPopover, .EditingTextField, .CategoryOpen])
    case .PresentingPopover:
      // If .CategoryOpen already existed, continue to let it exist (as users may want to modify
      // blocks from inside the toolbox). Disallow everything else.
      newState = _state.union(state).intersect([.PresentingPopover, .CategoryOpen])
    case .CategoryOpen, .TrashCanOpen:
      // Whenever these states are added, clear out all existing state.
      newState = UIState(value: stateValue)
    }

    refreshUIState(newState, animated: animated)
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
    refreshUIState(newState, animated: animated)
  }

  /**
   Resets the UI back to its default state.

   - Parameter animated: True if changes in UI state should be animated. False, if not.
   */
  private func resetUIState(animated: Bool = true) {
    refreshUIState(.Default, animated: animated)
  }

  /**
   Refreshes the UI based on a given state.

   - Parameter state: The state to set the UI
   - Parameter animated: True if changes in UI state should be animated. False, if not.
   - Note: This method should not be called directly. Instead, you should call addUIState(...),
   removeUIState(...), or resetUIState(...).
   */
  private func refreshUIState(state: UIState, animated: Bool = true) {
    _state = state

    setTrashCanFolderVisible(state.intersectsWith(.TrashCanOpen), animated: animated)

    trashCanButton?.setHighlighted(state.intersectsWith(.TrashCanHighlighted), animated: animated)

    if let selectedCategory = _toolboxCategoryListViewController.selectedCategory
      where state.intersectsWith(.CategoryOpen)
    {
      // Show the toolbox category
      toolboxCategoryView?.showCategory(selectedCategory, animated: true)
    } else {
      // Hide the toolbox category
      toolboxCategoryView?.hideCategory(animated: animated)
      _toolboxCategoryListViewController.selectedCategory = nil
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
    trashCanButton?.hidden = !visible
  }

  private func setTrashCanFolderVisible(visible: Bool, animated: Bool) {
    if _trashCanVisible == visible && trashCanButton != nil {
      return
    }

    if visible {
      _trashCanViewController.setWorkspaceViewHeight(300, animated: animated)
      _trashCanVisible = true
    } else {
      _trashCanViewController.setWorkspaceViewHeight(0, animated: animated)
      _trashCanVisible = false
    }
  }

  private func isGestureTouchingTrashCan(gesture: UIGestureRecognizer) -> Bool {
    if let trashCanButton = self.trashCanButton where !trashCanButton.hidden {
      // Define the trash area as being the bottom-right (or bottom-left in RTL) of the workspace
      // view
      if UIApplication.sharedApplication().userInterfaceLayoutDirection == .RightToLeft {
        let trashArea = CGRectMake(0, trashCanButton.frame.origin.y,
          trashCanButton.frame.size.width,
          self.view.bounds.size.height - trashCanButton.frame.origin.y)
        return CGRectContainsPoint(trashArea, gesture.locationInView(self.view))
      } else {
        let trashArea = CGRectMake(trashCanButton.frame.origin.x, trashCanButton.frame.origin.y,
          self.view.bounds.size.width - trashCanButton.frame.origin.x,
          self.view.bounds.size.height - trashCanButton.frame.origin.y)
        return CGRectContainsPoint(trashArea, gesture.locationInView(self.view))
      }
    }

    return false
  }
}

// MARK: - WorkspaceViewDelegate

extension WorkbenchViewController: WorkspaceViewDelegate {
  public func workspaceView(workspaceView: WorkspaceView, didAddBlockView blockView: BlockView) {
    if workspaceView == self.workspaceView {
      addGestureTrackingForBlockView(blockView)
    } else if workspaceView == toolboxCategoryView ||
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
    } else if workspaceView == toolboxCategoryView ||
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
        ViewManager.sharedInstance.findBlockViewForLayout(rootBlockLayout!)

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
    let touchingTrashCan = isGestureTouchingTrashCan(gesture)

    // TODO:(#44) Handle screen rotations (either lock the screen during drags or stop any
    // on-going drags when the screen is rotated).

    if gesture.state == .Began {
      addUIStateValue(.DraggingBlock)
      _dragger.startDraggingBlockLayout(blockLayout, touchPosition: touchPosition)
    } else if gesture.state == .Changed || gesture.state == .Cancelled || gesture.state == .Ended {
      addUIStateValue(.DraggingBlock)
      _dragger.continueDraggingBlockLayout(blockLayout, touchPosition: touchPosition)

      if touchingTrashCan {
        addUIStateValue(.TrashCanHighlighted)
      } else {
        removeUIStateValue(.TrashCanHighlighted)
      }
    }

    if gesture.state == .Cancelled || gesture.state == .Ended || gesture.state == .Failed {
      if touchingTrashCan {
        // This block is being "deleted" -- cancel the drag and copy the block into the trash can
        _dragger.clearGestureDataForBlockLayout(blockLayout)

        do {
          try _trashCanViewController.workspace?.copyBlockTree(blockLayout.block)
          blockLayout.workspaceLayout?.workspace.removeBlockTree(blockLayout.block)
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

// MARK: - BlockViewDelegate implementation

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

    presentViewController(viewController, animated: true, completion: nil)

    return true
  }
}

// MARK: - UIPopoverPresentationControllerDelegate implementation

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

// MARK: - ToolboxCategoryListViewControllerDelegate implementation

extension WorkbenchViewController: ToolboxCategoryListViewControllerDelegate {
  public func toolboxCategoryListViewController(
    controller: ToolboxCategoryListViewController, didSelectCategory category: Toolbox.Category)
  {
    addUIStateValue(.CategoryOpen, animated: true)
  }

  public func toolboxCategoryListViewControllerDidDeselectCategory(
    controller: ToolboxCategoryListViewController)
  {
    removeUIStateValue(.CategoryOpen, animated: true)
  }
}
