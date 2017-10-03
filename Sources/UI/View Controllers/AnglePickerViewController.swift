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
 Delegate for events that occur on `AnglePickerViewController`.
 */
@objc(BKYAnglePickerViewControllerDelegate)
public protocol AnglePickerViewControllerDelegate: class {
  /**
   Event that is called when the angle has been updated from the angle picker.

   - parameter viewController: The view controller where this event occurred.
   - parameter angle: The updated angle.
   */
  func anglePickerViewController(
    _ viewController: AnglePickerViewController, didUpdateAngle angle: Double)
}

/**
 View controller for selecting an angle.
 */
@objc(BKYAnglePickerViewController)
@objcMembers public class AnglePickerViewController: UIViewController {
  // MARK: - Properties

  /// The current angle value.
  public var angle: Double = 0 {
    didSet {
      anglePicker.angle = angle
    }
  }

  /// Delegate for events that occur on this controller.
  public weak var delegate: AnglePickerViewControllerDelegate?

  /// Angle picker control.
  public private(set) lazy var anglePicker: AnglePicker = {
    let anglePicker = AnglePicker(frame: .zero, options: self._anglePickerOptions)
    anglePicker.angle = self.angle
    anglePicker.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    anglePicker.addTarget(self, action: #selector(anglePickerValueChanged(_:)), for: .valueChanged)
    return anglePicker
  }()

  /// Options used when initializing the angle picker.
  private var _anglePickerOptions = AnglePicker.Options()

  // MARK: - Initializers

  public init(options: AnglePicker.Options? = nil) {
    if let options = options {
      _anglePickerOptions = options
    }
    super.init(nibName: nil, bundle: nil)
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func viewDidLoad() {
    super.viewDidLoad()

    anglePicker.frame =
      CGRect(x: 10, y: 10, width: view.bounds.width - 20, height: view.bounds.height - 20)
    view.addSubview(anglePicker)

    preferredContentSize = CGSize(width: 200, height: 200)
  }

  // MARK: - Private

  @objc private dynamic func anglePickerValueChanged(_ anglePicker: AnglePicker) {
    angle = anglePicker.angle

    delegate?.anglePickerViewController(self, didUpdateAngle: angle)
  }
}
