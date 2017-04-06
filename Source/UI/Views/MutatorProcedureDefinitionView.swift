/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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

// MARK: - MutatorProcedureDefinitionView Class

/**
 View for rendering a `MutatorProcedureDefinition`.
 */
@objc(MutatorProcedureDefinitionView)
open class MutatorProcedureDefinitionView: LayoutView {
  // MARK: - Properties

  /// Convenience property accessing `self.layout` as `MutatorProcedureDefinitionLayout`
  open var mutatorProcedureDefinitionLayout: MutatorProcedureDefinitionLayout? {
    return layout as? MutatorProcedureDefinitionLayout
  }

  /// A button for opening the popover settings
  open fileprivate(set) lazy var popoverButton: UIButton = {
    let button = UIButton(type: .custom)
    button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    if let image = ImageLoader.loadImage(named: "settings", forClass: type(of: self)) {
      button.setImage(image, for: .normal)
      button.imageView?.contentMode = .scaleAspectFit
      button.contentHorizontalAlignment = .fill
      button.contentVerticalAlignment = .fill
    }
    button.addTarget(self, action: #selector(openPopover(_:)), for: .touchUpInside)
    return button
  }()

  // MARK: - Initializers

  /// Initializes the number field view.
  public required init() {
    super.init(frame: CGRect.zero)

    addSubview(popoverButton)
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
      if flags.intersectsWith([Layout.Flag_NeedsDisplay, Layout.Flag_UpdateViewFrame]) {
        // Update the view frame
        self.frame = layout.viewFrame
      }

      let topPadding = layout.engine.viewUnitFromWorkspaceUnit(4)
      self.popoverButton.contentEdgeInsets = UIEdgeInsetsMake(topPadding, 0, topPadding, 0)
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()
    frame = CGRect.zero
  }

  // MARK: - Private

  private dynamic func openPopover(_ sender: UIButton) {
    guard let mutatorLayout = self.mutatorProcedureDefinitionLayout else {
      return
    }

    let viewController = MutatorProcedureDefinitionPopoverController(mutatorLayout: mutatorLayout)

    // Preserve the current input connections so that subsequent mutations don't disconnect them
    mutatorLayout.preserveCurrentInputConnections()

    popoverDelegate?.layoutView(self,
                                requestedToPresentPopoverViewController: viewController,
                                fromView: popoverButton)

    // Set the arrow direction of the popover to be up/down/right, so it won't
    // obstruct the view of the parameters
    viewController.popoverPresentationController?.permittedArrowDirections = [.up, .down, .right]
  }
}

// MARK: - MutatorProcedureDefinitionPopoverController Class

/**
 Popover used to display the configurable procedure definition options.
 
 - note: In the iOS Simulator, this popover may render incorrectly if "Debug > Optimize Rendering
 for Window Scale" is enabled. This rendering problem will go away if this optimization is
 disabled or if the app is running on a physical device.
 */
fileprivate class MutatorProcedureDefinitionPopoverController: UITableViewController {
  // MARK: - Properties

  /// Section index for parameters
  final let SECTION_PARAMETERS = 0
  /// Section index for other options
  final let SECTION_OTHER_OPTIONS = 1
  /// Reuse identifier for `ParameterCell`
  final let IDENTIFIER_PARAMETER_CELL = "ParameterCell"
  /// Reuse identifier for the parameter section header view
  final let IDENTIFIER_PARAMETER_HEADER = "ParameterHeaderView"
  /// Reuse identifier for the allow statements cell
  final let IDENTIFIER_ALLOW_STATEMENTS_CELL = "AllowStatementsCell"

  /// The mutator to configure
  private weak var mutatorLayout: MutatorProcedureDefinitionLayout!

  /// The font to use for general text in this popup
  private var generalFont: UIFont {
    return mutatorLayout.engine.config.popoverFont(for: LayoutConfig.GlobalFont)
  }

  /// The font to use for titles in this popup
  private var titleFont: UIFont {
    return mutatorLayout.engine.config.popoverFont(for: LayoutConfig.PopoverTitleFont)
  }

  /// The font to use for subtitles in this popup
  private var subtitleFont: UIFont {
    return mutatorLayout.engine.config.popoverFont(for: LayoutConfig.PopoverSubtitleFont)
  }

  /// Pointer used for distinguishing changes in `tableView.contentSize`
  private var _kvoContextContentSize = 0

  // MARK: - Initializers

  convenience init(mutatorLayout: MutatorProcedureDefinitionLayout) {
    // NOTE: Normally this would be configured as a designated initializer, but there is a problem
    // with UITableViewController initializers. Using a convenience initializer here is a quick
    // fix to the problem (albeit with use of a force unwrapped optional).
    //
    // See here for more details:
    // http://stackoverflow.com/questions/25139494/how-to-subclass-uitableviewcontroller-in-swift

    self.init(style: .grouped)
    self.mutatorLayout = mutatorLayout

    tableView.addObserver(
      self, forKeyPath: "contentSize", options: .new, context: &self._kvoContextContentSize)
  }

  deinit {
    tableView.removeObserver(self, forKeyPath: "contentSize")
  }

  // MARK: - Super

  open override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey : Any]?,
    context: UnsafeMutableRawPointer?)
  {
    if context == &_kvoContextContentSize {
      updatePreferredContentSize()
    } else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.setEditing(true, animated: false)
    tableView.rowHeight = UITableViewAutomaticDimension
    tableView.estimatedRowHeight = 44 * mutatorLayout.engine.popoverScale
    tableView.register(ParameterCellView.self,
                       forCellReuseIdentifier: IDENTIFIER_PARAMETER_CELL)
    tableView.register(UITableViewHeaderFooterView.self,
                       forHeaderFooterViewReuseIdentifier: IDENTIFIER_PARAMETER_HEADER)
    updatePreferredContentSize()
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    // If the mutator returns a value, then it can toggle its "allow statements" option. A new
    // section needs to be created for this option.
    return mutatorLayout.returnsValue ? 2 : 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
      case SECTION_PARAMETERS: return mutatorLayout.parameters.count + 1
      case SECTION_OTHER_OPTIONS: return 1
      default: return 0
    }
  }

  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
  {
    switch section {
      case SECTION_PARAMETERS:
        let headerView =
          tableView.dequeueReusableHeaderFooterView(withIdentifier: IDENTIFIER_PARAMETER_HEADER) ??
          UITableViewHeaderFooterView(reuseIdentifier: IDENTIFIER_PARAMETER_HEADER)

        configureParametersHeaderView(headerView)

        return headerView
      default:
        return nil
    }
  }

  override func tableView(
    _ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int)
  {
    switch section {
      case SECTION_PARAMETERS:
        if let headerView = view as? UITableViewHeaderFooterView {
          configureParametersHeaderView(headerView)
        }
      default: break
    }
  }

  override func tableView(
    _ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
  {
    // This is calculated manually since we haven't been able to force updates to *just*
    // section headers using automatic sizing without introducing strange render animations.
    switch section {
      case SECTION_PARAMETERS:
        let width = tableView.contentSize.width - 30 // -30 = default iOS left/right margins
        let titleHeight =
          parametersTitle().bky_multiLineSize(forFont: titleFont, constrainedToWidth: width).height
        let errorMessage = parametersErrorMessage()
        let errorHeight =
          errorMessage.bky_multiLineSize(forFont: subtitleFont, constrainedToWidth: width).height

        // 24 = top padding, 16 = padding between title and error
        let popoverScale = mutatorLayout.engine.popoverScale
        return (24 * popoverScale) + titleHeight +
          (errorMessage.isEmpty ? 0 : 16 * popoverScale) + errorHeight
      default:
        return 0
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell
  {
    if indexPath.section == SECTION_PARAMETERS {
      // Parameter cell
      let cell = tableView.dequeueReusableCell(
        withIdentifier: IDENTIFIER_PARAMETER_CELL, for: indexPath) as! ParameterCellView

      // Set this controller as the text field delegate
      cell.textField.font = generalFont
      cell.textField.delegate = self
      cell.textField.addTarget(
        self, action: #selector(updateParameterTextField), for: [.touchCancel, .touchDragOutside])

      // Update text field value
      if indexPath.row < mutatorLayout.parameters.count {
        cell.textField.text = mutatorLayout.parameters[indexPath.row].name
      } else {
        cell.textField.text = ""
      }

      return cell
    } else {
      // Allow statements option
      let accessoryView = UISwitch()
      accessoryView.addTarget(self, action: #selector(updateAllowStatements), for: .valueChanged)
      accessoryView.isOn = mutatorLayout.allowStatements

      let cell = UITableViewCell(style: .default, reuseIdentifier: IDENTIFIER_ALLOW_STATEMENTS_CELL)
      cell.textLabel?.text = message(forKey: "BKY_IOS_PROCEDURES_ALLOW_STATEMENTS")
      cell.textLabel?.font = generalFont
      cell.textLabel?.numberOfLines = 0
      cell.accessoryView = accessoryView

      return cell
    }
  }

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Only allow parameters to be edited
    return indexPath.section == SECTION_PARAMETERS && indexPath.row < mutatorLayout.parameters.count
  }

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    // Only allow parameters to be moved
    return indexPath.section == SECTION_PARAMETERS && indexPath.row < mutatorLayout.parameters.count
  }

  override func tableView(_ tableView: UITableView,
                          targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                          toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath
  {
    // Clamp the re-ordering rows to within the parameters section
    if proposedDestinationIndexPath.section != SECTION_PARAMETERS ||
      proposedDestinationIndexPath.row >= mutatorLayout.parameters.count
    {
      return IndexPath(row: max(mutatorLayout.parameters.count - 1, 0), section: SECTION_PARAMETERS)
    }
    return proposedDestinationIndexPath
  }

  override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath,
                          to destinationIndexPath: IndexPath)
  {
    if sourceIndexPath.section == SECTION_PARAMETERS &&
      destinationIndexPath.section == SECTION_PARAMETERS &&
      sourceIndexPath.row < mutatorLayout.parameters.count &&
      destinationIndexPath.row < mutatorLayout.parameters.count
    {
      let parameter = mutatorLayout.parameters.remove(at: sourceIndexPath.row)
      mutatorLayout.parameters.insert(parameter, at: destinationIndexPath.row)
      performMutation()

      tableView.moveRow(at: sourceIndexPath, to: destinationIndexPath)
    }
  }

  override func tableView(_ tableView: UITableView,
    commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath)
  {
    if indexPath.section == SECTION_PARAMETERS && indexPath.row < mutatorLayout.parameters.count &&
      editingStyle == .delete
    {
      mutatorLayout.parameters.remove(at: indexPath.row)
      performMutation()

      // Update UI
      tableView.deleteRows(at: [indexPath], with: .automatic)

      if let headerView = tableView.headerView(forSection: SECTION_PARAMETERS) {
        configureParametersHeaderView(headerView)
      }
    }
  }

  // MARK: - Update state

  func updatePreferredContentSize() {
    // Update preferred content size
    self.presentingViewController?.presentedViewController?.preferredContentSize =
      CGSize(width: 300, height: tableView.contentSize.height)
  }

  func configureParametersHeaderView(_ headerView: UITableViewHeaderFooterView) {
    headerView.textLabel?.text = parametersTitle()
    headerView.textLabel?.numberOfLines = 0
    headerView.textLabel?.font = titleFont
    headerView.detailTextLabel?.text = parametersErrorMessage()
    headerView.detailTextLabel?.numberOfLines = 0
    headerView.detailTextLabel?.font = subtitleFont
    headerView.detailTextLabel?.textColor = .red
    headerView.detailTextLabel?.highlightedTextColor = .red
    headerView.setNeedsDisplay()
    headerView.setNeedsLayout()
  }

  func parametersTitle() -> String {
    return message(forKey: "BKY_IOS_PROCEDURES_INPUTS")
  }

  func parametersErrorMessage() -> String {
    if mutatorLayout.containsDuplicateParameters() {
      return message(forKey: "BKY_IOS_PROCEDURES_DUPLICATE_INPUTS_ERROR")
    }
    return ""
  }

  fileprivate func indexPaths(containingParameter parameter: String) -> [IndexPath] {
    var indexPaths = [IndexPath]()

    for (i, aParameter) in mutatorLayout.parameters.enumerated() {
      if aParameter.name.lowercased() == parameter.lowercased() {
        indexPaths.append(IndexPath(row: i, section: SECTION_PARAMETERS))
      }
    }

    return indexPaths
  }

  // MARK: - Mutation

  func performMutation() {
    do {
      try EventManager.sharedInstance.groupAndFireEvents {
        try mutatorLayout.performMutation()

        if let blockLayout = mutatorLayout.mutator.block?.layout {
          Layout.animate {
            mutatorLayout.layoutCoordinator?.blockBumper
              .bumpNeighbors(ofBlockLayout: blockLayout, alwaysBumpOthers: true)
          }
        }
      }
    } catch let error {
      bky_assertionFailure("Could not perform mutation: \(error)")
    }
  }

  dynamic func updateAllowStatements() {
    if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: SECTION_OTHER_OPTIONS)),
      let accessoryView = cell.accessoryView as? UISwitch
    {
      mutatorLayout.allowStatements = accessoryView.isOn
      performMutation()
    }
  }

  func updateParameterTextField(_ textField: UITextField) {
    textField.resignFirstResponder()

    if let cell = textField.superview?.superview as? UITableViewCell,
      let indexPath = tableView.indexPath(for: cell),
      let text = textField.text
    {
      if indexPath.row >= mutatorLayout.parameters.count && !text.isEmpty {
        // Add new parameter
        mutatorLayout.parameters.append(ProcedureParameter(name: text))
        performMutation()

        // Update table
        let newAddRowIndexPath =
          IndexPath(row: mutatorLayout.parameters.count, section: SECTION_PARAMETERS)
        tableView.insertRows(at: [newAddRowIndexPath], with: .automatic)

        // Reload all rows containing this new parameter (the parameter may have already existed,
        // so other parameters may have been renamed to match its case sensitivity).
        let reloadRows = indexPaths(containingParameter: text) + [newAddRowIndexPath]
        tableView.reloadRows(at: reloadRows, with: .automatic)

        if let headerView = tableView.headerView(forSection: SECTION_PARAMETERS) {
          configureParametersHeaderView(headerView)
        }

        // Automatically give the next add row the focus
        if let cell = tableView.cellForRow(at: newAddRowIndexPath) as? ParameterCellView {
          cell.textField.becomeFirstResponder()
        }
      } else if indexPath.row < mutatorLayout.parameters.count {
        if text.isEmpty {
          // The user set the parameter to the empty string. Reset it to what it was before editing
          // began. (If the user's intent was to delete the parameter, they need to use the delete
          // button.)
          textField.text = mutatorLayout.parameters[indexPath.row].name
        } else {
          // Update the parameter
          mutatorLayout.parameters[indexPath.row].name = text
          performMutation()

          // Update all rows with this parameter name and the header title (based on whether
          // there are duplicates now)
          let reloadRows = indexPaths(containingParameter: text)
          tableView.reloadRows(at: reloadRows, with: .automatic)

          if let headerView = tableView.headerView(forSection: SECTION_PARAMETERS) {
            configureParametersHeaderView(headerView)
          }
        }
      }
    }
  }
}

extension MutatorProcedureDefinitionPopoverController: UITextFieldDelegate {

  // MARK: - UITextFieldDelegate Implementation

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    // Dismiss the keyboard
    textField.resignFirstResponder()
    return true
  }

  func textFieldDidEndEditing(_ textField: UITextField) {
    updateParameterTextField(textField)
  }
}

// MARK: - ParameterCellView Class

/**
 View cell for editing the name of single parameter.
 */
fileprivate class ParameterCellView: UITableViewCell {
  // MARK: - Properties

  /// The text field for entering the parameter
  lazy var textField: UITextField = {
    let textField = UITextField()
    textField.placeholder = message(forKey: "BKY_IOS_PROCEDURES_ADD_INPUT")
    return textField
  }()

  // MARK: - Initializers

  override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
    super.init(style: .default, reuseIdentifier: reuseIdentifier)

    let views: [String: UIView] = ["textField": textField]
    let constraints = [
      "H:|-[textField]-|",
      "V:|-[textField]-|"
    ]

    contentView.bky_addSubviews(Array(views.values))
    contentView.bky_addVisualFormatConstraints(constraints, metrics: nil, views: views)
    showsReorderControl = true
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }
}
