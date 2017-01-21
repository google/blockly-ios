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
    guard let mutator = self.mutatorProcedureDefinitionLayout else {
      return
    }

    let viewController = MutatorProcedureDefinitionPopoverController(mutator: mutator)

    // Preserve the current input connections so that subsequent mutations don't disconnect them
    mutator.preserveCurrentInputConnections()

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
  weak var mutator: MutatorProcedureDefinitionLayout!

  /// Pointer used for distinguishing changes in `tableView.contentSize`
  private var _kvoContextContentSize = 0

  // MARK: - Initializers

  convenience init(mutator: MutatorProcedureDefinitionLayout) {
    // NOTE: Normally this would be configured as a designated initializer, but there is a problem
    // with UITableViewController initializers. Using a convenience initializer here is a quick
    // fix to the problem (albeit with use of a force unwrapped optional).
    //
    // See here for more details:
    // http://stackoverflow.com/questions/25139494/how-to-subclass-uitableviewcontroller-in-swift

    self.init(style: .grouped)
    self.mutator = mutator

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
    tableView.register(ParameterCellView.self,
                       forCellReuseIdentifier: IDENTIFIER_PARAMETER_CELL)
    tableView.register(UITableViewHeaderFooterView.self,
                       forHeaderFooterViewReuseIdentifier: IDENTIFIER_PARAMETER_HEADER)
    updatePreferredContentSize()
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    // If the mutator returns a value, then it can toggle its "allow statements" option. A new
    // section needs to be created for this option.
    return mutator.returnsValue ? 2 : 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
      case SECTION_PARAMETERS: return mutator.parameters.count + 1
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

  override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    switch section {
      case SECTION_PARAMETERS:
        if let headerView = view as? UITableViewHeaderFooterView {
          configureParametersHeaderView(headerView)
        }
      default: break
    }
  }

  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    switch section {
      case SECTION_PARAMETERS:
        let errorMessage = self.parametersErrorMessage()
        let errorFont = UIFont.systemFont(ofSize: 14)
        let errorSize = errorMessage.bky_multiLineSize(
          forFont: errorFont, constrainedToWidth: tableView.contentSize.width - 30)
        return 40 + (errorMessage.isEmpty ? 0 : 16) + errorSize.height
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
      cell.textField.addTarget(
        self, action: #selector(updateParameterTextField), for: [.touchCancel, .touchDragOutside])

      // Update text field value
      if indexPath.row < mutator.parameters.count {
        cell.textField.text = mutator.parameters[indexPath.row]
      } else {
        cell.textField.text = ""
      }

      return cell
    } else {
      // Allow statements option
      let accessoryView = UISwitch()
      accessoryView.addTarget(self, action: #selector(updateAllowStatements), for: .valueChanged)
      accessoryView.isOn = mutator.allowStatements

      let cell = UITableViewCell(style: .default, reuseIdentifier: IDENTIFIER_ALLOW_STATEMENTS_CELL)
      cell.textLabel?.text = "Allow statements"
      cell.accessoryView = accessoryView

      return cell
    }
  }

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Only allow parameters to be edited
    return indexPath.section == SECTION_PARAMETERS && indexPath.row < mutator.parameters.count
  }

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    // Only allow parameters to be moved
    return indexPath.section == SECTION_PARAMETERS && indexPath.row < mutator.parameters.count
  }

  override func tableView(_ tableView: UITableView,
                          targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                          toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath
  {
    // Clamp the re-ordering rows to within the parameters section
    if proposedDestinationIndexPath.section != SECTION_PARAMETERS ||
      proposedDestinationIndexPath.row >= mutator.parameters.count
    {
      return IndexPath(row: 1, section: SECTION_PARAMETERS)
    }
    return proposedDestinationIndexPath
  }

  override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath,
                          to destinationIndexPath: IndexPath)
  {
    if sourceIndexPath.section == SECTION_PARAMETERS &&
      destinationIndexPath.section == SECTION_PARAMETERS &&
      sourceIndexPath.row < mutator.parameters.count &&
      destinationIndexPath.row < mutator.parameters.count
    {
      let parameter = mutator.parameters.remove(at: sourceIndexPath.row)
      mutator.parameters.insert(parameter, at: destinationIndexPath.row)
      performMutation()

      tableView.moveRow(at: sourceIndexPath, to: destinationIndexPath)
    }
  }

  override func tableView(_ tableView: UITableView,
    commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath)
  {
    if indexPath.section == SECTION_PARAMETERS && indexPath.row < mutator.parameters.count &&
      editingStyle == .delete
    {
      mutator.parameters.remove(at: indexPath.row)
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
    headerView.textLabel?.text = "INPUTS"
    headerView.detailTextLabel?.text = parametersErrorMessage()
    headerView.detailTextLabel?.numberOfLines = 0
    headerView.detailTextLabel?.font = UIFont.systemFont(ofSize: 14)
    headerView.detailTextLabel?.textColor = .red
    headerView.detailTextLabel?.highlightedTextColor = .red
    headerView.setNeedsDisplay()
    headerView.setNeedsLayout()
  }

  func parametersErrorMessage() -> String {
    if mutator.containsDuplicateParameters() {
      return "This function has duplicate inputs."
    }
    return ""
  }

  // MARK: - Mutation

  func performMutation() {
    do {
      try mutator.performMutation()
    } catch let error {
      bky_assertionFailure("Could not perform mutation: \(error)")
    }
  }

  dynamic func updateAllowStatements() {
    if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: SECTION_OTHER_OPTIONS)),
      let accessoryView = cell.accessoryView as? UISwitch
    {
      mutator.allowStatements = accessoryView.isOn
      performMutation()
    }
  }

  func updateParameterTextField(_ textField: UITextField) {
    textField.resignFirstResponder()

    if let cell = textField.superview?.superview as? UITableViewCell,
      let indexPath = tableView.indexPath(for: cell),
      let text = textField.text
    {
      if indexPath.row >= mutator.parameters.count && !text.isEmpty {
        // Add new parameter
        mutator.parameters.append(text)
        performMutation()

        // Update table
        let newAddRowIndexPath =
          IndexPath(row: mutator.parameters.count, section: SECTION_PARAMETERS)
        tableView.insertRows(at: [newAddRowIndexPath], with: .automatic)
        tableView.reloadRows(at: [indexPath, newAddRowIndexPath], with: .automatic)

        if let headerView = tableView.headerView(forSection: SECTION_PARAMETERS) {
          configureParametersHeaderView(headerView)
        }

        // Automatically give the next add row the focus
        if let cell = tableView.cellForRow(at: newAddRowIndexPath) as? ParameterCellView {
          cell.textField.becomeFirstResponder()
        }
      } else if indexPath.row < mutator.parameters.count {
        if text.isEmpty {
          // The user set the parameter to the empty string. Reset it to what it was before editing
          // began. (If the user's intent was to delete the parameter, they need to use the delete
          // button.)
          textField.text = mutator.parameters[indexPath.row]
        } else {
          // Update the parameter
          mutator.parameters[indexPath.row] = text
          performMutation()
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
    textField.placeholder = "+ Add input"
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
