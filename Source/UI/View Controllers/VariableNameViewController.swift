/*
* Copyright 2016 Google Inc. All Rights Reserved.
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

/**
 Delegate for events that occur on `FieldDropdownOptionsViewController`.
 */
@objc(BKYVariableNameViewControllerDelegate)
public protocol VariableNameViewControllerDelegate: class {
  /**
   Event that is called when the user has changed the name for the field.

   - parameter viewController: The view controller where this event occurred.
   - parameter name: The new name.
   */
  func variableNameViewController(_ viewController: VariableNameViewController,
    didChangeName name: String?)
}

/**
 View controller for selecting a name for a `FieldVariable`.
 */
@objc(BKYVariableNameViewController)
open class VariableNameViewController: UIViewController, UITextFieldDelegate {
  // MARK: - Properties

  /// The text field to render
  open fileprivate(set) lazy var textField: InsetTextField = {
    let frame = self.view.frame
    let textField = InsetTextField(frame: CGRect(x: frame.origin.x + 10, y: frame.origin.y, width: frame.width - 20, height: frame.height))
    textField.delegate = self
    textField.borderStyle = .roundedRect
    textField.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    textField.keyboardType = .default
    textField.adjustsFontSizeToFitWidth = false

    // There is an iPhone 7/7+ simulator (and possibly device) bug where the user can't edit the
    // text field. Setting an empty input accessory view seems to fix this problem.
    textField.inputAccessoryView = UIView(frame: CGRect.zero)

    return textField
  }()

  /// Delegate for events that occur on this controller
  open weak var delegate: VariableNameViewControllerDelegate?

  // MARK: - Initializers

  public init() {
    super.init(nibName: nil, bundle: nil)
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  open override func viewDidLoad() {
    super.viewDidLoad()

    let frame = self.view.frame
    self.view.frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: 100)
    self.view.addSubview(self.textField)
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    refreshView()
  }

  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }

  // MARK: - Public

  open func refreshView() {
    self.preferredContentSize = CGSize(width: 200, height: 100)
  }

  // MARK: - Private

  public func textFieldDidEndEditing(_ textField: UITextField) {
    self.delegate?.variableNameViewController(self, didChangeName: textField.text)
  }
}
