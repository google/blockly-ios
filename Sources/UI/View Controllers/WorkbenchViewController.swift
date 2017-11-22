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

import AEXML
import UIKit

/**
 Delegate for events that occur on `WorkbenchViewController`.
 */
@objc(BKYWorkbenchViewControllerDelegate)
public protocol WorkbenchViewControllerDelegate: class {
  /**
   Event that is called when a workbench updates its UI state.

   - parameter workbenchViewController: The `WorkbenchViewController`.
   - parameter state: The current `WorkbenchViewController.UIState`.
   */
  func workbenchViewController(
    _ workbenchViewController: WorkbenchViewController,
    didUpdateState state: WorkbenchViewController.UIState)

  /**
   Optional method that a delegate may override to specify the set of UI state values that should
   be kept in the workbench when a specific value is added via
   `WorkbenchViewController.addUIStateValue(_:animated)`.

   - parameter workbenchViewController: The `WorkbenchViewController`.
   - parameter keepStateValues: The default set of `UIStateValue` values that the system recommends
   keeping when `stateValue` is added.
   - parameter stateValue: The `UIStateValue` that is being added to the workbench.
   - returns: The set of `UIStateValue` values that should be kept.
   */
  @objc optional func workbenchViewController(
    _ workbenchViewController: WorkbenchViewController,
    shouldKeepStates keepStateValues: Set<WorkbenchViewController.UIStateValue>,
    forStateValue stateValue: WorkbenchViewController.UIStateValue)
    -> Set<WorkbenchViewController.UIStateValue>
}

// TODO(#61): Refactor parts of `WorkbenchViewController` into `WorkspaceViewController`.

/**
 View controller for editing a workspace.
 */
@objc(BKYWorkbenchViewController)
@objcMembers open class WorkbenchViewController: UIViewController {

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

  /// Set of `UIStateValue` values representing the workbench state.
  public typealias UIState = Set<UIStateValue>
  /// Underlying type for a UI state value.
  public typealias UIStateValue = Int

  // MARK: - Properties

  /// Total number of `UIStateValue` values that have been created via
  /// `WorkbenchViewController.newUIStateValue()`.
  private static var numberOfUIStateValues = 0
  /// State indicating the trash can is open.
  public let stateTrashCanOpen = WorkbenchViewController.newUIStateValue()
  /// State indicating the trash can is highlighted
  public let stateTrashCanHighlighted = WorkbenchViewController.newUIStateValue()
  /// State indicating the toolbox category is open.
  public let stateCategoryOpen = WorkbenchViewController.newUIStateValue()
  /// State indicating a text field is being edited.
  public let stateEditingTextField = WorkbenchViewController.newUIStateValue()
  /// State indicating a block is currently being dragged.
  public let stateDraggingBlock = WorkbenchViewController.newUIStateValue()
  /// State indicating a popover is being presented.
  public let statePresentingPopover = WorkbenchViewController.newUIStateValue()
  /// State indicating the user panned the workspace.
  public let stateDidPanWorkspace = WorkbenchViewController.newUIStateValue()
  /// State indicating the user tapped the workspace.
  public let stateDidTapWorkspace = WorkbenchViewController.newUIStateValue()

  /// The main workspace view controller
  public private(set) lazy var workspaceViewController: WorkspaceViewController = {
    // Create main workspace view
    let workspaceViewController = WorkspaceViewController(viewFactory: viewFactory)
    workspaceViewController.delegate = self
    workspaceViewController.workspaceLayoutCoordinator?.variableNameManager = variableNameManager
    workspaceViewController.workspaceView.allowZoom = true
    workspaceViewController.workspaceView.scrollView.panGestureRecognizer
      .addTarget(self, action: #selector(didPanWorkspaceView(_:)))
    workspaceViewController.workspaceView.scrollView.addGestureRecognizer(
      workspaceTapGestureRecognizer)
    workspaceViewController.workspaceView.dragLayerView = workspaceDragLayerView
    return workspaceViewController
  }()

  /// A convenience property to `workspaceViewController.workspaceView`
  fileprivate var workspaceView: WorkspaceView {
    return workspaceViewController.workspaceView
  }

  /// Layer that temporarily holds blocks when they are dragged.
  fileprivate let workspaceDragLayerView = ZIndexedGroupView(frame: .zero)

  /// The trash can view.
  open fileprivate(set) lazy var trashCanView: TrashCanView = {
    // Create trash can button
    let trashCanView = TrashCanView(imageNamed: "trash_can")
    trashCanView.button
      .addTarget(self, action: #selector(didTapTrashCan(_:)), for: .touchUpInside)
    trashCanView.button.isUserInteractionEnabled = self.keepTrashedBlocks
    trashCanView.tintColor = ColorPalette.grey.tint800
    return trashCanView
  }()

  /// The undo button
  open fileprivate(set) lazy var undoButton: UIButton = {
    let undoButton = UIButton(type: .system)
    if let image = ImageLoader.loadImage(
      named: "undo", forClass: WorkbenchViewController.self) {
      undoButton.setImage(image, for: .normal)
      undoButton.imageView?.contentMode = .scaleAspectFit
      undoButton.contentHorizontalAlignment = .fill
      undoButton.contentVerticalAlignment = .fill
      if self.engine.rtl {
        // Flip the image horizontally for RTL
        undoButton.transform = CGAffineTransform(scaleX: -1, y: 1)
      }
    }
    undoButton.addTarget(self, action: #selector(didTapUndoButton(_:)), for: .touchUpInside)
    undoButton.isEnabled = false
    return undoButton
  }()

  /// The redo button
  open fileprivate(set) lazy var redoButton: UIButton = {
    let redoButton = UIButton(type: .system)
    if let image = ImageLoader.loadImage(
      named: "redo", forClass: WorkbenchViewController.self) {
      redoButton.setImage(image, for: .normal)
      redoButton.contentMode = .center
      redoButton.imageView?.contentMode = .scaleAspectFit
      redoButton.contentHorizontalAlignment = .fill
      redoButton.contentVerticalAlignment = .fill
      if self.engine.rtl {
        // Flip the image horizontally for RTL
        redoButton.transform = CGAffineTransform(scaleX: -1, y: 1)
      }
    }
    redoButton.addTarget(self, action: #selector(didTapRedoButton(_:)), for: .touchUpInside)
    redoButton.isEnabled = false
    return redoButton
  }()

  /// The toolbox category view controller.
  open fileprivate(set) lazy var toolboxCategoryViewController: ToolboxCategoryViewController = {
    let viewController = ToolboxCategoryViewController(
      viewFactory: self.viewFactory,
      orientation: self.style.toolboxOrientation,
      variableNameManager: self.variableNameManager)
    viewController.delegate = self
    return viewController
  }()

  /// The layout engine to use for all views
  public final let engine: LayoutEngine
  /// The layout builder to create layout hierarchies
  public final let layoutBuilder: LayoutBuilder
  /// The factory for creating blocks under this workbench. Any block added to the workbench
  /// should be able to be re-created using this factory.
  public final let blockFactory: BlockFactory
  /// The factory for creating views
  public final let viewFactory: ViewFactory

  /// The style of workbench
  public final let style: Style
  /// The main workspace.
  open var workspace: Workspace? {
    return _workspaceLayout?.workspace
  }
  /// The toolbox that has been loaded via `loadToolbox(:)`
  open var toolbox: Toolbox? {
    return _toolboxLayout?.toolbox
  }

  /// The `NameManager` that controls the variables in this workbench's scope.
  public let variableNameManager: NameManager

  /// Coordinator that handles logic for managing procedure functionality
  public var procedureCoordinator: ProcedureCoordinator? {
    didSet {
      if oldValue != procedureCoordinator {
        oldValue?.syncWithWorkbench(nil)
        procedureCoordinator?.syncWithWorkbench(self)
      }
    }
  }

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
        removeUIStateValue(stateTrashCanOpen, animated: false)
      }
    }
  }

  /// If `true`, blocks dragged into trash are kept in memory and can be recalled by tapping the
  /// trash can. If `false`, blocks are not kept in memory and tapping the trash can is disabled.
  /// Defaults to `false`.
  open var keepTrashedBlocks: Bool = false {
    didSet {
      trashCanView.button.isUserInteractionEnabled = keepTrashedBlocks

      if !keepTrashedBlocks {
        // Hide trash can folder
        removeUIStateValue(stateTrashCanOpen, animated: false)
      }
    }
  }

  /// Enables or disables pinch zooming of the workspace. Defaults to `true`.
  open var allowZoom: Bool {
    get { return workspaceViewController.workspaceView.allowZoom }
    set { workspaceViewController.workspaceView.allowZoom = newValue }
  }

  /// Enables or disables the ability to undo/redo actions in the workspace. Defaults to `true`.
  open var allowUndoRedo: Bool = true {
    didSet {
      undoButton.isHidden = !allowUndoRedo
      redoButton.isHidden = !allowUndoRedo
    }
  }

  /// Keeps track of whether `self.navigationController.interactivePopGestureRecognizer` was
  /// enabled prior to loading this view controller. This value is used for restoring its previous
  /// state after this view controller has disappeared.
  fileprivate var _wasInteractivePopGestureRecognizerEnabled: Bool = false

  /// Enables or disables the `interactivePopGestureRecognizer` on `self.navigationController` (i.e.
  /// the backswipe gesture on `UINavigationController`). Defaults to `false`.
  open var allowInteractivePopGestureRecognizer: Bool = false {
    didSet {
      setInteractivePopGestureRecognizerEnabled(allowInteractivePopGestureRecognizer)
    }
  }

  /// The background color to use for the main workspace.
  public var workspaceBackgroundColor: UIColor? {
    get { return view.backgroundColor }
    set { view.backgroundColor = newValue }
  }

  /**
  Flag for whether the toolbox drawer should stay visible once it has been opened (`true`)
  or if it should automatically close itself when the user does something else (`false`).
  By default, this value is set to `false`.
  */
  open var toolboxDrawerStaysOpen: Bool = false

  /// A set containing all active states of the UI.
  open fileprivate(set) var state = WorkbenchViewController.UIState()

  /// The delegate for events that occur in the workbench
  open weak var delegate: WorkbenchViewControllerDelegate?

  /// Controls logic for dragging blocks around in the workspace
  fileprivate let _dragger = Dragger()
  /// Controller for listing the toolbox categories
  open fileprivate(set) lazy var toolboxCategoryListViewController:
    ToolboxCategoryListViewController = {
    // Set up toolbox category list view controller
    let viewController =
      ToolboxCategoryListViewController(orientation: self.style.toolboxOrientation)
    viewController.delegate = self
    viewController.view.backgroundColor = .white
    return viewController
  }()
  /// Controller for managing the trash can workspace
  open fileprivate(set) lazy var trashCanViewController: TrashCanViewController = {
    // Set up trash can folder view controller
    let viewController = TrashCanViewController(
      engine: self.engine,
      layoutBuilder: self.layoutBuilder,
      layoutDirection: self.style.trashLayoutDirection,
      viewFactory: self.viewFactory)
    viewController.delegate = self
    return viewController
  }()
  /// Flag indicating if the `self.trashCanViewController` is being shown
  fileprivate var _trashCanVisible: Bool = false

  /// Flag determining if this view controller should be recording events for undo/redo purposes.
  open fileprivate(set) var shouldRecordEvents = true

  /// Stack of events to run when applying "undo" actions. The events are sorted in
  /// chronological order, where the first event to "undo" is at the end of the array.
  open var undoStack = [BlocklyEvent]() {
    didSet {
      undoButton.isEnabled = !undoStack.isEmpty
    }
  }

  /// Stack of events to run when applying "redo" actions. The events are sorted in reverse
  /// chronological order, where the first event to "redo" is at the end of the array.
  open var redoStack = [BlocklyEvent]() {
    didSet {
      redoButton.isEnabled = !redoStack.isEmpty
    }
  }

  /// The pan gesture recognizer attached to the main workspace.
  public var workspacePanGesetureRecognizer: UIPanGestureRecognizer! {
    return workspaceViewController.workspaceView.scrollView.panGestureRecognizer
  }

  /// The tap gesture recognizer attached to the main workspace.
  public private(set) lazy var workspaceTapGestureRecognizer: UITapGestureRecognizer = {
    let tapGesture =
      UITapGestureRecognizer(target: self, action: #selector(didTapWorkspaceView(_:)))
    return tapGesture
  }()

  // MARK: - Initializers

  /**
   Creates the workbench with defaults for `self.engine`, `self.layoutBuilder`,
   `self.viewFactory`.

   - parameter style: The `Style` to use for this laying out items in this view controller.
   */
  public init(style: Style) {
    self.style = style
    self.engine = DefaultLayoutEngine()
    self.layoutBuilder = LayoutBuilder(layoutFactory: LayoutFactory())
    self.blockFactory = BlockFactory()
    self.viewFactory = ViewFactory()
    self.variableNameManager = NameManager()
    self.procedureCoordinator = ProcedureCoordinator()
    super.init(nibName: nil, bundle: nil)
  }

  /**
   Creates the workbench.

   - parameter style: The `Style` to use for this laying out items in this view controller.
   - parameter engine: Value used for `self.layoutEngine`.
   - parameter layoutBuilder: Value used for `self.layoutBuilder`.
   - parameter blockFactory: Value used for `self.blockFactory`.
   - parameter viewFactory: Value used for `self.viewFactory`.
   - parameter variableNameManager: Value used for `self.variableNameManager`.
   - parameter procedureCoordinator: Value used for `self.procedureCoordinator`.
   */
  public init(
    style: Style, engine: LayoutEngine, layoutBuilder: LayoutBuilder, blockFactory: BlockFactory,
    viewFactory: ViewFactory, variableNameManager: NameManager,
    procedureCoordinator: ProcedureCoordinator)
  {
    self.style = style
    self.engine = engine
    self.layoutBuilder = layoutBuilder
    self.blockFactory = blockFactory
    self.viewFactory = viewFactory
    self.variableNameManager = variableNameManager
    self.procedureCoordinator = ProcedureCoordinator()
    super.init(nibName: nil, bundle: nil)
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    // TODO(#52): Support the ability to create view controllers from XIBs.
    // Note: Both the layoutEngine and layoutBuilder need to be initialized somehow.
    fatalError("Called unsupported initializer")
  }

  deinit {
    // Unregister all notifications
    NotificationCenter.default.removeObserver(self)

    // Unregister as a listener for the EventManager, and fire any pending events to
    // effectively clear out events created by this workbench.
    EventManager.shared.removeListener(self)
    EventManager.shared.firePendingEvents()
  }

  // MARK: - Super

  open override func loadView() {
    super.loadView()

    // Set default styles
    workspaceBackgroundColor = ColorPalette.grey.tint50
    undoButton.tintColor = ColorPalette.grey.tint800
    redoButton.tintColor = ColorPalette.grey.tint800
    toolboxCategoryListViewController.categoryFont = UIFont.systemFont(ofSize: 16)
    toolboxCategoryListViewController.unselectedCategoryTextColor = ColorPalette.grey.tint900
    toolboxCategoryListViewController.unselectedCategoryBackgroundColor = ColorPalette.grey.tint300
    toolboxCategoryListViewController.selectedCategoryTextColor = ColorPalette.grey.tint100
    toolboxCategoryViewController.view.backgroundColor =
      ColorPalette.grey.tint300.withAlphaComponent(0.75)
    trashCanViewController.view.backgroundColor =
      ColorPalette.grey.tint300.withAlphaComponent(0.75)

    // Synchronize the procedure coordinator
    procedureCoordinator?.syncWithWorkbench(self)

    view.clipsToBounds = true
    view.autoresizesSubviews = true
    view.autoresizingMask = [.flexibleHeight, .flexibleWidth]

    // Add child view controllers
    addChildViewController(workspaceViewController)
    addChildViewController(trashCanViewController)
    addChildViewController(toolboxCategoryListViewController)
    addChildViewController(toolboxCategoryViewController)

    // Add views
    let viewInfo: [String: Any] = [
      "toolboxCategoriesListView": toolboxCategoryListViewController.view,
      "toolboxCategoryView": toolboxCategoryViewController.view,
      "workspaceView": workspaceViewController.view,
      "trashCanView": trashCanView,
      "trashCanFolderView": trashCanViewController.view,
      "undoButton": undoButton,
      "redoButton": redoButton,
      "topGuide": topLayoutGuide,
      "bottomGuide": bottomLayoutGuide
    ]
    let onlyViews = Array(viewInfo.values).filter({ $0 is UIView }) as! [UIView]
    view.bky_addSubviews(onlyViews)
    view.addSubview(workspaceDragLayerView)

    // Order the subviews from back to front
    view.sendSubview(toBack: workspaceViewController.view)
    view.bringSubview(toFront: trashCanViewController.view)
    view.bringSubview(toFront: toolboxCategoryViewController.view)
    view.bringSubview(toFront: workspaceDragLayerView)
    view.bringSubview(toFront: toolboxCategoryListViewController.view)

    // Set up auto-layout constraints
    let undoRedoButtonSize = CGSize(width: 36, height: 36)
    let iconPadding = CGFloat(25)
    let metrics = [
      "iconPadding": iconPadding,
      "undoRedoButtonWidth": undoRedoButtonSize.width,
      "undoRedoButtonHeight": undoRedoButtonSize.height
    ]
    var constraints = [String]()
    if style == .alternate {
      // Position the button inside the trashCanView to be `(iconPadding, iconPadding)`
      // away from the top-trailing corner.
      trashCanView.setButtonPadding(top: iconPadding, leading: 0, bottom: 0, trailing: iconPadding)
      constraints = [
        // Position the toolbox category list along the bottom margin, and let the workspace view
        // fill the rest of the space
        "H:|[workspaceView]|",
        "H:|[toolboxCategoriesListView]|",
        "V:|[workspaceView][toolboxCategoriesListView]|",
        // Position the toolbox category view above the list view
        "H:|[toolboxCategoryView]|",
        "V:[toolboxCategoryView][toolboxCategoriesListView]",
        // Position the undo/redo buttons along the top-leading margin (horizontal part handled
        // below).
        "H:[undoButton(undoRedoButtonWidth)]",
        "V:[undoButton(undoRedoButtonHeight)]",
        "H:[redoButton(undoRedoButtonWidth)]",
        "V:[redoButton(undoRedoButtonHeight)]",
        "H:[undoButton]-(iconPadding)-[redoButton]",
        "V:[topGuide]-(iconPadding)-[undoButton]",
        "V:[topGuide]-(iconPadding)-[redoButton]",
        // Position the trash can button along the top-trailing margin (horizontal part handled
        // below).
        "V:[topGuide][trashCanView]",
        // Position the trash can folder view on the trailing edge of the view, between the toolbox
        // category view and trash can button
        "H:[trashCanFolderView]|",
        "V:[trashCanView]-(iconPadding)-[trashCanFolderView]-[toolboxCategoryView]",
      ]

      // If possible, create horizontal constraints that respect the safe area. If not, default
      // to using the superview's leading/trailing margins.
      if #available(iOS 11.0, *) {
        undoButton.leadingAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: iconPadding).isActive = true
        trashCanView.trailingAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
      } else {
        constraints.append(contentsOf: [
          "H:|-(iconPadding)-[undoButton]",
          "H:[trashCanView]|"
        ])
      }
    } else {
      // Position the button inside the trashCanView to be `(iconPadding, iconPadding)`
      // away from the bottom-trailing corner.
      trashCanView.setButtonPadding(top: 0, leading: 0, bottom: iconPadding, trailing: iconPadding)
      constraints = [
        // Position the toolbox category list along the leading margin, and let the workspace view
        // fill the rest of the space
        "H:|[toolboxCategoriesListView][workspaceView]|",
        "V:|[toolboxCategoriesListView]|",
        "V:|[workspaceView]|",
        // Position the toolbox category view beside the category list
        "H:[toolboxCategoriesListView][toolboxCategoryView]",
        "V:|[toolboxCategoryView]|",
        // Position the undo/redo buttons along the bottom-leading margin
        "H:[undoButton(undoRedoButtonWidth)]",
        "V:[undoButton(undoRedoButtonHeight)]",
        "H:[redoButton(undoRedoButtonWidth)]",
        "V:[redoButton(undoRedoButtonHeight)]",
        "H:[toolboxCategoriesListView]-(iconPadding)-[undoButton]-(iconPadding)-[redoButton]",
        "V:[undoButton]-(iconPadding)-[bottomGuide]",
        "V:[redoButton]-(iconPadding)-[bottomGuide]",
        // Position the trash can button along the bottom-trailing margin (horizontal part handled
        // below).
        "V:[trashCanView][bottomGuide]",
        // Position the trash can folder view on the bottom of the view, between the toolbox
        // category view and trash can button
        "H:[toolboxCategoryView]-[trashCanFolderView]-(iconPadding)-[trashCanView]",
        "V:[trashCanFolderView]|",
      ]

      // If possible, create horizontal constraints that respect the safe area. If not, default
      // to using the superview's leading/trailing margins.
      if #available(iOS 11.0, *) {
        trashCanView.trailingAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
      } else {
        constraints.append(contentsOf: [
          "H:[trashCanView]|"
        ])
      }
    }

    // Add constraints
    view.bky_addVisualFormatConstraints(constraints, metrics: metrics, views: viewInfo)

    // Attach the block pan gesture recognizer to the entire view (so it can block out any other
    // once touches once its gesture state turns to `.began`).
    let panGesture = BlocklyPanGestureRecognizer(targetDelegate: self)
    panGesture.delegate = self
    view.addGestureRecognizer(panGesture)

    // Signify to view controllers that they've been moved to this parent
    workspaceViewController.didMove(toParentViewController: self)
    trashCanViewController.didMove(toParentViewController: self)
    toolboxCategoryListViewController.didMove(toParentViewController: self)
    toolboxCategoryViewController.didMove(toParentViewController: self)

    // Update workspace view edge insets to account for control overlays
    let controlHeight =
      max(undoButton.image(for: .normal)?.size.height ?? 0,
          redoButton.image(for: .normal)?.size.height ?? 0,
          trashCanView.button.image(for: .normal)?.size.height ?? 0)
    switch style {
    case .defaultStyle:
      workspaceView.scrollIntoViewEdgeInsets =
        EdgeInsets(top: iconPadding, leading: iconPadding, bottom: controlHeight + iconPadding * 2,
                   trailing: iconPadding)
    case .alternate:
      workspaceView.scrollIntoViewEdgeInsets =
        EdgeInsets(top: controlHeight + iconPadding * 2, leading: iconPadding, bottom: iconPadding,
                   trailing: iconPadding)
    }

    // Create a default workspace, if one doesn't already exist
    if workspace == nil {
      do {
        try loadWorkspace(Workspace())
      } catch let error {
        bky_print("Could not create a default workspace: \(error)")
      }
    }

    // Register for keyboard notifications
    NotificationCenter.default.addObserver(
      self, selector: #selector(keyboardWillShowNotification(_:)),
      name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(keyboardWillHideNotification(_:)),
      name: NSNotification.Name.UIKeyboardWillHide, object: nil)

    // Clear out any pending events first. We only care about events moving forward.
    EventManager.shared.firePendingEvents()

    // Listen for Blockly events
    EventManager.shared.addListener(self)
  }

  open override func viewDidLoad() {
    super.viewDidLoad()

    // Hide/show trash can
    setTrashCanViewVisible(enableTrashCan)

    refreshView()
  }

  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Enable/disable the pop gesture recognizer
    _wasInteractivePopGestureRecognizerEnabled = interactivePopGestureRecognizerEnabled()
    setInteractivePopGestureRecognizerEnabled(allowInteractivePopGestureRecognizer)
  }

  open override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // Set the pop gesture recognizer to the state as it existed prior to this view controller
    // appearing.
    setInteractivePopGestureRecognizerEnabled(_wasInteractivePopGestureRecognizerEnabled)

    // Reset all existing drags.
    _dragger.cancelAllDrags()
  }

  // MARK: - Public

  /**
   Automatically creates a `WorkspaceLayout` and `WorkspaceLayoutCoordinator` for a given workspace
   (using both the `self.engine` and `self.layoutBuilder` instances). The workspace is then
   rendered into the view controller.

   - note: All blocks in `workspace` must have corresponding `BlockBuilder` objects in
   `self.blockFactory`, based on their associated block name. This is needed for things like
   handling undo/redo and automatic creation of variable blocks.
   - note: A `ConnectionManager` is automatically created for the `WorkspaceLayoutCoordinator`.
   - parameter workspace: The `Workspace` to load
   - throws:
   `BlocklyError`: Thrown if an associated `WorkspaceLayout` could not be created for the workspace,
   or if no corresponding `BlockBuilder` could be found in `self.blockFactory` for at least one of
   the blocks in `workspace`.
   */
  open func loadWorkspace(_ workspace: Workspace) throws {
    try loadWorkspace(workspace, connectionManager: ConnectionManager())
  }

  /**
   Automatically creates a `WorkspaceLayout` and `WorkspaceLayoutCoordinator` for a given workspace
   (using both the `self.engine` and `self.layoutBuilder` instances). The workspace is then
   rendered into the view controller.

   - note: All blocks in `workspace` must have corresponding `BlockBuilder` objects in
   `self.blockFactory`, based on their associated block name. This is needed for things like
   handling undo/redo and automatic creation of variable blocks.
   - parameter workspace: The `Workspace` to load
   - parameter connectionManager: A `ConnectionManager` to track connections in the workspace.
   - throws:
   `BlocklyError`: Thrown if an associated `WorkspaceLayout` could not be created for the workspace,
   or if no corresponding `BlockBuilder` could be found in `self.blockFactory` for at least one of
   the blocks in `workspace`.
   */
  open func loadWorkspace(_ workspace: Workspace, connectionManager: ConnectionManager) throws {
    // Verify all blocks in the workspace can be re-created from the block factory
    try verifyBlockBuilders(forBlocks: Array(workspace.allBlocks.values))

    // Create a layout for the workspace, which is required for viewing the workspace
    let workspaceLayout = WorkspaceLayout(workspace: workspace, engine: engine)
    let aConnectionManager = connectionManager
    _workspaceLayoutCoordinator =
      try WorkspaceLayoutCoordinator(workspaceLayout: workspaceLayout,
                                     layoutBuilder: layoutBuilder,
                                     connectionManager: aConnectionManager)

    // Now that the workspace has changed, the procedure coordinator needs to get re-synced to
    // reflect any new blocks in the workspace.
    // TODO(#61): As part of the refactor of WorkbenchViewController, this can potentially be
    // moved into a listener so no explicit call to syncWithWorkbench() is made
    procedureCoordinator?.syncWithWorkbench(self)

    refreshView()

    // Automatically change the viewport to show the top-leading part of the workspace.
    setViewport(to: .topLeading, animated: false)

    // Fire any events that were created as a result of loading a new workspace.
    EventManager.shared.firePendingEvents()
  }

  /**
   Automatically creates a `ToolboxLayout` for a given `Toolbox` (using both the `self.engine`
   and `self.layoutBuilder` instances) and loads it into the view controller.

   - note: All blocks defined by categories in `toolbox` must have corresponding
   `BlockBuilder` objects in `self.blockFactory`, based on their associated block name. This is
   needed for things like handling undo/redo and automatic creation of variable blocks.
   - parameter toolbox: The `Toolbox` to load
   - throws:
   `BlocklyError`: Thrown if an associated `ToolboxLayout` could not be created for the toolbox,
   or if no corresponding `BlockBuilder` could be found in `self.blockFactory` for at least one of
   the blocks specified in`toolbox`.
   */
  open func loadToolbox(_ toolbox: Toolbox) throws {
    // Verify all blocks in the toolbox can be re-created from the block factory
    let allToolboxBlocks = toolbox.categories.flatMap({ $0.allBlocks.values })
    try verifyBlockBuilders(forBlocks: allToolboxBlocks)

    let toolboxLayout = ToolboxLayout(
      toolbox: toolbox, engine: engine, layoutDirection: style.toolboxCategoryLayoutDirection,
      layoutBuilder: layoutBuilder)
    _toolboxLayout = toolboxLayout
    _toolboxLayout?.setBlockFactory(blockFactory)

    // Now that the toolbox has changed, the procedure coordinator needs to get re-synced to
    // reflect any new blocks in the toolbox.
    // TODO(#61): As part of the refactor of WorkbenchViewController, this can potentially be
    // moved into a listener so no explicit call to syncWithWorkbench() is made
    procedureCoordinator?.syncWithWorkbench(self)

    refreshView()

    // Fire any events that were created as a result of loading a new toolbox.
    EventManager.shared.firePendingEvents()
  }

  /**
   Refreshes the UI based on the current version of `self.workspace` and `self.toolbox`.
   */
  open func refreshView() {
    do {
      try workspaceViewController.loadWorkspaceLayoutCoordinator(_workspaceLayoutCoordinator)
    } catch let error {
      bky_assertionFailure("Could not load workspace layout: \(error)")
    }

    toolboxCategoryListViewController.toolboxLayout = _toolboxLayout
    toolboxCategoryListViewController.refreshView()

    toolboxCategoryViewController.toolboxLayout = _toolboxLayout

    // Set the state to the default empty state
    refreshUIState([])
    updateWorkspaceCapacity()
  }

  // MARK: - Private

  /**
   Method called by a gesture recognizer when the main workspace area has been panned.

   - parameter gesture: The `UIPanGestureRecognizer` that fired the method.
   */
  @objc private dynamic func didPanWorkspaceView(_ gesture: UIPanGestureRecognizer) {
    addUIStateValue(stateDidPanWorkspace)
  }

  /**
   Method called by a gesture recognizer when the main workspace area has been tapped.

   - parameter gesture: The `UITapGestureRecognizer` that fired the method.
   */
  @objc private dynamic func didTapWorkspaceView(_ gesture: UITapGestureRecognizer) {
    addUIStateValue(stateDidTapWorkspace)
  }

  /**
   Updates the trash can and toolbox so the user may only interact with block groups that
   would not exceed the workspace's remaining capacity.
   */
  fileprivate func updateWorkspaceCapacity() {
    if let capacity = _workspaceLayout?.workspace.remainingCapacity {
      trashCanViewController.workspace?.deactivateBlockTrees(forGroupsGreaterThan: capacity)
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
  fileprivate func copyBlockView(_ blockView: BlockView) throws -> BlockView
  {
    // TODO(#57): When this operation is being used as part of a "copy-and-delete" operation, it's
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
    let newBlock = try workspaceLayoutCoordinator.copyBlockTree(
      blockLayout.block, editable: true, position: newWorkspacePosition)

    // Because there are listeners on the layout hierarchy to update the corresponding view
    // hierarchy when layouts change, we just need to find the view that was automatically created.
    guard
      let newBlockLayout = newBlock.layout,
      let newBlockView = ViewManager.shared.findBlockView(forLayout: newBlockLayout) else
    {
      throw BlocklyError(.viewNotFound, "View could not be located for the copied block")
    }

    return newBlockView
  }

  /**
   Given a list of blocks, verifies that each block has a corresponding `BlockBuilder` in
   `self.blockFactory`, based on the block's name.

   - parameter blocks: List of blocks to check.
   - throws:
   `BlocklyError`: Thrown if one or more of the blocks is missing a corresponding `BlockBuilder`
   in `self.blockFactory`.
   */
  fileprivate func verifyBlockBuilders(forBlocks blocks: [Block]) throws {
    let names = blocks.map({ $0.name })
        .filter({ self.blockFactory.blockBuilder(forName: $0) == nil })

    if !names.isEmpty {
      throw BlocklyError(.illegalState,
        "Missing `BlockBuilder` in `self.blockFactory` for the following block names: \n" +
        "'\(Array(Set(names)).sorted().joined(separator: "', '"))'")
    }
  }
}

// MARK: - State Handling

extension WorkbenchViewController {
  /**
   Creates a new `UIStateValue`. Subclasses may call this to create additional state values that
   should be handled by `WorkbenchViewController`.

   - returns: A unique `UIStateValue`.
   */
  public static func newUIStateValue() -> UIStateValue {
    let key = numberOfUIStateValues
    numberOfUIStateValues += 1
    return key
  }

  /**
   Adds an individual UI state value to the current state of the workbench. Generally, this call
   should be matched by a future call to `removeUIStateValue(_:animated:)`.

   - parameter stateValue: The `UIStateValue` to add to `self.state`.
   - parameter animated: `true` if changes in UI state should be animated. `false`, if not.
   - see: To change the behavior of how the state value is added to the current state, see
   `WorkbenchViewControllerDelegate.workbenchViewController(_:shouldKeepStates:forStateValue:)`.
   */
  public func addUIStateValue(_ stateValue: UIStateValue, animated: Bool = true) {
    // Make a list of states to keep when the state is added.
    var keepStates = Set<UIStateValue>()

    if toolboxDrawerStaysOpen && self.state.contains(stateCategoryOpen) {
      // Always keep `stateCategoryOpen` if it existed before
      keepStates.insert(stateCategoryOpen)
    }

    switch stateValue {
    case stateDraggingBlock:
      // Dragging a block can only co-exist with highlighting the trash can
      keepStates.insert(stateTrashCanHighlighted)
    case stateTrashCanHighlighted:
      // This state can co-exist with anything, keep all states.
      keepStates.formUnion(state)
    case stateEditingTextField:
      // Allow `stateEditingTextField` to co-exist with `statePresentingPopover` and
      // `stateCategoryOpen`, but nothing else
      keepStates.insert(statePresentingPopover)
      keepStates.insert(stateCategoryOpen)
    case statePresentingPopover:
      // If `stateCategoryOpen` already existed, continue to let it exist (as users may want to
      // modify blocks from inside the toolbox). Disallow everything else.
      keepStates.insert(stateCategoryOpen)
    case stateDidPanWorkspace, stateDidTapWorkspace, stateCategoryOpen, stateTrashCanOpen:
      // These states are all exclusive. Don't keep anything else.
      break
    default:
      // This is a custom defined state. Let a delegate method handle what states should be kept.
      break
    }

    // Allow a delegate method to override what states are kept
    if let delegateKeepStates = delegate?.workbenchViewController?(self,
                                                                   shouldKeepStates: keepStates,
                                                                   forStateValue: stateValue) {
      keepStates = delegateKeepStates
    }

    // Keep any relevant states from the existing state, and append the new state value.
    let newState = self.state.intersection(keepStates).union([stateValue])
    refreshUIState(newState, animated: animated)
  }

  /**
   Removes a UI state value from the current state of the workbench. This call should have matched
   a previous call to `addUIStateValue(_:animated:)`.

   - parameter stateValue: The `UIStateValue` to remove from `self.state`.
   - parameter animated: `true` if changes in UI state should be animated. `false`, if not.
   */
  public func removeUIStateValue(_ stateValue: UIStateValue, animated: Bool = true) {
    // When subtracting a state value, there is no need to check for compatibility.
    // Simply set the new state, minus the given state value.
    let newState = self.state.subtracting([stateValue])
    refreshUIState(newState, animated: animated)
  }

  /**
   Refreshes the UI based on a set of states.

   - parameter state: The `WorkbenchViewController.UIState` to set.
   - parameter animated: `true` if changes in UI state should be animated. `false`, if not.
   */
  fileprivate func refreshUIState(_ state: UIState, animated: Bool = true) {
    self.state = state

    setTrashCanFolderVisible(state.contains(stateTrashCanOpen), animated: animated)

    trashCanView.setHighlighted(state.contains(stateTrashCanHighlighted), animated: animated)

    if let selectedCategory = toolboxCategoryListViewController.selectedCategory,
      state.contains(stateCategoryOpen) {
      // Show the toolbox category
      toolboxCategoryViewController.showCategory(selectedCategory, animated: animated)
    } else {
      // Hide the toolbox category
      toolboxCategoryViewController.hideCategory(animated: animated)
      toolboxCategoryListViewController.selectedCategory = nil
    }

    if !state.contains(stateEditingTextField) {
      // Force all child text fields to end editing (which essentially dismisses the keyboard if
      // it's currently visible)
      self.view.endEditing(true)
    }

    if !state.contains(statePresentingPopover),
      let presentedViewController = self.presentedViewController,
      !presentedViewController.isBeingDismissed {
      presentedViewController.dismiss(animated: animated, completion: nil)
    }

    // Always allow undo/redo except when blocks are being dragged, text fields are being edited,
    // or a popover is being shown.
    setUndoRedoUserInteractionEnabled(!(
      state.contains(stateDraggingBlock) ||
      state.contains(stateEditingTextField) ||
      state.contains(statePresentingPopover)))

    // Notify the delegate so it can make more changes.
    delegate?.workbenchViewController(self, didUpdateState: state)
  }
}

// MARK: - Trash Can

extension WorkbenchViewController {
  /**
   Event that is fired when the trash can is tapped on.

   - parameter sender: The trash can button that sent the event.
   */
  @objc fileprivate dynamic func didTapTrashCan(_ sender: UIButton) {
    // Toggle trash can visibility
    if !_trashCanVisible && keepTrashedBlocks {
      addUIStateValue(stateTrashCanOpen)
    } else {
      removeUIStateValue(stateTrashCanOpen)
    }
  }

  fileprivate func setTrashCanViewVisible(_ visible: Bool) {
    trashCanView.isHidden = !visible
  }

  fileprivate func setTrashCanFolderVisible(_ visible: Bool, animated: Bool) {
    if _trashCanVisible == visible {
      return
    }

    let size: CGFloat = visible ? 300 : 0
    if style == .defaultStyle {
      trashCanViewController.setWorkspaceViewHeight(size, animated: animated)
    } else {
      trashCanViewController.setWorkspaceViewWidth(size, animated: animated)
    }
    _trashCanVisible = visible
  }

  fileprivate func isGestureTouchingTrashCan(_ gesture: BlocklyPanGestureRecognizer) -> Bool {
    if !trashCanView.isHidden {
      return gesture.isTouchingView(trashCanView)
    }

    return false
  }

  fileprivate func isTouchTouchingTrashCan(_ touchPosition: CGPoint, fromView: UIView?) -> Bool {
    if !trashCanView.isHidden {
      let trashSpacePosition = trashCanView.convert(touchPosition, from: fromView)
      return trashCanView.bounds.contains(trashSpacePosition)
    }

    return false
  }
}

// MARK: - EventManagerListener Implementation

extension WorkbenchViewController: EventManagerListener {
  open func eventManager(_ eventManager: EventManager, didFireEvent event: BlocklyEvent) {
    guard shouldRecordEvents && allowUndoRedo else {
      return
    }

    if event.workspaceID == workspace?.uuid {
      // Try to merge this event with the last one in the undo stack
      if let lastEvent = undoStack.last,
        let mergedEvent = lastEvent.merged(withNextChronologicalEvent: event) {
        undoStack.removeLast()

        if !mergedEvent.isDiscardable() {
          undoStack.append(mergedEvent)
        }
      } else {
        // Couldn't merge event with last one, just append it
        undoStack.append(event)
      }

      // Clear the redo stack now since a new event has been added to the undo stack
      redoStack.removeAll()
    }
  }
}

// MARK: - Undo / Redo

extension WorkbenchViewController {
  fileprivate func setUndoRedoUserInteractionEnabled(_ enabled: Bool) {
    if (undoButton.isUserInteractionEnabled && !enabled) ||
      (!undoButton.isUserInteractionEnabled && enabled)
    {
      undoButton.isUserInteractionEnabled = enabled
      redoButton.isUserInteractionEnabled = enabled

      UIView.animate(withDuration: 0.3) {
        self.undoButton.alpha = enabled ? 1 : 0.3
        self.redoButton.alpha = enabled ? 1 : 0.3
      }
    }
  }

  @objc fileprivate dynamic func didTapUndoButton(_ sender: UIButton) {
    guard !undoStack.isEmpty else {
      return
    }

    // Don't listen to any events, to avoid echoing
    shouldRecordEvents = false

    // Pop off the next group of events from the undo stack. These events will already be sorted
    // in the order which they should be played (reverse chronological order).
    let events = popGroupedEvents(fromStack: &undoStack)

    // Run each event in order
    for event in events {
      update(fromEvent: event, runForward: false)
    }

    // Add events back to redo stack
    redoStack.append(contentsOf: events)

    // Fire pending events before listening to events again, in case outside listeners need to
    // update their state from those events.
    EventManager.shared.firePendingEvents()

    // Listen to events again
    shouldRecordEvents = true
  }

  @objc fileprivate dynamic func didTapRedoButton(_ sender: UIButton) {
    guard !redoStack.isEmpty else {
      return
    }

    // Don't listen to any events, to avoid echoing
    shouldRecordEvents = false

    // Pop off the next group of events from the redo stack. These events will already be sorted
    // in the order which they should be played (chronological order).
    let events = popGroupedEvents(fromStack: &redoStack)

    // Run each event in order
    for event in events {
      update(fromEvent: event, runForward: true)
    }

    // Add events back to undo stack
    undoStack.append(contentsOf: events)

    // Fire pending events before listening to events again, in case outside listeners need to
    // update their state from those events.
    EventManager.shared.firePendingEvents()

    // Listen to events again
    shouldRecordEvents = true
  }
}

// MARK: - Events

extension WorkbenchViewController {

  /**
   Updates the workbench based on a `BlocklyEvent`.

   - parameter event: The `BlocklyEvent`.
   - parameter runForward: Flag determining if the event should be run forward (`true` for redo
   operations) or run backward (`false` for undo operations).
   */
  open func update(fromEvent event: BlocklyEvent, runForward: Bool) {
    if let createEvent = event as? BlocklyEvent.Create {
      update(fromCreateEvent: createEvent, runForward: runForward)
    } else if let deleteEvent = event as? BlocklyEvent.Delete {
      update(fromDeleteEvent: deleteEvent, runForward: runForward)
    } else if let moveEvent = event as? BlocklyEvent.Move {
      update(fromMoveEvent: moveEvent, runForward: runForward)
    } else if let changeEvent = event as? BlocklyEvent.Change {
      update(fromChangeEvent: changeEvent, runForward: runForward)
    }
  }

  /**
   Updates the workbench based on a `BlocklyEvent.Create`.

   - parameter event: The `BlocklyEvent.Create`.
   - parameter runForward: Flag determining if the event should be run forward (`true` for redo
   operations) or run backward (`false` for undo operations).
   */
  open func update(fromCreateEvent event: BlocklyEvent.Create, runForward: Bool) {
    if runForward {
      do {
        let blockTree = try Block.blockTree(fromXMLString: event.xml, factory: blockFactory)
        try _workspaceLayoutCoordinator?.addBlockTree(blockTree.rootBlock)
      } catch let error {
        bky_assertionFailure("Could not re-create block from event: \(error)")
      }
    } else {
      for blockID in event.blockIDs {
        if let block = workspace?.allBlocks[blockID] {
          try? _workspaceLayoutCoordinator?.removeBlockTree(block)
        }
      }
    }
  }

  /**
   Updates the workbench based on a `BlocklyEvent.Delete`.

   - parameter event: The `BlocklyEvent.Delete`.
   - parameter runForward: Flag determining if the event should be run forward (`true` for redo
   operations) or run backward (`false` for undo operations).
   */
  open func update(fromDeleteEvent event: BlocklyEvent.Delete, runForward: Bool) {
    if runForward {
      for blockID in event.blockIDs {
        if let block = workspace?.allBlocks[blockID] {
          var allBlocksToRemove = block.allBlocksForTree()
          try? _workspaceLayoutCoordinator?.removeBlockTree(block)
          addBlockToTrash(block)
          allBlocksToRemove.removeAll()
        }
      }
    } else {
      do {
        let blockTree = try Block.blockTree(fromXMLString: event.oldXML, factory: blockFactory)
        try _workspaceLayoutCoordinator?.addBlockTree(blockTree.rootBlock)

        if let trashBlock = trashCanViewController.workspace?.allBlocks[blockTree.rootBlock.uuid]
        {
          // Remove this block from the trash can
          try trashCanViewController.workspaceLayoutCoordinator?.removeBlockTree(trashBlock)
        }
      } catch let error {
        bky_assertionFailure("Could not re-create block from event: \(error)")
      }
    }
  }

  /**
   Updates the workbench based on a `BlocklyEvent.Move`.

   - parameter event: The `BlocklyEvent.Move`.
   - parameter runForward: Flag determining if the event should be run forward (`true` for redo
   operations) or run backward (`false` for undo operations).
   */
  open func update(fromMoveEvent event: BlocklyEvent.Move, runForward: Bool) {
    guard let workspace = _workspaceLayoutCoordinator?.workspaceLayout.workspace,
      let blockID = event.blockID,
      let block = workspace.allBlocks[blockID] else
    {
      // Block may have been deleted (through a real-time event), so simply print an error.
      bky_debugPrint("Can't move non-existent block: \(event.blockID ?? "")")
      return
    }

    let parentID = runForward ? event.newParentID : event.oldParentID
    let inputName = runForward ? event.newInputName : event.oldInputName
    let position = runForward ? event.newPosition : event.oldPosition

    if let parentID = parentID, workspace.allBlocks[parentID] == nil {
      // Parent block may have been deleted (through a real-time event), so simply print an error.
      bky_debugPrint("Can't connect to non-existent parent block: \(parentID)")
      return
    }

    // Check current parent of block
    if let inferiorConnection = block.inferiorConnection {
      if let currentParent = inferiorConnection.targetBlock,
        currentParent.uuid == parentID,
        inferiorConnection.targetConnection?.sourceInput?.name == inputName
      {
        // No-op: The block is already connected to the target connection.
        return
      } else {
        do {
          // Disconnect the block from current parent
          try _workspaceLayoutCoordinator?.disconnect(inferiorConnection)
        } catch let error {
          bky_assertionFailure("Could not disconnect block from its parent: \(error)")
          return
        }
      }
    }

    if let position = position,
      let blockLayout = block.layout
    {
      // Move to new workspace position
      blockLayout.rootBlockGroupLayout?.move(toWorkspacePosition: position)
    } else if let inferiorConnection = block.inferiorConnection,
      let parentID = parentID,
      let parentBlock = workspace.allBlocks[parentID]
    {
      // Find target connection on parent block
      var parentConnection: Connection?
      if let inputName = inputName {
        if let input = parentBlock.firstInput(withName: inputName) {
          parentConnection = input.connection
        }
      } else if inferiorConnection.type == .previousStatement {
        parentConnection = parentBlock.nextConnection
      }

      // Connect block to parent block
      if let parentConnection = parentConnection {
        do {
          try _workspaceLayoutCoordinator?.connect(inferiorConnection, parentConnection)
        } catch let error {
          bky_assertionFailure("Could not connect block: \(error)")
        }
      } else {
        // Parent connection may no longer exist (through a real-time event), so simply print an
        // error.
        bky_debugPrint("Can't connect to non-existent parent connection")
      }
    }
  }

  /**
   Updates the workbench based on a `BlocklyEvent.Change`.

   - parameter event: The `BlocklyEvent.Change`.
   - parameter runForward: Flag determining if the event should be run forward (`true` for redo
   operations) or run backward (`false` for undo operations).
   */
  open func update(fromChangeEvent event: BlocklyEvent.Change, runForward: Bool) {
    guard let workspace = _workspaceLayoutCoordinator?.workspaceLayout.workspace,
      let blockID = event.blockID,
      let block = workspace.allBlocks[blockID] else
    {
      bky_debugPrint("Can't change non-existent block: \(event.blockID ?? "")")
      return
    }

    let value = (runForward ? event.newValue : event.oldValue) ?? ""
    let boolValue = runForward ? event.newBoolValue : event.oldBoolValue
    let element = event.element

    if element == BlocklyEvent.Change.elementComment {
      block.layout?.comment = value
    } else if element == BlocklyEvent.Change.elementDisabled {
      block.layout?.disabled = boolValue
    } else if element == BlocklyEvent.Change.elementField {
      if let fieldName = event.fieldName,
        let field = block.firstField(withName: fieldName)
      {
        do {
          try field.layout?.setValue(fromSerializedText: value)
        } catch let error {
          bky_assertionFailure(
            "Couldn't set value(\"\(value)\") for field(\"\(fieldName)\"):\n\(error)")
        }
      } else {
        bky_assertionFailure("Can't set non-existent field: \(event.fieldName ?? "")")
      }
    } else if element == BlocklyEvent.Change.elementInline {
      block.layout?.inputsInline = boolValue
    } else if element == BlocklyEvent.Change.elementMutate {
      do {
        // Update the mutator from xml
        let mutatorLayout = block.mutator?.layout
        let xml = try AEXMLDocument(xml: value)
        try mutatorLayout?.performMutation(fromXML: xml)
      } catch let error {
        bky_assertionFailure("Can't update mutator from xml [\"\(value)\"]:\n\(error)")
      }
    }
  }

  /**
   Pops a group of events from the end of a stack of events and returns them in the order they
   were popped off the stack.

   If the top of the stack contains an event with a group ID, this method will pop off all
   events that match that group ID.
   If the top of the stack contains an event without a group ID, only that event is popped off.

   - parameter stack: The stack of events.
   - returns: An array of grouped events, sorted in the order they were popped off the stack.
   */
  fileprivate func popGroupedEvents(fromStack stack: inout [BlocklyEvent]) -> [BlocklyEvent] {
    var events = [BlocklyEvent]()

    if let lastEvent = stack.popLast() {
      events.append(lastEvent)

      // If this event was part of a group, get all other events part of this group
      if let groupID = lastEvent.groupID {
        while let event = stack.last,
          event.groupID == groupID
        {
          stack.removeLast()
          events.append(event)
        }
      }
    }

    return events
  }
}

// MARK: - WorkspaceViewControllerDelegate

extension WorkbenchViewController: WorkspaceViewControllerDelegate {
  open func workspaceViewController(
    _ workspaceViewController: WorkspaceViewController,
    didAddBlockView blockView: BlockView) {
    if workspaceViewController == self.workspaceViewController {
      addGestureTracking(forBlockView: blockView)
      updateWorkspaceCapacity()
    }
  }

  open func workspaceViewController(
    _ workspaceViewController: WorkspaceViewController,
    didRemoveBlockView blockView: BlockView) {
    if workspaceViewController == self.workspaceViewController {
      removeGestureTracking(forBlockView: blockView)
      updateWorkspaceCapacity()
    }
  }

  open func workspaceViewController(
    _ workspaceViewController: WorkspaceViewController,
    willPresentViewController viewController: UIViewController) {
    addUIStateValue(statePresentingPopover)
  }

  open func workspaceViewControllerDismissedViewController(
    _ workspaceViewController: WorkspaceViewController) {
    removeUIStateValue(statePresentingPopover)
  }
}

// MARK: - Block Copying

extension WorkbenchViewController {
  /**
   Copies the specified block from a flyout (trash/toolbox) to the workspace.

   - parameter blockView: The `BlockView` to copy
   - returns: The new `BlockView`
   */
  public func copyBlockToWorkspace(_ blockView: BlockView) -> BlockView? {
    // The block the user is dragging out of the toolbox/trash may be a child of a large nested
    // block. We want to do a deep copy on the root block (not just the current block).
    guard let rootBlockLayout = blockView.blockLayout?.rootBlockGroupLayout?.blockLayouts[0],
      // TODO(#45): This should be copying the root block layout, not the root block view.
      let rootBlockView = ViewManager.shared.findBlockView(forLayout: rootBlockLayout)
      else
    {
      return nil
    }

    // Copy the block view into the workspace view
    let newBlockView: BlockView
    do {
      newBlockView = try copyBlockView(rootBlockView)
    } catch let error {
      bky_assertionFailure("Could not copy toolbox block view into workspace view: \(error)")
      return nil
    }

    return newBlockView
  }

  /**
   Adds a copy of a given block to the trash.

   - note: If `keepTrashedBlocks` is set to `false`, this method does nothing.
   - parameter block: The `Block` to add to the trash.
   */
  public func addBlockToTrash(_ block: Block) {
    guard keepTrashedBlocks else { return }

    do {
      _ = try trashCanViewController.workspaceLayoutCoordinator?.addBlockTree(block)
    } catch let error {
      bky_assertionFailure("Could not add block to trash: \(error)")
    }
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

    if let trashWorkspace = trashCanViewController.workspaceView.workspaceLayout?.workspace
      , trashWorkspace.containsBlock(rootBlockLayout.block)
    {
      do {
        // Remove this block view from the trash can
        try trashCanViewController.workspace?.removeBlockTree(rootBlockLayout.block)
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
   Adds custom gesture recognizers to a block view. It is automatically called by
   `WorkbenchViewController` when a block view is added to the workspace.

   Subclasses may override this to add custom gesture tracking to a block view.
   The default implementation does nothing.

   - parameter blockView: A given block view.
   */
  open func addGestureTracking(forBlockView blockView: BlockView) {
  }

  /**
   Removes all gesture recognizers and any on-going gesture data from a block view.

   - parameter blockView: A given block view.
   */
  open func removeGestureTracking(forBlockView blockView: BlockView) {
    blockView.bky_removeAllGestureRecognizers()

    if let blockLayout = blockView.blockLayout {
      _dragger.cancelDraggingBlockLayout(blockLayout)
    }
  }
}

// MARK: - UIKeyboard notifications

extension WorkbenchViewController {
  @objc fileprivate dynamic func keyboardWillShowNotification(_ notification: Notification) {
    addUIStateValue(stateEditingTextField)

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

  @objc fileprivate dynamic func keyboardWillHideNotification(_ notification: Notification) {
    removeUIStateValue(stateEditingTextField)

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
    addUIStateValue(stateCategoryOpen, animated: true)
  }

  public func toolboxCategoryListViewControllerDidDeselectCategory(
    _ controller: ToolboxCategoryListViewController)
  {
    removeUIStateValue(stateCategoryOpen, animated: true)
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
  /**
   Automatically adjusts the workspace's scroll view to bring a given `Block` into view.

   - parameter block: The `Block` to bring into view.
   - parameter location: The area of the screen where the block should appear. If `.anywhere`
   is specified, the viewport is changed the minimal amount necessary to bring the block
   into view.
   - parameter animated: Flag determining if this scroll view adjustment should be animated.
   */
  public func scrollBlockIntoView(
    blockUUID: String, location: WorkspaceView.Location = .anywhere, animated: Bool) {
    guard let block = workspace?.allBlocks[blockUUID] else {
        return
    }

    // Always perform this method at the end of the run loop, in order to ensure views have first
    // been created/positioned in the scroll view. This fixes a problem where attempting
    // to scroll blocks into the view, immediately after the workspace has loaded, does not work.
    DispatchQueue.main.async {
      self.workspaceView.scrollBlockIntoView(block, location: location, animated: animated)
    }
  }

  /**
   Sets the content offset of the workspace's scroll view so that a specific location in the
   workspace is visible.

   - parameter location: The `Location` that should be made visible. If `.anywhere` is specified,
   this method does nothing.
   - parameter animated: Flag determining if this scroll view adjustment should be animated.
   */
  public func setViewport(to location: WorkspaceView.Location, animated: Bool) {
    // Always perform this method at the end of the run loop, in order to ensure views have first
    // been created/positioned in the scroll view. This fixes a problem where attempting
    // to scroll blocks into the view, immediately after the workspace has loaded, does not work.
    DispatchQueue.main.async {
      self.workspaceView.setViewport(to: location, animated: animated)
    }
  }
}

// MARK: - BlocklyPanGestureRecognizerDelegate

extension WorkbenchViewController: BlocklyPanGestureRecognizerDelegate {
  /**
   Pan gesture event handler for a block view inside `self.workspaceView`.
   */
  open func blocklyPanGestureRecognizer(
    _ gesture: BlocklyPanGestureRecognizer, didTouchBlock block: BlockView,
    touch: UITouch, touchState: BlocklyPanGestureRecognizer.TouchState)
  {
    guard let blockLayout = block.blockLayout?.draggableBlockLayout else {
      return
    }

    var blockView = block
    let touchPosition = touch.location(in: workspaceView.scrollView)
    let workspacePosition = workspaceView.workspacePosition(fromViewPoint: touchPosition)

    // TODO(#44): Handle screen rotations (either lock the screen during drags or stop any
    // on-going drags when the screen is rotated).

    if touchState == .began {
      if EventManager.shared.currentGroupID == nil {
        EventManager.shared.pushNewGroup()
      }

      let inToolbox = blockView.bky_isDescendant(of: toolboxCategoryViewController.view)
      let inTrash = blockView.bky_isDescendant(of: trashCanViewController.view)
      // If the touch is in the toolbox, copy the block over to the workspace first.
      if inToolbox {
        guard let newBlock = copyBlockToWorkspace(blockView) else {
          return
        }
        gesture.replaceBlock(block, with: newBlock)
        blockView = newBlock

        if !toolboxDrawerStaysOpen {
          removeUIStateValue(stateCategoryOpen, animated: false)
        }
      } else if inTrash {
        let oldBlock = blockView

        guard let newBlock = copyBlockToWorkspace(blockView) else {
          return
        }
        gesture.replaceBlock(block, with: newBlock)
        blockView = newBlock
        removeBlockFromTrash(oldBlock)

        removeUIStateValue(stateTrashCanOpen, animated: false)
      }

      guard let blockLayout = blockView.blockLayout?.draggableBlockLayout else {
        return
      }

      addUIStateValue(stateDraggingBlock)
      do {
        try _dragger.startDraggingBlockLayout(blockLayout, touchPosition: workspacePosition)
      } catch let error {
        bky_assertionFailure("Could not start dragging block layout: \(error)")

        // This shouldn't happen in practice. Cancel the gesture to be safe.
        gesture.cancelAllTouches()
      }
    } else if touchState == .changed || touchState == .ended {
      addUIStateValue(stateDraggingBlock)
      _dragger.continueDraggingBlockLayout(blockLayout, touchPosition: workspacePosition)

      if isGestureTouchingTrashCan(gesture) && blockLayout.block.deletable {
        addUIStateValue(stateTrashCanHighlighted)
      } else {
        removeUIStateValue(stateTrashCanHighlighted)
      }
    }

    if (touchState == .ended || touchState == .cancelled) && _dragger.numberOfActiveDrags > 0 {
      let touchTouchingTrashCan = isTouchTouchingTrashCan(touchPosition,
        fromView: workspaceView.scrollView)
      if touchState == .ended && touchTouchingTrashCan && blockLayout.block.deletable {
        // This block is being "deleted" -- cancel the drag and copy the block into the trash can
        _dragger.cancelDraggingBlockLayout(blockLayout)

        do {
          // Keep a reference of all blocks that are getting transferred over so they don't go
          // out of memory.
          var allBlocksToRemove = blockLayout.block.allBlocksForTree()

          try _workspaceLayoutCoordinator?.removeBlockTree(blockLayout.block)

          // Enable the entire block tree, before adding it to the trash can.
          for block in blockLayout.block.allBlocksForTree() {
            block.disabled = false
          }

          addBlockToTrash(blockLayout.block)

          allBlocksToRemove.removeAll()
        } catch let error {
          bky_assertionFailure("Could not copy block to trash can: \(error)")
        }
      } else {
        _dragger.finishDraggingBlockLayout(blockLayout)
      }

      if _dragger.numberOfActiveDrags == 0 {
        // Update the UI state
        removeUIStateValue(stateDraggingBlock)
        if !isGestureTouchingTrashCan(gesture) {
          removeUIStateValue(stateTrashCanHighlighted)
        }

        EventManager.shared.popGroup()
      }

      // Always fire pending events after a finger has been lifted. All grouped events will
      // eventually get grouped together regardless if they were fired in batches.
      EventManager.shared.firePendingEvents()
    }
  }
}

// MARK: - UIGestureRecognizerDelegate

extension WorkbenchViewController: UIGestureRecognizerDelegate {
  open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

    if workspaceViewController.workspaceView.scrollView.isInMotion ||
      toolboxCategoryViewController.workspaceScrollView.isInMotion ||
      trashCanViewController.workspaceView.scrollView.isInMotion {
      return false
    }

    if let panGestureRecognizer = gestureRecognizer as? BlocklyPanGestureRecognizer,
      let firstTouch = panGestureRecognizer.firstTouch,
      let toolboxView = toolboxCategoryViewController.view,
      toolboxView.bounds.contains(firstTouch.previousLocation(in: toolboxView))
    {
      // For toolbox blocks, only fire the pan gesture if the user is panning in the direction
      // perpendicular to the toolbox scrolling. Otherwise, don't let it fire, so the user can
      // simply continue scrolling the toolbox.
      let delta = panGestureRecognizer.firstTouchDelta(inView: toolboxView)

      // Figure out angle of delta vector, relative to the scroll direction
      let radians: CGFloat
      if style.toolboxOrientation == .vertical {
        radians = atan(abs(delta.x) / abs(delta.y))
      } else {
        radians = atan(abs(delta.y) / abs(delta.x))
      }

      // Fire the gesture if it started more than 20 degrees in the perpendicular direction
      let angle = (radians / CGFloat.pi) * 180
      if angle > 20 {
        return true
      } else {
        panGestureRecognizer.cancelAllTouches()
        return false
      }
    }

    return true
  }

  open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
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

// MARK: - Interactive Pop Gesture Recognizer

extension WorkbenchViewController {
  fileprivate func setInteractivePopGestureRecognizerEnabled(_ enabled: Bool) {
    guard let navigationController = self.navigationController,
      let interactivePopGestureRecognizer = navigationController.interactivePopGestureRecognizer,
      let gestureRecognizers = navigationController.view.gestureRecognizers else {
        return
    }

    // Add/remove pop gesture recognizer
    let containsRecognizer = gestureRecognizers.contains(interactivePopGestureRecognizer)
    if enabled && !containsRecognizer {
      navigationController.view.addGestureRecognizer(interactivePopGestureRecognizer)
    } else if !enabled && containsRecognizer {
      navigationController.view.removeGestureRecognizer(interactivePopGestureRecognizer)
    }
  }

  fileprivate func interactivePopGestureRecognizerEnabled() -> Bool {
    guard let navigationController = self.navigationController,
      let interactivePopGestureRecognizer = navigationController.interactivePopGestureRecognizer,
      let gestureRecognizers = navigationController.view.gestureRecognizers else {
      return false
    }

    return gestureRecognizers.contains(interactivePopGestureRecognizer)
  }
}
