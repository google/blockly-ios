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
@objcMembers open class MutatorIfElseView: LayoutView {
  // MARK: - Properties

  /// Convenience property accessing `self.layout` as `MutatorIfElseLayout`
  open var mutatorIfElseLayout: MutatorIfElseLayout? {
    return layout as? MutatorIfElseLayout
  }

  /// A button for opening the popover settings
  open fileprivate(set) lazy var popoverButton: UIButton = {
    let button = UIButton(type: .system)
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

    guard let layout = self.mutatorIfElseLayout else {
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
    guard let mutatorIfElseLayout = self.mutatorIfElseLayout else {
      return
    }

    let viewController =
      MutatorIfElseViewPopoverController(mutatorIfElseLayout: mutatorIfElseLayout)

    // Preserve the current input connections so that subsequent mutations don't disconnect them
    mutatorIfElseLayout.preserveCurrentInputConnections()

    popoverDelegate?.layoutView(self,
                                requestedToPresentPopoverViewController: viewController,
                                fromView: popoverButton,
                                presentationDelegate: self)
  }
}

// MARK: - UIPopoverPresentationControllerDelegate

extension MutatorIfElseView: UIPopoverPresentationControllerDelegate {
  public func prepareForPopoverPresentation(
    _ popoverPresentationController: UIPopoverPresentationController) {
    guard let rtl = self.mutatorIfElseLayout?.engine.rtl else { return }

    // Prioritize arrow directions, so it won't obstruct the view of the block
    popoverPresentationController.bky_prioritizeArrowDirections([.down, .right, .left], rtl: rtl)
  }
}

// MARK: - MutatorIfElseViewPopoverController Class

/**
 Popover used to display the "else-if" and "else" options.
 */
fileprivate class MutatorIfElseViewPopoverController: UITableViewController {
  // MARK: - Properties

  /// The mutator to configure
  weak var mutatorIfElseLayout: MutatorIfElseLayout!

  // MARK: - Initializers

  convenience init(mutatorIfElseLayout: MutatorIfElseLayout) {
    // NOTE: Normally this would be configured as a designated initializer, but there is a problem
    // with UITableViewController initializers. Using a convenience initializer here is a quick
    // fix to the problem (albeit with use of a force unwrapped optional).
    //
    // See here for more details:
    // http://stackoverflow.com/questions/25139494/how-to-subclass-uitableviewcontroller-in-swift

    self.init(style: .plain)
    self.mutatorIfElseLayout = mutatorIfElseLayout

    // Set all estimated heights to 0 so that `tableView.contentSize` is calculated properly
    // instead of using estimated values.
    tableView.estimatedRowHeight = 0
    tableView.estimatedSectionHeaderHeight = 0
    tableView.estimatedSectionFooterHeight = 0

    tableView.allowsSelection = false

    // Load data immediately
    tableView.reloadData()

    // Set the preferred content size immediately so that the correct popover arrow direction
    // can be determined by the instantiator of this object.
    preferredContentSize = CGSize(width: 220, height: tableView.contentSize.height)
  }

  // MARK: - Super

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
      cell.textLabel?.text =
        MessageManager.shared.message(forKey: "BKY_CONTROLS_IF_MSG_ELSEIF") ?? ""
      cell.accessoryView = accessoryView

      return cell
    } else {
      // Else option
      let accessoryView = UISwitch()
      accessoryView.addTarget(self, action: #selector(updateElseCount), for: .valueChanged)
      accessoryView.isOn = mutatorIfElseLayout.elseStatement

      let cell = UITableViewCell(style: .default, reuseIdentifier: "ElseCell")
      cell.textLabel?.text = MessageManager.shared.message(forKey: "BKY_CONTROLS_IF_MSG_ELSE") ?? ""
      cell.accessoryView = accessoryView

      return cell
    }
  }

  // MARK: - Perform Mutation

  fileprivate func performMutation() {
    do {
      try EventManager.shared.groupAndFireEvents {
        try mutatorIfElseLayout.performMutation()

        if let blockLayout = mutatorIfElseLayout.mutator.block?.layout {
          Layout.animate {
            mutatorIfElseLayout.layoutCoordinator?.blockBumper
              .bumpNeighbors(ofBlockLayout: blockLayout, alwaysBumpOthers: true)
          }
        }
      }
    } catch let error {
      bky_assertionFailure("Could not update if/else block: \(error)")
    }
  }

  // MARK: - Else Mutation

  @objc fileprivate dynamic func updateElseCount() {
    if let cell = tableView.cellForRow(at: IndexPath(row: 1, section: 0)),
      let accessoryView = cell.accessoryView as? UISwitch
    {
      mutatorIfElseLayout.elseStatement = accessoryView.isOn
      performMutation()
    }
  }
}

extension MutatorIfElseViewPopoverController: IntegerIncrementerViewDelegate {
  // MARK: - Else-If Mutation

  fileprivate func integerIncrementerView(
    _ integerIncrementerView: IntegerIncrementerView, didChangeToValue value: Int)
  {
    mutatorIfElseLayout.elseIfCount = value
    performMutation()
  }
}
