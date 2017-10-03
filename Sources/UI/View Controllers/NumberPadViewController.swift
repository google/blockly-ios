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

/**
 View controller for inputting a number.
 */
@objc(BKYNumberPadViewController)
@objcMembers public class NumberPadViewController: UIViewController {
  // MARK: - Properties

  /// Number pad control.
  public private(set) lazy var numberPad: NumberPad = {
    let numberPad = NumberPad(frame: .zero, options: self._numberPadOptions)
    numberPad.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    return numberPad
  }()

  /// Options used when initializing the number pad.
  private var _numberPadOptions = NumberPad.Options()

  // MARK: - Initializers

  public init(options: NumberPad.Options? = nil) {
    if let options = options {
      _numberPadOptions = options
    }
    super.init(nibName: nil, bundle: nil)
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func viewDidLoad() {
    super.viewDidLoad()

    numberPad.frame =
      CGRect(x: 10, y: 10, width: view.bounds.width - 20, height: view.bounds.height - 20)
    view.addSubview(numberPad)

    preferredContentSize = CGSize(width: 200, height: 200)
  }

  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    numberPad.textField?.becomeFirstResponder()
  }
}
