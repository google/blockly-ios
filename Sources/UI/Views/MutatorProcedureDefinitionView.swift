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
@objcMembers open class MutatorProcedureDefinitionView: LayoutView {
  // MARK: - Properties

  /// Convenience property accessing `self.layout` as `MutatorProcedureDefinitionLayout`
  open var mutatorProcedureDefinitionLayout: MutatorProcedureDefinitionLayout? {
    return layout as? MutatorProcedureDefinitionLayout
  }

  /// A button for opening the popover settings
  open fileprivate(set) lazy var popoverButton: UIButton = {
    let button = UIButton(type: .system)
    button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    if let image = ImageLoader.loadImage(named: "settings",
                                         forClass: MutatorProcedureDefinitionView.self) {
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

    guard let layout = self.mutatorProcedureDefinitionLayout else {
      return
    }

    runAnimatableCode(animated) {
      if flags.intersectsWith([Layout.Flag_NeedsDisplay, Layout.Flag_UpdateViewFrame]) {
        // Update the view frame
        self.frame = layout.viewFrame

        // Force the mutator view to always be drawn behind sibling views (which could be other
        // blocks).
        self.superview?.sendSubview(toBack: self)
      }

      let topPadding = layout.engine.viewUnitFromWorkspaceUnit(4)
      self.popoverButton.contentEdgeInsets = UIEdgeInsetsMake(topPadding, 0, topPadding, 0)
      self.popoverButton.tintColor =
        layout.config.color(for: DefaultLayoutConfig.MutatorSettingsButtonColor)

      self.isUserInteractionEnabled = layout.userInteractionEnabled
    }
  }

  open override func prepareForReuse() {
    super.prepareForReuse()
    frame = CGRect.zero
  }

  // MARK: - Private

  @objc private dynamic func openPopover(_ sender: UIButton) {
    guard let mutatorLayout = self.mutatorProcedureDefinitionLayout else {
      return
    }

    let viewController = MutatorProcedureDefinitionPopoverController(mutatorLayout: mutatorLayout)

    // Preserve the current input connections so that subsequent mutations don't disconnect them
    mutatorLayout.preserveCurrentInputConnections()

    popoverDelegate?.layoutView(self,
                                requestedToPresentPopoverViewController: viewController,
                                fromView: popoverButton,
                                presentationDelegate: self)
  }
}

// MARK: - UIPopoverPresentationControllerDelegate

extension MutatorProcedureDefinitionView: UIPopoverPresentationControllerDelegate {
  public func prepareForPopoverPresentation(
    _ popoverPresentationController: UIPopoverPresentationController) {
    guard let rtl = self.mutatorProcedureDefinitionLayout?.engine.rtl else { return }

    // Prioritize arrow directions, so it won't obstruct the view of the parameters
    popoverPresentationController.bky_prioritizeArrowDirections([.down, .up, .right], rtl: rtl)
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
    return mutatorLayout.engine.config.popoverFont(for: LayoutConfig.PopoverLabelFont)
  }

  /// The font to use for titles in this popup
  private var titleFont: UIFont {
    return mutatorLayout.engine.config.popoverFont(for: LayoutConfig.PopoverTitleFont)
  }

  /// The font to use for subtitles in this popup
  private var subtitleFont: UIFont {
    return mutatorLayout.engine.config.popoverFont(for: LayoutConfig.PopoverSubtitleFont)
  }

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

    // Register custom cells
    tableView.setEditing(true, animated: false)
    tableView.register(ParameterCellView.self,
                       forCellReuseIdentifier: IDENTIFIER_PARAMETER_CELL)
    tableView.register(UITableViewHeaderFooterView.self,
                       forHeaderFooterViewReuseIdentifier: IDENTIFIER_PARAMETER_HEADER)

    // Set all estimated heights to 0 so that `tableView.contentSize` is calculated properly
    // instead of using estimated values.
    tableView.estimatedRowHeight = 0
    tableView.estimatedSectionHeaderHeight = 0
    tableView.estimatedSectionFooterHeight = 0

    // Load data immediately
    tableView.reloadData()

    // Set the preferred content size immediately so that the correct popover arrow direction
    // can be determined by the instantiator of this object.
    updatePreferredContentSize()
  }

  // MARK: - Super

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
      cell.textField.delegate = self
      cell.textField.font = generalFont
      cell.textField.addTarget(
        self, action: #selector(updateParameterTextField), for: [.touchCancel, .touchDragOutside])

      // Update text field value, and tag the cell with the parameter UUID that it represents
      // (so we know which value to update later).
      if indexPath.row < mutatorLayout.parameters.count {
        cell.textField.text = mutatorLayout.parameters[indexPath.row].name
        cell.textField.placeholder = ""
        cell.parameterUUID = mutatorLayout.parameters[indexPath.row].uuid
      } else {
        cell.textField.text = ""
        cell.textField.placeholder = message(forKey: "BKY_IOS_PROCEDURES_ADD_INPUT")
        cell.parameterUUID = nil // A new parameter is represented with a UUID set to `nil`
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

      updatePreferredContentSize()
    }
  }

  // MARK: - Update state

  func updatePreferredContentSize() {
    // Set `preferredContentSize` using the correct value of `tableView.contentSize`.
    preferredContentSize = CGSize(width: 300, height: tableView.contentSize.height)
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
      try EventManager.shared.groupAndFireEvents {
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

  @objc dynamic func updateAllowStatements() {
    if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: SECTION_OTHER_OPTIONS)),
      let accessoryView = cell.accessoryView as? UISwitch
    {
      mutatorLayout.allowStatements = accessoryView.isOn
      performMutation()
    }
  }

  @objc func updateParameterTextField(_ textField: UITextField) {
    guard let cell = textField.bky_firstAncestor(ofType: ParameterCellView.self) else {
      return
    }

    let text = textField.text ?? ""

    // Figure out which parameter index this text field is associated with this text field
    let parameterIndex = cell.parameterUUID == nil ?
      // If `nil`, this represents a new parameter
      mutatorLayout.parameters.count :
      // Find the parameter index with matching UUID
      (mutatorLayout.parameters.index(where: { $0.uuid == cell.parameterUUID }) ?? -1)

    if parameterIndex >= mutatorLayout.parameters.count && !text.isEmpty {
      // Add new parameter
      let newParameter = ProcedureParameter(name: text)
      mutatorLayout.parameters.append(newParameter)
      performMutation()

      // Update the cell's UUID
      cell.parameterUUID = newParameter.uuid

      // Update table
      let newAddRowIndexPath =
        IndexPath(row: mutatorLayout.parameters.count, section: SECTION_PARAMETERS)
      tableView.insertRows(at: [newAddRowIndexPath], with: .none)

      // Reload all rows containing this new parameter (the parameter may have already existed,
      // so other parameters may have been renamed to match its case sensitivity).
      let reloadRows = indexPaths(containingParameter: text) + [newAddRowIndexPath]
      tableView.reloadRows(at: reloadRows, with: .none)

      if let headerView = tableView.headerView(forSection: SECTION_PARAMETERS) {
        configureParametersHeaderView(headerView)
      }

      // Scroll the new "add input" row into view.
      tableView.scrollToRow(at: newAddRowIndexPath, at: .middle, animated: true)

      // Automatically give focus to the "add input" text field.
      if let cell = self.tableView.cellForRow(at: newAddRowIndexPath) as? ParameterCellView {
        cell.textField.becomeFirstResponder()
      }
    } else if 0 <= parameterIndex && parameterIndex < mutatorLayout.parameters.count {
      if text.isEmpty {
        // The user set the parameter to the empty string. Reset it to what it was before editing
        // began. (If the user's intent was to delete the parameter, they need to use the delete
        // button.)
        textField.text = mutatorLayout.parameters[parameterIndex].name
      } else {
        // Update the parameter
        mutatorLayout.parameters[parameterIndex].name = text
        performMutation()

        // Update all rows with this parameter name and the header title (based on whether
        // there are duplicates now)
        let reloadRows = indexPaths(containingParameter: text)
        tableView.reloadRows(at: reloadRows, with: .automatic)

        if let headerView = tableView.headerView(forSection: SECTION_PARAMETERS) {
          configureParametersHeaderView(headerView)
        }
      }
    } else if parameterIndex < 0 {
      bky_debugPrint("No associated parameter index could be found for parameter UUID " +
        "('\(cell.parameterUUID ?? "nil")').")
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

  func textFieldDidBeginEditing(_ textField: UITextField) {
    // If the user is adding a new parameter, automatically the text field into the
    // middle of the table view.
    if let cell = textField.superview?.superview as? ParameterCellView,
      let indexPath = tableView.indexPath(for: cell),
      cell.parameterUUID == nil {
      tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
    }
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
  var textField = UITextField()

  /// The parameter UUID this cell represents. If `nil`, this cell represents the "+ add input" row.
  var parameterUUID: String?

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
