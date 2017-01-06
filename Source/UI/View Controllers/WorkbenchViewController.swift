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
@objc(BKYWorkbenchViewControllerDelegate)
public protocol WorkbenchViewControllerDelegate: class {
  /**
   Event that is called when a `WorkbenchViewController` updates its `state`.
   */
  func workbenchViewController(_ workbenchViewController: WorkbenchViewController,
                               didUpdateState state: WorkbenchViewController.UIState)
}

/**
 Adding Swift convenience functions to `BKYWorkbenchViewControllerUIState`.
 */
extension WorkbenchViewControllerUIState {
  /**
   Initializes the workbench view controller UI state with a `WorkbenchViewController.UIStateValue`.

   - parameter value: The `enum` value of the state.
   */
  public init(value: WorkbenchViewControllerUIStateValue) {
    self.init(rawValue: 1 << UInt(value.rawValue))
  }

  /**
   Checks if the state intersects with another. Returns `true` if they share any common options,
   `false` otherwise.
   */
  public func intersectsWith(_ other: WorkbenchViewControllerUIState) -> Bool {
    return intersection(other).rawValue != 0
  }
}

// TODO:(#61) Refactor parts of `WorkbenchViewController` into `WorkspaceViewController`.

/**
 View controller for editing a workspace.
 */
@objc(BKYWorkbenchViewController)
open class WorkbenchViewController: UIViewController {

  // MARK: - Constants

  /// The style of the workbench
  @objc(BKYWorkbenchViewControllerStyle)
  public enum Style: Int {
    case
      /// Style where the toolbox is positioned vertically, the trash can is located in the
      /// bottom-right corner, and the trash folder flies out from the bottom
      defaultStyle,
      /// Style where the toolbox is positioned horizontally on the bottom, the trash can is
      /// located in the top-right corner, and the trash folder flies out from the trailing edge of
      /// the screen
      alternate

    /// The `WorkspaceFlowLayout.LayoutDirection` to use for the trash folder
    fileprivate var trashLayoutDirection: WorkspaceFlowLayout.LayoutDirection {
      switch self {
      case .defaultStyle, .alternate: return .horizontal
      }
    }

    /// The `WorkspaceFlowLayout.LayoutDirection` to use for the toolbox category
    fileprivate var toolboxCategoryLayoutDirection: WorkspaceFlowLayout.LayoutDirection {
      switch self {
      case .defaultStyle: return .vertical
      case .alternate: return .horizontal
      }
    }

    /// The `ToolboxCategoryListViewController.Orientation` to use for the toolbox
    fileprivate var toolboxOrientation: ToolboxCategoryListViewController.Orientation {
      switch self {
      case .defaultStyle: return .vertical
      case .alternate: return .horizontal
      }
    }
  }

  // MARK: - Aliases

  /// Details the bitflags for `WorkbenchViewController`'s state.
  public typealias UIState = WorkbenchViewControllerUIState

  /// Specifies the bitflags for individual state values of `WorkbenchViewController`.
  public typealias UIStateValue = WorkbenchViewControllerUIStateValue

  // MARK: - Properties

  /// The main workspace view controller
  open fileprivate(set) var workspaceViewController: WorkspaceViewController! {
    didSet {
      oldValue?.delegate = nil
      workspaceViewController?.delegate = self
    }
  }

  /// A convenience property to `workspaceViewController.workspaceView`
  fileprivate var workspaceView: WorkspaceView! {
    return workspaceViewController.workspaceView
  }

  /// The trash can view.
  open fileprivate(set) var trashCanView: TrashCanView!

  /// The toolbox category view controller.
  open fileprivate(set) var toolboxCategoryViewController: ToolboxCategoryViewController! {
    didSet {
      // We need to listen for when block views are added/removed from the block list
      // so we can attach pan gesture recognizers to those blocks (for dragging them onto
      // the workspace)
      oldValue?.delegate = nil
      toolboxCategoryViewController.delegate = self
    }
  }

  /// The layout engine to use for all views
  public final let engine: LayoutEngine
  /// The layout builder to create layout hierarchies
  public final let layoutBuilder: LayoutBuilder
  /// The factory for creating views
  public final let viewFactory: ViewFactory

  /// The style of workbench
  public final let style: Style
  /// The current state of the main workspace
  open var workspace: Workspace? {
    return _workspaceLayout?.workspace
  }
  /// The toolbox that has been loaded via `loadToolbox(:)`
  open var toolbox: Toolbox? {
    return _toolboxLayout?.toolbox
  }

  /// The `NameManager` that controls the variables in this workbench's scope.
  private let variableNameManager: NameManager

  /// The main workspace layout coordinator
  fileprivate var _workspaceLayoutCoordinator: WorkspaceLayoutCoordinator? {
    didSet {
      _dragger.workspaceLayoutCoordinator = _workspaceLayoutCoordinator
      _workspaceLayoutCoordinator?.variableNameManager = variableNameManager
    }
  }
  /// The underlying workspace layout
  fileprivate var _workspaceLayout: WorkspaceLayout? {
    return _workspaceLayoutCoordinator?.workspaceLayout
  }
  /// The underlying toolbox layout
  fileprivate var _toolboxLayout: ToolboxLayout?

  /// Displays (`true`) or hides (`false`) a trash can. By default, this value is set to `true`.
  open var enableTrashCan: Bool = true {
    didSet {
      setTrashCanViewVisible(enableTrashCan)

      if !enableTrashCan {
        // Hide trash can folder
        removeUIStateValue(.trashCanOpen, animated: false)
      }
    }
  }

  /// Enables or disables pinch zooming of the workspace. Defaults to `true`.
  open var allowZoom: Bool {
    get { return workspaceViewController.workspaceView.allowZoom }
    set { workspaceViewController.workspaceView.allowZoom = newValue }
  }

  /**
  Flag for whether the toolbox drawer should stay visible once it has been opened (`true`)
  or if it should automatically close itself when the user does something else (`false`).
  By default, this value is set to `false`.
  */
  open var toolboxDrawerStaysOpen: Bool = false

  /// The current state of the UI
  open fileprivate(set) var state = UIState.defaultState

  /// The delegate for events that occur in the workbench
  open weak var delegate: WorkbenchViewControllerDelegate?

  /// Controls logic for dragging blocks around in the workspace
  fileprivate let _dragger = Dragger()
  /// Controller for listing the toolbox categories
  fileprivate var _toolboxCategoryListViewController: ToolboxCategoryListViewController!
  /// Controller for managing the trash can workspace
  fileprivate var _trashCanViewController: TrashCanViewController!
  /// Flag indicating if the `self._trashCanViewController` is being shown
  fileprivate var _trashCanVisible: Bool = false

  // MARK: - Initializers

  /**
   Creates the workbench with defaults for `self.engine`, `self.layoutBuilder`,
   `self.viewFactory`.

   - parameter style: The `Style` to use for this laying out items in this view controller.
   */
  public init(style: Style) {
    self.style = style
    self.engine = DefaultLayoutEngine()
    self.layoutBuilder = LayoutBuilder(layoutFactory: DefaultLayoutFactory())
    self.viewFactory = ViewFactory()
    self.variableNameManager = NameManager()
    super.init(nibName: nil, bundle: nil)
    commonInit()
  }

  /**
   Creates the workbench.

   - parameter style: The `Style` to use for this laying out items in this view controller.
   - parameter engine: Value used for `self.layoutEngine`.
   - parameter layoutBuilder: Value used for `self.layoutBuilder`.
   - parameter viewFactory: Value used for `self.viewFactory`.
   */
  public init(style: Style, engine: LayoutEngine, layoutBuilder: LayoutBuilder,
              viewFactory: ViewFactory, variableNameManager: NameManager)
  {
    self.style = style
    self.engine = engine
    self.layoutBuilder = layoutBuilder
    self.viewFactory = viewFactory
    self.variableNameManager = variableNameManager
    super.init(nibName: nil, bundle: nil)
    commonInit()
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    // TODO:(#52) Support the ability to create view controllers from XIBs.
    // Note: Both the layoutEngine and layoutBuilder need to be initialized somehow.
    fatalError("Called unsupported initializer")
  }

  fileprivate func commonInit() {
    // Create main workspace view
    workspaceViewController = WorkspaceViewController(viewFactory: viewFactory)
    workspaceViewController.workspaceLayoutCoordinator?.variableNameManager = variableNameManager
    workspaceViewController.workspaceView.allowZoom = true
    workspaceViewController.workspaceView.scrollView.panGestureRecognizer
      .addTarget(self, action: #selector(didPanWorkspaceView(_:)))
    let tapGesture =
      UITapGestureRecognizer(target: self, action: #selector(didTapWorkspaceView(_:)))
    workspaceViewController.workspaceView.scrollView.addGestureRecognizer(tapGesture)

    // Create trash can button
    let trashCanView = TrashCanView(imageNamed: "trash_can")
    trashCanView.button
      .addTarget(self, action: #selector(didTapTrashCan(_:)), for: .touchUpInside)
    self.trashCanView = trashCanView

    // Set up trash can folder view controller
    _trashCanViewController = TrashCanViewController(
      engine: engine, layoutBuilder: layoutBuilder, layoutDirection: style.trashLayoutDirection,
      viewFactory: viewFactory)
    _trashCanViewController.delegate = self

    // Set up toolbox category list view controller
    _toolboxCategoryListViewController = ToolboxCategoryListViewController(
      orientation: style.toolboxOrientation)
    _toolboxCategoryListViewController.delegate = self

    // Create toolbox views
    toolboxCategoryViewController = ToolboxCategoryViewController(viewFactory: viewFactory,
      orientation: style.toolboxOrientation, variableNameManager: variableNameManager)

    // Register for keyboard notifications
    NotificationCenter.default.addObserver(
      self, selector: #selector(keyboardWillShowNotification(_:)),
      name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(keyboardWillHideNotification(_:)),
      name: NSNotification.Name.UIKeyboardWillHide, object: nil)
  }

  deinit {
    // Unregister all notifications
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Super

  open override func loadView() {
    super.loadView()

    self.view.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
    self.view.autoresizesSubviews = true
    self.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]

    // Add child view controllers
    addChildViewController(workspaceViewController)
    addChildViewController(_trashCanViewController)
    addChildViewController(_toolboxCategoryListViewController)
    addChildViewController(toolboxCategoryViewController)

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

    if style == .alternate {
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

    self.view.sendSubview(toBack: workspaceViewController.view)

    let panGesture = BlocklyPanGestureRecognizer(targetDelegate: self)
    panGesture.delegate = self
    workspaceViewController.view.addGestureRecognizer(panGesture)

    let toolboxGesture = BlocklyPanGestureRecognizer(targetDelegate: self)
    toolboxGesture.delegate = self
    toolboxCategoryViewController.view.addGestureRecognizer(toolboxGesture)

    let trashGesture = BlocklyPanGestureRecognizer(targetDelegate: self)
    trashGesture.delegate = self
    _trashCanViewController.view.addGestureRecognizer(trashGesture)

    // Signify to view controllers that they've been moved to this parent
    workspaceViewController.didMove(toParentViewController: self)
    _trashCanViewController.didMove(toParentViewController: self)
    _toolboxCategoryListViewController.didMove(toParentViewController: self)
    toolboxCategoryViewController.didMove(toParentViewController: self)

    // Create a default workspace, if one doesn't already exist
    if workspace == nil {
      do {
        try loadWorkspace(Workspace())
      } catch let error {
        bky_print("Could not create a default workspace: \(error)")
      }
    }
  }

  open override func viewDidLoad() {
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

   - parameter workspace: The `Workspace` to load
   - throws:
   `BlocklyError`: Thrown if an associated `WorkspaceLayout` could not be created for the workspace.
   - note: A `ConnectionManager` is automatically created for the `WorkspaceLayoutCoordinator`.
   */
  open func loadWorkspace(_ workspace: Workspace) throws {
    try loadWorkspace(workspace, connectionManager: ConnectionManager())
  }

  /**
   Automatically creates a `WorkspaceLayout` and `WorkspaceLayoutCoordinator` for a given workspace
   (using both the `self.engine` and `self.layoutBuilder` instances). The workspace is then
   rendered into the view controller.

   - parameter workspace: The `Workspace` to load
   - parameter connectionManager: A `ConnectionManager` to track connections in the workspace.
   - throws:
   `BlocklyError`: Thrown if an associated `WorkspaceLayout` could not be created for the workspace.
   */
  open func loadWorkspace(_ workspace: Workspace, connectionManager: ConnectionManager)
      throws {
    // Create a layout for the workspace, which is required for viewing the workspace
    let workspaceLayout = WorkspaceLayout(workspace: workspace, engine: engine)
    let aConnectionManager = connectionManager
    _workspaceLayoutCoordinator =
      try WorkspaceLayoutCoordinator(workspaceLayout: workspaceLayout,
                                     layoutBuilder: layoutBuilder,
                                     connectionManager: aConnectionManager)

    refreshView()
  }

  /**
   Automatically creates a `ToolboxLayout` for a given `Toolbox` (using both the `self.engine`
   and `self.layoutBuilder` instances) and loads it into the view controller.

   - parameter toolbox: The `Toolbox` to load
   - throws:
   `BlocklyError`: Thrown if an associated `ToolboxLayout` could not be created for the toolbox.
   */
  open func loadToolbox(_ toolbox: Toolbox, blockFactory: BlockFactory? = nil) throws {
    let toolboxLayout = ToolboxLayout(
      toolbox: toolbox, engine: engine, layoutDirection: style.toolboxCategoryLayoutDirection,
      layoutBuilder: layoutBuilder)
    _toolboxLayout = toolboxLayout
    _toolboxLayout?.setBlockFactory(blockFactory)

    refreshView()
  }

  /**
   Refreshes the UI based on the current version of `self.workspace` and `self.toolbox`.
   */
  open func refreshView() {
    do {
      try workspaceViewController?.loadWorkspaceLayoutCoordinator(_workspaceLayoutCoordinator)
    } catch let error {
      bky_assertionFailure("Could not load workspace layout: \(error)")
    }

    _toolboxCategoryListViewController?.toolboxLayout = _toolboxLayout
    _toolboxCategoryListViewController?.refreshView()

    toolboxCategoryViewController?.toolboxLayout = _toolboxLayout

    resetUIState()
    updateWorkspaceCapacity()
  }

  // MARK: - Private

  fileprivate dynamic func didPanWorkspaceView(_ gesture: UIPanGestureRecognizer) {
    addUIStateValue(.didPanWorkspace)
  }

  fileprivate dynamic func didTapWorkspaceView(_ gesture: UITapGestureRecognizer) {
    addUIStateValue(.didTapWorkspace)
  }

  /**
   Updates the trash can and toolbox so the user may only interact with block groups that
   would not exceed the workspace's remaining capacity.
   */
  fileprivate func updateWorkspaceCapacity() {
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

   - parameter blockView: The block view to copy into this workspace.
   - returns: The new block view that was added to this workspace.
   - throws:
   `BlocklyError`: Thrown if the block view could not be created.
   */
  open func copyBlockView(_ blockView: BlockView) throws -> BlockView
  {
    // TODO:(#57) When this operation is being used as part of a "copy-and-delete" operation, it's
    // causing a performance hit. Try to create an alternate method that performs an optimized
    // "cut" operation.

    guard let blockLayout = blockView.blockLayout else {
      throw BlocklyError(.layoutNotFound, "No layout was set for the `blockView` parameter")
    }
    guard let workspaceLayoutCoordinator = _workspaceLayoutCoordinator else {
      throw BlocklyError(.layoutNotFound,
        "No workspace layout coordinator has been set for `self._workspaceLayoutCoordinator`")
    }

    // Get the position of the block view relative to this view, and use that as
    // the position for the newly created block.
    // Note: This is done before creating a new block since adding a new block might change the
    // workspace's size, which would mess up this position calculation.
    let newWorkspacePosition = workspaceView.workspacePosition(fromBlockView: blockView)

    // Create a deep copy of this block in this workspace (which will automatically create a layout
    // tree for the block)
    let newBlock = try workspaceLayoutCoordinator.copyBlockTree(blockLayout.block, editable: true)

    // Set its new workspace position
    newBlock.layout?.parentBlockGroupLayout?.move(toWorkspacePosition: newWorkspacePosition)

    // Because there are listeners on the layout hierarchy to update the corresponding view
    // hierarchy when layouts change, we just need to find the view that was automatically created.
    guard
      let newBlockLayout = newBlock.layout,
      let newBlockView = ViewManager.sharedInstance.findBlockView(forLayout: newBlockLayout) else
    {
      throw BlocklyError(.viewNotFound, "View could not be located for the copied block")
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

   - parameter state: The state to append to `self.state`.
   - parameter animated: True if changes in UI state should be animated. False, if not.
   */
  fileprivate func addUIStateValue(_ stateValue: UIStateValue, animated: Bool = true) {
    var state = UIState(value: stateValue)
    let newState: UIState

    if toolboxDrawerStaysOpen && self.state.intersectsWith(.categoryOpen) {
      // Always keep the .CategoryOpen state if it existed before
      state = state.union(.categoryOpen)
    }

    // When adding a new state, check for compatibility with existing states.

    switch stateValue {
    case .draggingBlock:
      // Dragging a block can only co-exist with highlighting the trash can
      newState = self.state.intersection([.trashCanHighlighted]).union(state)
    case .trashCanHighlighted:
      // This state can co-exist with anything, simply add it to the current state
      newState = self.state.union(state)
    case .editingTextField:
      // Allow .EditingTextField to co-exist with .PresentingPopover and .CategoryOpen, but nothing
      // else
      newState = self.state.intersection([.presentingPopover, .categoryOpen]).union(state)
    case .presentingPopover:
      // If .CategoryOpen already existed, continue to let it exist (as users may want to modify
      // blocks from inside the toolbox). Disallow everything else.
      newState = self.state.intersection([.categoryOpen]).union(state)
    case .defaultState, .didPanWorkspace, .didTapWorkspace, .categoryOpen, .trashCanOpen:
      // Whenever these states are added, clear out all existing state
      newState = state
    }

    refreshUIState(newState, animated: animated)
  }

  /**
   Removes a state to the current state of the UI. This call should have matched a previous call to
   addUIState(state:animated:).

   - parameter state: The state to remove from `self.state`.
   - parameter animated: True if changes in UI state should be animated. False, if not.
   */
  fileprivate func removeUIStateValue(_ stateValue: UIStateValue, animated: Bool = true) {
    // When subtracting a state value, there is no need to check for compatibility.
    // Simply set the new state, minus the given state value.
    let newState = self.state.subtracting(UIState(value: stateValue))
    refreshUIState(newState, animated: animated)
  }

  /**
   Resets the UI back to its default state.

   - parameter animated: True if changes in UI state should be animated. False, if not.
   */
  fileprivate func resetUIState(_ animated: Bool = true) {
    addUIStateValue(.defaultState, animated: animated)
  }

  /**
   Refreshes the UI based on a given state.

   - parameter state: The state to set the UI
   - parameter animated: True if changes in UI state should be animated. False, if not.
   - note: This method should not be called directly. Instead, you should call addUIState(...),
   removeUIState(...), or resetUIState(...).
   */
  fileprivate func refreshUIState(_ state: UIState, animated: Bool = true) {
    self.state = state

    setTrashCanFolderVisible(state.intersectsWith(.trashCanOpen), animated: animated)

    trashCanView?.setHighlighted(state.intersectsWith(.trashCanHighlighted), animated: animated)

    if let selectedCategory = _toolboxCategoryListViewController.selectedCategory
      , state.intersectsWith(.categoryOpen)
    {
      // Show the toolbox category
      toolboxCategoryViewController?.showCategory(selectedCategory, animated: true)
    } else {
      // Hide the toolbox category
      toolboxCategoryViewController?.hideCategory(animated: animated)
      _toolboxCategoryListViewController.selectedCategory = nil
    }

    if !state.intersectsWith(.editingTextField) {
      // Force all child text fields to end editing (which essentially dismisses the keyboard if
      // it's currently visible)
      self.view.endEditing(true)
    }

    if !state.intersectsWith(.presentingPopover) && self.presentedViewController != nil {
      dismiss(animated: animated, completion: nil)
    }

    delegate?.workbenchViewController(self, didUpdateState: state)
  }
}

// MARK: - Trash Can

extension WorkbenchViewController {
  // MARK: - Public

  /**
   Event that is fired when the trash can is tapped on.

   - parameter sender: The trash can button that sent the event.
   */
  public func didTapTrashCan(_ sender: UIButton) {
    // Toggle trash can visibility
    if !_trashCanVisible {
      addUIStateValue(.trashCanOpen)
    } else {
      removeUIStateValue(.trashCanOpen)
    }
  }

  // MARK: - Private

  fileprivate func setTrashCanViewVisible(_ visible: Bool) {
    trashCanView?.isHidden = !visible
  }

  fileprivate func setTrashCanFolderVisible(_ visible: Bool, animated: Bool) {
    if _trashCanVisible == visible && trashCanView != nil {
      return
    }

    let size: CGFloat = visible ? 300 : 0
    if style == .defaultStyle {
      _trashCanViewController.setWorkspaceViewHeight(size, animated: animated)
    } else {
      _trashCanViewController.setWorkspaceViewWidth(size, animated: animated)
    }
    _trashCanVisible = visible
  }

  fileprivate func isGestureTouchingTrashCan(_ gesture: BlocklyPanGestureRecognizer) -> Bool {
    if let trashCanView = self.trashCanView , !trashCanView.isHidden {
      return gesture.isTouchingView(trashCanView)
    }

    return false
  }

  fileprivate func isTouchTouchingTrashCan(_ touchPosition: CGPoint, fromView: UIView?) -> Bool {
    if let trashCanView = self.trashCanView , !trashCanView.isHidden {
      let trashSpacePosition = trashCanView.convert(touchPosition, from: fromView)
      return trashCanView.bounds.contains(trashSpacePosition)
    }

    return false
  }
}

// MARK: - WorkspaceViewControllerDelegate

extension WorkbenchViewController: WorkspaceViewControllerDelegate {
  public func workspaceViewController(
    _ workspaceViewController: WorkspaceViewController, didAddBlockView blockView: BlockView)
  {
    if workspaceViewController == self.workspaceViewController {
      addGestureTracking(forBlockView: blockView)
    }
  }

  public func workspaceViewController(
    _ workspaceViewController: WorkspaceViewController, didRemoveBlockView blockView: BlockView)
  {
    if workspaceViewController == self.workspaceViewController {
      removeGestureTracking(forBlockView: blockView)
    }
  }

  public func workspaceViewController(
    _ workspaceViewController: WorkspaceViewController, willPresentViewController: UIViewController)
  {
    addUIStateValue(.presentingPopover)
  }

  public func workspaceViewControllerDismissedViewController(
    _ workspaceViewController: WorkspaceViewController)
  {
    removeUIStateValue(.presentingPopover)
  }
}

// MARK: - Toolbox Gesture Tracking

extension WorkbenchViewController {
  /**
   Removes all gesture recognizers from a block view that is part of a workspace flyout (ie. trash
   can or toolbox).

   - parameter blockView: A given block view.
   */
  fileprivate func removeGestureTrackingForWorkspaceFolderBlockView(_ blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()
  }

  /**
   Copies the specified block from a flyout (trash/toolbox) to the workspace.

   - parameter blockView: The `BlockView` to copy
   - returns: The new `BlockView`
   */
  public func copyBlockToWorkspace(_ blockView: BlockView) -> BlockView? {
    // The block the user is dragging out of the toolbox/trash may be a child of a large nested
    // block. We want to do a deep copy on the root block (not just the current block).
    guard let rootBlockLayout = blockView.blockLayout?.rootBlockGroupLayout?.blockLayouts[0],
      // TODO:(#45) This should be copying the root block layout, not the root block view.
      let rootBlockView = ViewManager.sharedInstance.findBlockView(forLayout: rootBlockLayout)
      else
    {
      return nil
    }

    // Copy the block view into the workspace view
    let newBlockView: BlockView
    do {
      newBlockView = try copyBlockView(rootBlockView)
      updateWorkspaceCapacity()
    } catch let error {
      bky_assertionFailure("Could not copy toolbox block view into workspace view: \(error)")
      return nil
    }

    return newBlockView
  }

  /**
   Removes a `BlockView` from the trash, when moving it back to the workspace.

   - parameter blockView: The `BlockView` to remove.
   */
  public func removeBlockFromTrash(_ blockView: BlockView) {
    guard let rootBlockLayout = blockView.blockLayout?.rootBlockGroupLayout?.blockLayouts[0]
      else
    {
      return
    }

    if let trashWorkspace = _trashCanViewController.workspaceView.workspaceLayout?.workspace
      , trashWorkspace.containsBlock(rootBlockLayout.block)
    {
      do {
        // Remove this block view from the trash can
        try _trashCanViewController.workspace?.removeBlockTree(rootBlockLayout.block)
      } catch let error {
        bky_assertionFailure("Could not remove block from trash can: \(error)")
        return
      }
    }
  }
}

// MARK: - Workspace Gesture Tracking

extension WorkbenchViewController {
  /**
   Adds pan and tap gesture recognizers to a block view.

   - parameter blockView: A given block view.
   */
  fileprivate func addGestureTracking(forBlockView blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()

    let tapGesture =
      UITapGestureRecognizer(target: self, action: #selector(didRecognizeWorkspaceTapGesture(_:)))
    blockView.addGestureRecognizer(tapGesture)
  }

  /**
   Removes all gesture recognizers and any on-going gesture data from a block view.

   - parameter blockView: A given block view.
   */
  fileprivate func removeGestureTracking(forBlockView blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()

    if let blockLayout = blockView.blockLayout {
      _dragger.clearGestureDataForBlockLayout(blockLayout)
    }
  }

  /**
   Tap gesture event handler for a block view inside `self.workspaceView`.
   */
  fileprivate dynamic func didRecognizeWorkspaceTapGesture(_ gesture: UITapGestureRecognizer) {
  }
}

// MARK: - UIKeyboard notifications

extension WorkbenchViewController {
  fileprivate dynamic func keyboardWillShowNotification(_ notification: Notification) {
    addUIStateValue(.editingTextField)

    if let keyboardEndSize =
      (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
    {
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

  fileprivate dynamic func keyboardWillHideNotification(_ notification: Notification) {
    removeUIStateValue(.editingTextField)

    // Reset the canvas padding of the scroll view (when the keyboard was initially shown)
    let contentInsets = UIEdgeInsets.zero
    workspaceView.scrollView.contentInset = contentInsets
  }
}

// MARK: - ToolboxCategoryListViewControllerDelegate implementation

extension WorkbenchViewController: ToolboxCategoryListViewControllerDelegate {
  public func toolboxCategoryListViewController(
    _ controller: ToolboxCategoryListViewController, didSelectCategory category: Toolbox.Category)
  {
    addUIStateValue(.categoryOpen, animated: true)
  }

  public func toolboxCategoryListViewControllerDidDeselectCategory(
    _ controller: ToolboxCategoryListViewController)
  {
    removeUIStateValue(.categoryOpen, animated: true)
  }
}

// MARK: - Block Highlighting

extension WorkbenchViewController {
  /**
   Highlights a block in the workspace.

   - parameter blockUUID: The UUID of the block to highlight
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

   - parameter highlight: The value to set for `highlighted`
   - parameter blocks: The list of `Block` instances
   */
  fileprivate func setHighlight(_ highlight: Bool, forBlocks blocks: [Block]) {
    guard let workspaceLayout = workspaceView.workspaceLayout else {
      return
    }

    let visibleBlockLayouts = workspaceLayout.allVisibleBlockLayoutsInWorkspace()

    for block in blocks {
      guard let blockLayout = block.layout , visibleBlockLayouts.contains(blockLayout) else {
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

// MARK: - BlocklyPanGestureRecognizerDelegate

extension WorkbenchViewController: BlocklyPanGestureRecognizerDelegate {
  /**
   Pan gesture event handler for a block view inside `self.workspaceView`.
   */
  public func blocklyPanGestureRecognizer(_ gesture: BlocklyPanGestureRecognizer,
    didTouchBlock block: BlockView, touch: UITouch,
    touchState: BlocklyPanGestureRecognizer.TouchState)
  {
    guard let blockLayout = block.blockLayout?.draggableBlockLayout else {
      return
    }

    var blockView = block
    let touchPosition = touch.location(in: workspaceView.scrollView.containerView)
    let workspacePosition = workspaceView.workspacePosition(fromViewPoint: touchPosition)

    // TODO:(#44) Handle screen rotations (either lock the screen during drags or stop any
    // on-going drags when the screen is rotated).

    if touchState == .began {
      let inToolbox = gesture.view == toolboxCategoryViewController.view
      let inTrash = gesture.view == _trashCanViewController.view
      // If the touch is in the toolbox, copy the block over to the workspace first.
      if inToolbox {
        guard let newBlock = copyBlockToWorkspace(blockView) else {
          return
        }
        gesture.replaceBlock(block, with: newBlock)
        blockView = newBlock
      } else if inTrash {
        let oldBlock = blockView

        guard let newBlock = copyBlockToWorkspace(blockView) else {
          return
        }
        gesture.replaceBlock(block, with: newBlock)
        blockView = newBlock
        removeBlockFromTrash(oldBlock)
      }

      guard let blockLayout = blockView.blockLayout?.draggableBlockLayout else {
        return
      }

      addUIStateValue(.draggingBlock)
      _dragger.startDraggingBlockLayout(blockLayout, touchPosition: workspacePosition)
    } else if touchState == .changed || touchState == .ended {
      addUIStateValue(.draggingBlock)
      _dragger.continueDraggingBlockLayout(blockLayout, touchPosition: workspacePosition)

      if isGestureTouchingTrashCan(gesture) && blockLayout.block.deletable {
        addUIStateValue(.trashCanHighlighted)
      } else {
        removeUIStateValue(.trashCanHighlighted)
      }
    }

    if touchState == .ended {
      let touchTouchingTrashCan = isTouchTouchingTrashCan(touchPosition,
        fromView: workspaceView.scrollView.containerView)
      if touchTouchingTrashCan && blockLayout.block.deletable {
        // This block is being "deleted" -- cancel the drag and copy the block into the trash can
        _dragger.clearGestureDataForBlockLayout(blockLayout)

        do {
          try _trashCanViewController.workspace?.copyBlockTree(blockLayout.block, editable: true)
          try _workspaceLayout?.workspace.removeBlockTree(blockLayout.block)
          updateWorkspaceCapacity()
        } catch let error {
          bky_assertionFailure("Could not copy block to trash can: \(error)")
        }
      } else {
        _dragger.finishDraggingBlockLayout(blockLayout)
      }

      // HACK: Re-add gesture tracking for the block view, as there is a problem re-recognizing
      // them when dragging multiple blocks simultaneously
      addGestureTracking(forBlockView: blockView)

      // Update the UI state
      removeUIStateValue(.draggingBlock)
      if !isGestureTouchingTrashCan(gesture) {
        removeUIStateValue(.trashCanHighlighted)
      }
    }

    return
  }
}

// MARK: - UIGestureRecognizerDelegate

extension WorkbenchViewController: UIGestureRecognizerDelegate {
  public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if let panGestureRecognizer = gestureRecognizer as? BlocklyPanGestureRecognizer
      , gestureRecognizer.view == toolboxCategoryViewController.view
    {
      // For toolbox blocks, only fire the pan gesture if the user is panning in the direction
      // perpendicular to the toolbox scrolling. Otherwise, don't let it fire, so the user can
      // simply continue scrolling the toolbox.
      let delta = panGestureRecognizer.firstTouchDelta(inView: panGestureRecognizer.view)

      // Figure out angle of delta vector, relative to the scroll direction
      let radians: CGFloat
      if style.toolboxOrientation == .vertical {
        radians = atan(abs(delta.x) / abs(delta.y))
      } else {
        radians = atan(abs(delta.y) / abs(delta.x))
      }

      // Fire the gesture if it started more than 20 degrees in the perpendicular direction
      let angle = (radians / CGFloat(M_PI)) * 180
      if angle > 20 {
        return true
      } else {
        panGestureRecognizer.cancelAllTouches()
        return false
      }
    }

    return true
  }

  public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
    shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool
  {
    let scrollView = workspaceViewController.workspaceView.scrollView
    let toolboxScrollView = toolboxCategoryViewController.workspaceScrollView

    // Force the scrollView pan and zoom gestures to fail unless this one fails
    if otherGestureRecognizer == scrollView.panGestureRecognizer ||
      otherGestureRecognizer == toolboxScrollView.panGestureRecognizer ||
      otherGestureRecognizer == scrollView.pinchGestureRecognizer {
      return true
    }

    return false
  }
}
