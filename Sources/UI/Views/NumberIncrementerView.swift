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
 Protocol for delegate events that occur on a `IntegerIncrementerView`.
 */
internal protocol IntegerIncrementerViewDelegate: class {
  func integerIncrementerView(
    _ integerIncrementerView: IntegerIncrementerView, didChangeToValue value: Int)
}

/**
 View that increments or decrements a number by use of buttons.
 */
internal class IntegerIncrementerView: UIView {
  // MARK: - Number Properties

  /// The current integer value for this view
  var value: Int = 0 {
    didSet {
      // Clamp to min/max values
      value = max(value, (self.minimumValue ?? value))
      value = min(value, (self.maximumValue ?? value))

      // Update state of the view
      updateState()

      if value != oldValue {
        delegate?.integerIncrementerView(self, didChangeToValue: value)
      }
    }
  }

  /// [Optional] The minimum possible integer for `value`. If `nil`, no minimum is enforced.
  var minimumValue: Int? {
    didSet {
      // Re-validate value
      value = max(value, (self.minimumValue ?? value))
    }
  }

  /// [Optional] The maximum possible integer for `value`. If `nil`, no maximum is enforced.
  var maximumValue: Int? {
    didSet {
      // Re-validate value
      value = min(value, (self.maximumValue ?? value))
    }
  }

  /// Delegate for listening to events
  weak var delegate: IntegerIncrementerViewDelegate?

  // MARK: - View Properties

  /// Label for displaying `value`
  lazy var label: UILabel = {
    let label = UILabel()
    label.isUserInteractionEnabled = false
    label.textAlignment = .center
    return label
  }()

  /// Button for decrementing `value`
  lazy var buttonMinus: UIButton = {
    let buttonMinus = UIButton(type: .custom)
    buttonMinus.setTitle("-", for: .normal)
    buttonMinus.setTitleColor(.blue, for: .normal)
    buttonMinus.setTitleColor(.gray, for: .disabled)
    buttonMinus.addTarget(self, action: #selector(decrementValue), for: .touchUpInside)
    return buttonMinus
  }()

  /// Button for incrementing `value`
  lazy var buttonPlus: UIButton = {
    let buttonPlus = UIButton(type: .custom)
    buttonPlus.setTitle("+", for: .normal)
    buttonPlus.setTitleColor(.blue, for: .normal)
    buttonPlus.setTitleColor(.gray, for: .disabled)
    buttonPlus.addTarget(self, action: #selector(incrementValue), for: .touchUpInside)
    return buttonPlus
  }()

  // MARK: - Initializers

  override init(frame: CGRect) {
    super.init(frame: frame)

    let subviews: [String: UIView] =
      ["buttonPlus": buttonPlus, "label": label, "buttonMinus": buttonMinus]
    let constraints = [
      "H:|[buttonMinus(28)][label][buttonPlus(28)]|",
      "V:|[buttonPlus]|",
      "V:|[label]|",
      "V:|[buttonMinus]|"
    ]
    bky_addSubviews(Array(subviews.values))
    bky_addVisualFormatConstraints(constraints, metrics: nil, views: subviews)

    updateState()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - User Interaction

  @objc private dynamic func decrementValue() {
    value -= 1
  }

  @objc private dynamic func incrementValue() {
    value += 1
  }

  // MARK: - Validation

  /**
   Updates the state of the view, based on the current number and any minimum/maximum values.
   */
  private func updateState() {
    label.text = String(value)

    if let minimumValue = self.minimumValue {
      buttonMinus.isEnabled = (value > minimumValue)
    } else {
      buttonMinus.isEnabled = true
    }

    if let maximumValue = self.maximumValue {
      buttonPlus.isEnabled = (value < maximumValue)
    } else {
      buttonPlus.isEnabled = true
    }
  }
}
