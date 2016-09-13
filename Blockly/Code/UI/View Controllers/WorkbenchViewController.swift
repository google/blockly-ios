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
 Delegate for events that occur on `WorkbenchViewController`.
 */
public protocol WorkbenchViewControllerDelegate: class {
  /**
   Event that is called when a `WorkbenchViewController` updates its `state`.
   */
  func workbenchViewController(workbenchViewController: WorkbenchViewController,
                               didUpdateState state: WorkbenchViewController.UIState)
}

/**
 View controller for editing a workspace.

 TODO:(#61) Refactor parts of this code into `WorkspaceViewController`.
 */
@objc(BKYWorkbenchViewController)
public class WorkbenchViewController: UIViewController {

  // MARK: - Style Enum

  /// Defines the style of the workbench
  public enum Style {
    /// Style where the toolbox is positioned vertically, the trash can is located in the
    /// bottom-right corner, and the trash folder flies out from the bottom
    case Default,
    /// Style where the toolbox is positioned horizontally on the bottom, the trash can is
    /// located in the top-right corner, and the trash folder flies out from the trailing edge of the
    /// screen
      Alternate

    /// The `WorkspaceFlowLayout.LayoutDirection` to use for the trash folder
    private var trashLayoutDirection: WorkspaceFlowLayout.LayoutDirection {
      switch self {
      case Default, Alternate: return .Horizontal
      }
    }

    /// The `WorkspaceFlowLayout.LayoutDirection` to use for the toolbox category
    private var toolboxCategoryLayoutDirection: WorkspaceFlowLayout.LayoutDirection {
      switch self {
      case Default: return .Vertical
      case Alternate: return .Horizontal
      }
    }

    /// The `ToolboxCategoryListViewController.Orientation` to use for the toolbox
    private var toolboxOrientation: ToolboxCategoryListViewController.Orientation {
      switch self {
      case Default: return .Vertical
      case Alternate: return .Horizontal
      }
    }
  }

  // MARK: - UIState Struct

  /// Defines possible UI states that the view controller may be in
  public struct UIState : OptionSetType {
    public static let Default = UIState(value: .Default)
    public static let TrashCanOpen = UIState(value: .TrashCanOpen)
    public static let TrashCanHighlighted = UIState(value: .TrashCanHighlighted)
    public static let CategoryOpen = UIState(value: .CategoryOpen)
    public static let EditingTextField = UIState(value: .EditingTextField)
    public static let DraggingBlock = UIState(value: .DraggingBlock)
    public static let PresentingPopover = UIState(value: .PresentingPopover)
    public static let DidPanWorkspace = UIState(value: .DidPanWorkspace)
    public static let DidTapWorkspace = UIState(value: .DidTapWorkspace)

    public enum Value: Int {
      case Default = 1,
        TrashCanOpen,
        TrashCanHighlighted,
        CategoryOpen,
        EditingTextField,
        DraggingBlock,
        PresentingPopover,
        DidPanWorkspace,
        DidTapWorkspace
    }
    public let rawValue : Int
    public init(rawValue: Int) {
      self.rawValue = rawValue
    }
    public init(value: Value) {
      self.init(rawValue: 1 << value.rawValue)
    }

    public func intersectsWith(other: UIState) -> Bool {
      return intersect(other).rawValue != 0
    }
  }

  // MARK: - Properties

  /// The main workspace view controller
  public private(set) var workspaceViewController: WorkspaceViewController! {
    didSet {
      oldValue?.delegate = nil
      workspaceViewController?.delegate = self
    }
  }

  /// A convenience property to `workspaceViewController.workspaceView`
  private var workspaceView: WorkspaceView! {
    return workspaceViewController.workspaceView
  }

  // The trash can view
  public private(set) var trashCanView: TrashCanView?

  // The toolbox category view controller
  public private(set) var toolboxCategoryViewController: ToolboxCategoryViewController! {
    didSet {
      // We need to listen for when block views are added/removed from the block list
      // so we can attach pan gesture recognizers to those blocks (for dragging them onto
      // the workspace)
      oldValue?.delegate = nil
      toolboxCategoryViewController?.delegate = self
    }
  }

  /// The layout engine to use for all views
  public final let engine: LayoutEngine
  /// The layout builder to create layout hierarchies
  public final let layoutBuilder: LayoutBuilder
  /// The factory for creating views
  public final let viewFactory: ViewFactory

  /// The current style of workbench
  public final let style: Style
  /// The workspace that has been loaded via `loadWorkspace(:)`
  public var workspace: Workspace? {
    return _workspaceLayout?.workspace
  }
  /// The toolbox that has been loaded via `loadToolbox(:)`
  public var toolbox: Toolbox? {
    return _toolboxLayout?.toolbox
  }
  /// The main workspace layout coordinator
  private var _workspaceLayoutCoordinator: WorkspaceLayoutCoordinator? {
    didSet {
      _dragger.workspaceLayoutCoordinator = _workspaceLayoutCoordinator
    }
  }
  /// The underlying workspace layout
  private var _workspaceLayout: WorkspaceLayout? {
    return _workspaceLayoutCoordinator?.workspaceLayout
  }
  /// The underlying toolbox layout
  private var _toolboxLayout: ToolboxLayout?

  /// Flag for enabling trash can functionality
  public var enableTrashCan: Bool = true {
    didSet {
      setTrashCanViewVisible(enableTrashCan)

      if !enableTrashCan {
        // Hide trash can folder
        removeUIStateValue(.TrashCanOpen, animated: false)
      }
    }
  }

  /**
  Flag for whether the toolbox drawer should stay visible once it has been opened (`true`)
  or if it should automatically close itself when the user does something else (`false`).
  By default, this value is set to `false`.
  */
  public var toolboxDrawerStaysOpen: Bool = false

  /// The current state of the UI
  public private(set) var state = UIState.Default

  /// The delegate for events that occur in the workbench
  public weak var delegate: WorkbenchViewControllerDelegate?

  /// Controls logic for dragging blocks around in the workspace
  private let _dragger = Dragger()
  /// Controller for listing the toolbox categories
  private var _toolboxCategoryListViewController: ToolboxCategoryListViewController!
  /// Controller for managing the trash can workspace
  private var _trashCanViewController: TrashCanViewController!
  /// Flag indicating if the `self._trashCanViewController` is being shown
  private var _trashCanVisible: Bool = false
  /// Flag indicating if block highlighting is allowed
  private var _enableBlockHighlighting = true
  /// Flag indicating if blocks should be automatically scrolled into view when they are highlighted
  private var _enableScrollBlockIntoView = true

  // MARK: - Initializers

  /**
   Creates the workbench.

   - Parameter style: The `Style` to use for this laying out items in this view controller.
   - Parameter engine: [Optional] Value used for `self.layoutEngine`. If no value is specified, a
   new `LayoutEngine` is automatically created.
   - Parameter layoutBuilder: [Optional] Value used for `self.layoutBuilder`. If no value is
   specified, a new `LayoutBuilder` is automatically created.
   - Parameter layoutBuilder: [Optional] Value used for `self.viewFactory`. If no value is
   specified, a new `ViewFactory` is automatically created.
   */
  public init(style: Style, engine: LayoutEngine? = nil, layoutBuilder: LayoutBuilder? = nil,
              viewFactory: ViewFactory? = nil)
  {
    self.style = style
    self.engine = (engine ?? DefaultLayoutEngine())
    self.layoutBuilder = (layoutBuilder ?? LayoutBuilder(layoutFactory: DefaultLayoutFactory()))
    self.viewFactory = (viewFactory ?? ViewFactory())
    super.init(nibName: nil, bundle: nil)
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    // TODO:(#52) Support the ability to create view controllers from XIBs.
    // Note: Both the layoutEngine and layoutBuilder need to be initialized somehow.
    fatalError("Called unsupported initializer")
  }

  private func commonInit() {
    // Set up trash can folder view controller
    _trashCanViewController = TrashCanViewController(
      engine: engine, layoutBuilder: layoutBuilder, layoutDirection: style.trashLayoutDirection,
      viewFactory: viewFactory)
    _trashCanViewController.delegate = self
    addChildViewController(_trashCanViewController)

    // Set up toolbox category list view controller
    _toolboxCategoryListViewController = ToolboxCategoryListViewController(
      orientation: style.toolboxOrientation)
    _toolboxCategoryListViewController.delegate = self
    addChildViewController(_toolboxCategoryListViewController)

    // Register for keyboard notifications
    NSNotificationCenter.defaultCenter().addObserver(
      self, selector: #selector(keyboardWillShowNotification(_:)),
      name: UIKeyboardWillShowNotification, object: nil)
    NSNotificationCenter.defaultCenter().addObserver(
      self, selector: #selector(keyboardWillHideNotification(_:)),
      name: UIKeyboardWillHideNotification, object: nil)
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
    toolboxCategoryViewController = ToolboxCategoryViewController(viewFactory: viewFactory)
    addChildViewController(toolboxCategoryViewController)

    // Create main workspace view
    workspaceViewController = WorkspaceViewController(viewFactory: viewFactory)
    workspaceViewController.workspaceView.scrollView.panGestureRecognizer
      .addTarget(self, action: #selector(didPanWorkspaceView(_:)))
    let tapGesture =
      UITapGestureRecognizer(target: self, action: #selector(didTapWorkspaceView(_:)))
    workspaceViewController.workspaceView.scrollView.addGestureRecognizer(tapGesture)
    addChildViewController(workspaceViewController)

    // Create trash can button
    let trashCanView = TrashCanView(imageNamed: "trash_can")
    trashCanView.button
      .addTarget(self, action: #selector(didTapTrashCan(_:)), forControlEvents: .TouchUpInside)
    self.trashCanView = trashCanView

    // Set up auto-layout constraints
    let trashCanPadding = CGFloat(25)
    let views: [String: UIView] = [
      "toolboxCategoriesListView": _toolboxCategoryListViewController.view,
      "toolboxCategoryView": toolboxCategoryViewController.view,
      "workspaceView": workspaceViewController.view,
      "trashCanView": trashCanView,
      "trashCanFolderView": _trashCanViewController.view,
    ]
    let metrics = [
      "trashCanPadding": trashCanPadding,
    ]
    let constraints: [String]

    if style == .Alternate {
      // Position the button inside the trashCanView to be `(trashCanPadding, trashCanPadding)`
      // away from the top-trailing corner.
      trashCanView.setButtonPadding(
        top: trashCanPadding, leading: 0, bottom: 0, trailing: trashCanPadding)
      constraints = [
        // Position the toolbox category list along the bottom margin, and let the workspace view
        // fill the rest of the space
        "H:|[workspaceView]|",
        "H:|[toolboxCategoriesListView]|",
        "V:|[workspaceView][toolboxCategoriesListView]|",
        // Position the toolbox category view above the list view
        "H:|[toolboxCategoryView]|",
        "V:[toolboxCategoryView][toolboxCategoriesListView]",
        // Position the trash can button along the top-trailing margin
        "H:[trashCanView]|",
        "V:|[trashCanView]",
        // Position the trash can folder view on the trailing edge of the view, between the toolbox
        // category view and trash can button
        "H:[trashCanFolderView]|",
        "V:[trashCanView]-(trashCanPadding)-[trashCanFolderView]-[toolboxCategoryView]",
      ]
    } else {
      // Position the button inside the trashCanView to be `(trashCanPadding, trashCanPadding)`
      // away from the bottom-trailing corner.
      trashCanView.setButtonPadding(
        top: 0, leading: 0, bottom: trashCanPadding, trailing: trashCanPadding)
      constraints = [
        // Position the toolbox category list along the leading margin, and let the workspace view
        // fill the rest of the space
        "H:|[toolboxCategoriesListView][workspaceView]|",
        "V:|[toolboxCategoriesListView]|",
        "V:|[workspaceView]|",
        // Position the toolbox category view beside the category list
        "H:[toolboxCategoriesListView][toolboxCategoryView]",
        "V:|[toolboxCategoryView]|",
        // Position the trash can button along the bottom-trailing margin
        "H:[trashCanView]|",
        "V:[trashCanView]|",
        // Position the trash can folder view on the bottom of the view, between the toolbox
        // category view and trash can button
        "H:[toolboxCategoryView]-[trashCanFolderView]-(trashCanPadding)-[trashCanView]",
        "V:[trashCanFolderView]|",
      ]
    }

    self.view.bky_addSubviews(Array(views.values))
    self.view.bky_addVisualFormatConstraints(constraints, metrics: metrics, views: views)

    self.view.sendSubviewToBack(workspaceViewController.view)
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    // Hide/show trash can
    setTrashCanViewVisible(enableTrashCan)

    refreshView()
  }

  // MARK: - Public

  /**
   Automatically creates a `WorkspaceLayout` and `WorkspaceLayoutCoordinator` for a given workspace
   (using both the `self.engine` and `self.layoutBuilder` instances). The workspace is then
   rendered into the view controller.

   - Parameter workspace: The `Workspace` to load
   - Parameter connectionManager: A `ConnectionManager` to track connections in the workspace.
   If none is specified, a default one is automatically created.
   - Throws:
   `BlocklyError`: Thrown if an associated `WorkspaceLayout` could not be created for the workspace.
   */
  public func loadWorkspace(workspace: Workspace, connectionManager: ConnectionManager? = nil)
      throws {
    // Create a layout for the workspace, which is required for viewing the workspace
    let workspaceLayout = WorkspaceLayout(workspace: workspace, engine: engine)
    let aConnectionManager = connectionManager ?? ConnectionManager()
    _workspaceLayoutCoordinator =
      try WorkspaceLayoutCoordinator(workspaceLayout: workspaceLayout,
                                     layoutBuilder: layoutBuilder,
                                     connectionManager: aConnectionManager)

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
    let toolboxLayout = ToolboxLayout(
      toolbox: toolbox, engine: engine, layoutDirection: style.toolboxCategoryLayoutDirection,
      layoutBuilder: layoutBuilder)
    _toolboxLayout = toolboxLayout

    refreshView()
  }

  /**
   Refreshes the UI based on the current version of `self.workspace` and `self.toolbox`.
   */
  public func refreshView() {
    do {
      try workspaceViewController?.loadWorkspaceLayoutCoordinator(_workspaceLayoutCoordinator)
    } catch let error as NSError {
      bky_assertionFailure("Could not load workspace layout: \(error)")
    }

    _toolboxCategoryListViewController?.toolboxLayout = _toolboxLayout
    _toolboxCategoryListViewController?.refreshView()

    toolboxCategoryViewController?.toolboxLayout = _toolboxLayout

    resetUIState()
    updateWorkspaceCapacity()
  }

  // MARK: - Private

  private dynamic func didPanWorkspaceView(gesture: UIPanGestureRecognizer) {
    addUIStateValue(.DidPanWorkspace)
  }

  private dynamic func didTapWorkspaceView(gesture: UITapGestureRecognizer) {
    addUIStateValue(.DidTapWorkspace)
  }

  /**
   Updates the trash can and toolbox so the user may only interact with block groups that
   would not exceed the workspace's remaining capacity.
   */
  private func updateWorkspaceCapacity() {
    if let capacity = _workspaceLayout?.workspace.remainingCapacity {
      _trashCanViewController.workspace?.deactivateBlockTrees(forGroupsGreaterThan: capacity)
      _toolboxLayout?.toolbox.categories.forEach {
        $0.deactivateBlockTrees(forGroupsGreaterThan: capacity)
      }
    }
  }

  /**
   Copies a block view into this workspace view. This is done by:
   1) Creating a copy of the view's block
   2) Building its layout tree and setting its workspace position to be relative to where the given
   block view is currently on-screen.

   - Parameter blockView: The block view to copy into this workspace.
   - Returns: The new block view that was added to this workspace.
   - Throws:
   `BlocklyError`: Thrown if the block view could not be created.
   */
  public func copyBlockView(blockView: BlockView) throws -> BlockView
  {
    // TODO:(#57) When this operation is being used as part of a "copy-and-delete" operation, it's
    // causing a performance hit. Try to create an alternate method that performs an optimized
    // "cut" operation.

    guard let blockLayout = blockView.blockLayout else {
      throw BlocklyError(.LayoutNotFound, "No layout was set for the `blockView` parameter")
    }
    guard let workspaceLayoutCoordinator = _workspaceLayoutCoordinator else {
      throw BlocklyError(.LayoutNotFound,
        "No workspace layout coordinator has been set for `self._workspaceLayoutCoordinator`")
    }

    // Get the position of the block view relative to this view, and use that as
    // the position for the newly created block.
    // Note: This is done before creating a new block since adding a new block might change the
    // workspace's size, which would mess up this position calculation.
    let newWorkspacePosition = workspaceView.workspacePositionFromBlockView(blockView)

    // Create a deep copy of this block in this workspace (which will automatically create a layout
    // tree for the block)
    let newBlock = try workspaceLayoutCoordinator.copyBlockTree(blockLayout.block, editable: true)

    // Set its new workspace position
    newBlock.layout?.parentBlockGroupLayout?.moveToWorkspacePosition(newWorkspacePosition)

    // Because there are listeners on the layout hierarchy to update the corresponding view
    // hierarchy when layouts change, we just need to find the view that was automatically created.
    guard
      let newBlockLayout = newBlock.layout,
      let newBlockView = ViewManager.sharedInstance.findBlockViewForLayout(newBlockLayout) else
    {
      throw BlocklyError(.ViewNotFound, "View could not be located for the copied block")
    }

    return newBlockView
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
    var state = UIState(value: stateValue)
    let newState: UIState

    if toolboxDrawerStaysOpen && self.state.intersectsWith(.CategoryOpen) {
      // Always keep the .CategoryOpen state if it existed before
      state = state.union(.CategoryOpen)
    }

    // When adding a new state, check for compatibility with existing states.

    switch stateValue {
    case .DraggingBlock:
      // Dragging a block can only co-exist with highlighting the trash can
      newState = self.state.intersect([.TrashCanHighlighted]).union(state)
    case .TrashCanHighlighted:
      // This state can co-exist with anything, simply add it to the current state
      newState = self.state.union(state)
    case .EditingTextField:
      // Allow .EditingTextField to co-exist with .PresentingPopover and .CategoryOpen, but nothing
      // else
      newState = self.state.intersect([.PresentingPopover, .CategoryOpen]).union(state)
    case .PresentingPopover:
      // If .CategoryOpen already existed, continue to let it exist (as users may want to modify
      // blocks from inside the toolbox). Disallow everything else.
      newState = self.state.intersect([.CategoryOpen]).union(state)
    case .Default, .DidPanWorkspace, .DidTapWorkspace, .CategoryOpen, .TrashCanOpen:
      // Whenever these states are added, clear out all existing state
      newState = state
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
    // When subtracting a state value, there is no need to check for compatibility.
    // Simply set the new state, minus the given state value.
    let newState = self.state.subtract(UIState(value: stateValue))
    refreshUIState(newState, animated: animated)
  }

  /**
   Resets the UI back to its default state.

   - Parameter animated: True if changes in UI state should be animated. False, if not.
   */
  private func resetUIState(animated: Bool = true) {
    addUIStateValue(.Default, animated: animated)
  }

  /**
   Refreshes the UI based on a given state.

   - Parameter state: The state to set the UI
   - Parameter animated: True if changes in UI state should be animated. False, if not.
   - Note: This method should not be called directly. Instead, you should call addUIState(...),
   removeUIState(...), or resetUIState(...).
   */
  private func refreshUIState(state: UIState, animated: Bool = true) {
    self.state = state

    setTrashCanFolderVisible(state.intersectsWith(.TrashCanOpen), animated: animated)

    trashCanView?.setHighlighted(state.intersectsWith(.TrashCanHighlighted), animated: animated)

    if let selectedCategory = _toolboxCategoryListViewController.selectedCategory
      where state.intersectsWith(.CategoryOpen)
    {
      // Show the toolbox category
      toolboxCategoryViewController?.showCategory(selectedCategory, animated: true)
    } else {
      // Hide the toolbox category
      toolboxCategoryViewController?.hideCategory(animated: animated)
      _toolboxCategoryListViewController.selectedCategory = nil
    }

    if !state.intersectsWith(.EditingTextField) {
      // Force all child text fields to end editing (which essentially dismisses the keyboard if
      // it's currently visible)
      self.view.endEditing(true)
    }

    if !state.intersectsWith(.PresentingPopover) && self.presentedViewController != nil {
      dismissViewControllerAnimated(animated, completion: nil)
    }

    delegate?.workbenchViewController(self, didUpdateState: state)
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

  private func setTrashCanViewVisible(visible: Bool) {
    trashCanView?.hidden = !visible
  }

  private func setTrashCanFolderVisible(visible: Bool, animated: Bool) {
    if _trashCanVisible == visible && trashCanView != nil {
      return
    }

    let size: CGFloat = visible ? 300 : 0
    if style == .Default {
      _trashCanViewController.setWorkspaceViewHeight(size, animated: animated)
    } else {
      _trashCanViewController.setWorkspaceViewWidth(size, animated: animated)
    }
    _trashCanVisible = visible
  }

  private func isGestureTouchingTrashCan(gesture: UIGestureRecognizer) -> Bool {
    if let trashCanView = self.trashCanView where !trashCanView.hidden {
      return CGRectContainsPoint(trashCanView.bounds, gesture.locationInView(trashCanView))
    }

    return false
  }
}

// MARK: - WorkspaceViewControllerDelegate

extension WorkbenchViewController: WorkspaceViewControllerDelegate {
  public func workspaceViewController(
    workspaceViewController: WorkspaceViewController, didAddBlockView blockView: BlockView)
  {
    if workspaceViewController == toolboxCategoryViewController ||
      workspaceViewController == _trashCanViewController
    {
      addGestureTrackingForWorkspaceFolderBlockView(blockView)
    } else if workspaceViewController == self.workspaceViewController {
      addGestureTrackingForBlockView(blockView)
    }
  }

  public func workspaceViewController(
    workspaceViewController: WorkspaceViewController, didRemoveBlockView blockView: BlockView)
  {
    if workspaceViewController == toolboxCategoryViewController ||
      workspaceViewController == _trashCanViewController
    {
      removeGestureTrackingForWorkspaceFolderBlockView(blockView)
    } else if workspaceViewController == self.workspaceViewController {
      removeGestureTrackingForBlockView(blockView)
    }
  }

  public func workspaceViewController(
    workspaceViewController: WorkspaceViewController, willPresentViewController: UIViewController)
  {
    addUIStateValue(.PresentingPopover)
  }

  public func workspaceViewControllerDismissedViewController(
    workspaceViewController: WorkspaceViewController)
  {
    removeUIStateValue(.PresentingPopover)
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
      target: self, action: #selector(didRecognizeWorkspaceFolderPanGesture(_:)))
    panGesture.maximumNumberOfTouches = 1
    panGesture.delegate = self
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
      guard let rootBlockLayout = aBlockView.blockLayout?.rootBlockGroupLayout?.blockLayouts[0]
        else
      {
        return
      }

      // TODO:(#45) This should be copying the root block layout, not the root block view.
      let rootBlockView: BlockView! =
        ViewManager.sharedInstance.findBlockViewForLayout(rootBlockLayout)


      // Copy the block view into the workspace view
      let newBlockView: BlockView
      do {
        newBlockView = try copyBlockView(rootBlockView)
        updateWorkspaceCapacity()
      } catch let error as NSError {
        bky_assertionFailure("Could not copy toolbox block view into workspace view: \(error)")
        return
      }

      // Transfer this gesture recognizer from the original block view to the new block view
      gesture.removeTarget(self, action: #selector(didRecognizeWorkspaceFolderPanGesture(_:)))
      aBlockView.removeGestureRecognizer(gesture)
      gesture.addTarget(self, action: #selector(didRecognizeWorkspacePanGesture(_:)))
      newBlockView.addGestureRecognizer(gesture)

      // Start the first step of dragging the block layout
      let touchPosition = workspaceView.workspacePositionFromGestureTouchLocation(gesture)
      _dragger.startDraggingBlockLayout(newBlockView.blockLayout!, touchPosition: touchPosition)

      if let trashWorkspace = _trashCanViewController.workspace
        where trashWorkspace.containsBlock(rootBlockLayout.block)
      {
        do {
          // Remove this block view from the trash can
          try _trashCanViewController.workspaceLayoutCoordinator?
            .removeBlockTree(rootBlockLayout.block)
        } catch let error as NSError {
          bky_assertionFailure("Could not remove block from trash can: \(error)")
          return
        }
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
    // TODO:(#122) Gesture recognizing doesn't work simultaneously on a subview when a superview is
    // already being dragged.

    blockView.bky_removeAllGestureRecognizers()

    let panGesture =
      UIPanGestureRecognizer(target: self, action: #selector(didRecognizeWorkspacePanGesture(_:)))
    panGesture.maximumNumberOfTouches = 1
    blockView.addGestureRecognizer(panGesture)

    let tapGesture =
      UITapGestureRecognizer(target: self, action: #selector(didRecognizeWorkspaceTapGesture(_:)))
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
      blockLayout = blockView.blockLayout?.draggableBlockLayout else {
        return
    }

    let touchPosition = workspaceView.workspacePositionFromGestureTouchLocation(gesture)
    let touchingTrashCan = isGestureTouchingTrashCan(gesture)

    // TODO:(#44) Handle screen rotations (either lock the screen during drags or stop any
    // on-going drags when the screen is rotated).

    if gesture.state == .Began {
      // Temporarily remove gesture recognizer from the blockView
      blockView.removeGestureRecognizer(gesture)

      addUIStateValue(.DraggingBlock)
      _dragger.startDraggingBlockLayout(blockLayout, touchPosition: touchPosition)

      // When the block layout is being dragged around, the corresponding view hierarchy may have
      // been re-created (for example, if the block was disconnected from its parent). So we must
      // find the view for the block layout and re-attach the gesture recognizer to it.
      ViewManager.sharedInstance.findBlockViewForLayout(blockLayout)?.addGestureRecognizer(gesture)
    } else if gesture.state == .Changed || gesture.state == .Cancelled || gesture.state == .Ended {
      addUIStateValue(.DraggingBlock)
      _dragger.continueDraggingBlockLayout(blockLayout, touchPosition: touchPosition)

      if touchingTrashCan && blockLayout.block.deletable {
        addUIStateValue(.TrashCanHighlighted)
      } else {
        removeUIStateValue(.TrashCanHighlighted)
      }
    }

    if gesture.state == .Cancelled || gesture.state == .Ended || gesture.state == .Failed {
      if touchingTrashCan && blockLayout.block.deletable {
        // This block is being "deleted" -- cancel the drag and copy the block into the trash can
        _dragger.clearGestureDataForBlockLayout(blockLayout)

        do {
          try _trashCanViewController.workspaceLayoutCoordinator?
            .copyBlockTree(blockLayout.block, editable: true)
          try _workspaceLayoutCoordinator?.removeBlockTree(blockLayout.block)
          updateWorkspaceCapacity()
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

// MARK: - Block Highlighting

extension WorkbenchViewController {
  /**
   Highlights a block in the workspace.

   - Parameter blockUUID: The UUID of the block to highlight
   */
  public func highlightBlock(blockUUID: String) {
    guard let workspace = self.workspace,
      let block = workspace.allBlocks[blockUUID] else {
        return
    }

    setHighlight(true, forBlocks: [block])
  }

  /**
   Unhighlights a block in the workspace.

   - Paramater blockUUID: The UUID of the block to unhighlight.
   */
  public func unhighlightBlock(blockUUID: String) {
    guard let workspace = self.workspace,
      let block = workspace.allBlocks[blockUUID] else {
      return
    }

    setHighlight(false, forBlocks: [block])
  }

  /**
   Unhighlights all blocks in the workspace.
   */
  public func unhighlightAllBlocks() {
    guard let workspace = self.workspace else {
      return
    }

    setHighlight(false, forBlocks: Array(workspace.allBlocks.values))
  }

  /**
   Sets the `highlighted` property for the layouts of a given list of blocks.

   - Parameter highlight: The value to set for `highlighted`
   - Parameter blocks: The list of `Block` instances
   */
  private func setHighlight(highlight: Bool, forBlocks blocks: [Block]) {
    guard let workspaceLayout = workspaceView.workspaceLayout else {
      return
    }

    let visibleBlockLayouts = workspaceLayout.allVisibleBlockLayoutsInWorkspace()

    for block in blocks {
      guard let blockLayout = block.layout where visibleBlockLayouts.contains(blockLayout) else {
        continue
      }

      blockLayout.highlighted = highlight

      if highlight {
        workspaceLayout.bringBlockGroupLayoutToFront(blockLayout.parentBlockGroupLayout)
      }
    }
  }
}

// MARK: - Scrolling

extension WorkbenchViewController {
  public func scrollBlockIntoView(blockUUID: String, animated: Bool) {
    guard let block = workspace?.allBlocks[blockUUID] else {
        return
    }

    workspaceView.scrollBlockIntoView(block, animated: animated)
  }
}

// MARK: - UIGestureRecognizerDelegate

extension WorkbenchViewController: UIGestureRecognizerDelegate {
  public func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
    if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer,
      let blockView = gestureRecognizer.view as? BlockView,
      let block = blockView.blockLayout?.block,
      let toolboxCategory = toolboxCategoryViewController.category
      where toolboxCategory.containsBlock(block)
    {
      // For toolbox blocks, only fire the pan gesture if the user is panning in the direction
      // perpendicular to the toolbox scrolling. Otherwise, don't let it fire, so the user can
      // simply continue scrolling the toolbox.
      let velocity = panGestureRecognizer.velocityInView(panGestureRecognizer.view)

      // Figure out angle of velocity vector, relative to the scroll direction
      let radians: CGFloat
      if style.toolboxOrientation == .Vertical {
        radians = atan(abs(velocity.x) / abs(velocity.y))
      } else {
        radians = atan(abs(velocity.y) / abs(velocity.x))
      }

      // Fire the gesture if it started more than 20 degrees in the perpendicular direction
      let angle = (radians / CGFloat(M_PI)) * 180
      return angle > 20
    }

    return true
  }
}
