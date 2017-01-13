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

// MARK: - MutatorIfElseView Class

/**
 View for rendering a `MutatorIfElse`.
 */
@objc(BKYMutatorIfElseView)
open class MutatorIfElseView: LayoutView {
  // MARK: - Properties

  /// Convenience property accessing `self.layout` as `MutatorIfElseLayout`
  open var mutatorIfElseLayout: MutatorIfElseLayout? {
    return layout as? MutatorIfElseLayout
  }

  /// A button for opening the popover settings
  open fileprivate(set) lazy var popoverButton: UIButton = {
    let button = UIButton(type: .custom)
    button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    if let image = ImageLoader.loadImage(named: "settings", forClass: MutatorIfElseView.self) {
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
    guard let mutatorIfElseLayout = self.mutatorIfElseLayout else {
      return
    }

    let viewController =
      MutatorIfElseViewPopoverController(mutatorIfElseLayout: mutatorIfElseLayout)
    viewController.preferredContentSize = CGSize(width: 220, height: 100)

    // Preserve the current input connections so that subsequent mutations don't disconnect them
    mutatorIfElseLayout.preserveCurrentInputConnections()

    popoverDelegate?.layoutView(self,
                                requestedToPresentPopoverViewController: viewController,
                                fromView: popoverButton)

    // Set the arrow direction of the popover to be down/right/left, so it won't
    // obstruct the view of the block
    viewController.popoverPresentationController?.permittedArrowDirections = [.down, .right, .left]
  }
}

// MARK: - MutatorIfElseViewPopoverController Class

/**
 Popover used to display the "else-if" and "else" options.
 */
fileprivate class MutatorIfElseViewPopoverController: UITableViewController {

  // MARK: - Properties

  /// The mutator to configure
  unowned let mutatorIfElseLayout: MutatorIfElseLayout

  // MARK: - Initializers

  init(mutatorIfElseLayout: MutatorIfElseLayout) {
    self.mutatorIfElseLayout = mutatorIfElseLayout
    super.init(style: .plain)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("Unsupported initializer")
  }

  // MARK: - Super

  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.allowsSelection = false
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 2
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell
  {
    if indexPath.row == 0 {
      // Else-if option
      let accessoryView = IntegerIncrementerView(frame: CGRect(x: 0, y: 0, width: 84, height: 44))
      accessoryView.value = mutatorIfElseLayout.elseIfCount
      accessoryView.minimumValue = 0
      accessoryView.delegate = self

      let cell = UITableViewCell(style: .default, reuseIdentifier: "ElseIfCell")
      cell.textLabel?.text = "else if"
      cell.accessoryView = accessoryView

      return cell
    } else {
      // Else option
      let accessoryView = UISwitch()
      accessoryView.addTarget(self, action: #selector(updateElseCount), for: .valueChanged)
      accessoryView.isOn = (mutatorIfElseLayout.elseCount > 0)

      let cell = UITableViewCell(style: .default, reuseIdentifier: "ElseCell")
      cell.textLabel?.text = "else"
      cell.accessoryView = accessoryView

      return cell
    }
  }

  // MARK: - Else Mutation

  fileprivate dynamic func updateElseCount() {
    if let cell = tableView.cellForRow(at: IndexPath(row: 1, section: 0)),
      let accessoryView = cell.accessoryView as? UISwitch
    {
      mutatorIfElseLayout.elseCount = accessoryView.isOn ? 1 : 0
      try? mutatorIfElseLayout.performMutation()
    }
  }
}

extension MutatorIfElseViewPopoverController: IntegerIncrementerViewDelegate {
  // MARK: - Else-If Mutation

  fileprivate func integerIncrementerView(
    _ integerIncrementerView: IntegerIncrementerView, didChangeToValue value: Int)
  {
    mutatorIfElseLayout.elseIfCount = value
    try? mutatorIfElseLayout.performMutation()
  }
}
