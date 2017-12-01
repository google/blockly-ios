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

import Foundation

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


/**
 Text field for inputting a number value.
 */
@objc(BKYFieldNumber)
@objcMembers public final class FieldNumber: Field {
  // MARK: - Static Properties

  /// The maximum number of digits allowed after the decimal place
  fileprivate static let MAXIMUM_FRACTION_DIGITS = 100

  // MARK: - Properties

  /**
  The number value of the field.
  
  When setting this field, the resulting value may differ from the original value, in order to
  adapt to the `self.minimumValue`, `self.maximumValue`, and `self.precision` constraints.
  */
  public var value: Double {
    didSet {
      value = constrainedValue(value) // Make sure the new value is constrained
      didSetProperty(value, oldValue)
    }
  }
  /// The localized text representation of `self.value`
  public var textValue: String {
    return _localizedNumberFormatter.string(from: NSNumber(value: value as Double)) ?? String(value)
  }
  /// The minimum value of `self.value`. If `nil`, `self.value` is unconstrained by a minimum value.
  public fileprivate(set) var minimumValue: Double? = nil {
    didSet { didSetProperty(minimumValue, oldValue) }
  }
  /// The maximum value of `self.value`. If `nil`, `self.value` is unconstrained by a maximum value.
  public fileprivate(set) var maximumValue: Double? = nil {
    didSet { didSetProperty(maximumValue, oldValue) }
  }
  /**
   The precision of the value allowed by this field.

   `self.value` must be a multiple of `self.precision`. Precision is usually expressed as a power of
   `10` (e.g., `1`, `100`, `0.01`), though other useful examples might be `5`, `20`, or `25`.

   If `nil`, `self.value` is unconstrained by a precision value.
   */
  public fileprivate(set) var precision: Double? = nil {
    didSet {
      if didSetProperty(precision, oldValue) {
        updateNumberFormatter()
      }
    }
  }
  /// Flag indicating if `self.value` is constrained to being an integer value.
  public var isInteger: Bool {
    return precision != nil && precision! == round(precision!)
  }
  /// The actual minimum value of the field, based on `self.precision` and `self.minimumValue`
  fileprivate var _effectiveMinimumValue: Double?
  /// The actual maximum value of the field, based on `self.precision` and `self.maximumValue`
  fileprivate var _effectiveMaximumValue: Double?

  /// Number formatter used for outputting the value as localized text
  fileprivate let _localizedNumberFormatter: NumberFormatter = {
    // Note: `self._localizedNumberFormatter` is already set to the default locale.
    let numberFormatter = NumberFormatter()
    numberFormatter.minimumIntegerDigits = 1
    return numberFormatter
  }()

  /// Number formatter used for serializing the value
  fileprivate let _serializedNumberFormatter: NumberFormatter = {
    // Set the locale of the serialized number formatter to "English".
    let numberFormatter = NumberFormatter()
    numberFormatter.locale = Locale(identifier: "en")
    numberFormatter.minimumIntegerDigits = 1
    return numberFormatter
  }()

  // MARK: - Initializers

  /**
   Initializes the number field.

   - parameter name: The name of this field.
   - parameter value: The initial value of this field.
   */
  public init(name: String, value: Double) {
    self.value = value
    super.init(name: name)

    updateNumberFormatter()
  }

  // MARK: - Super

  public override func copyField() -> Field {
    let number = FieldNumber(name: name, value: value)
    number.minimumValue = minimumValue
    number.maximumValue = maximumValue
    number.precision = precision
    number._effectiveMinimumValue = _effectiveMinimumValue
    number._effectiveMaximumValue = _effectiveMaximumValue
    return number
  }

  public override func setValueFromSerializedText(_ text: String) throws {
    self.value = try valueFromText(text, numberFormatter: _serializedNumberFormatter)
  }

  public override func serializedText() throws -> String? {
    return _serializedNumberFormatter.string(from: NSNumber(value: value as Double))
  }

  // MARK: - Public

  /**
   Sets `self.value` from the given text, using the current default locale.

   - parameter text: The localized text value.
   - returns: `true` if the value was set successfully using the localized text, or `false`
   otherwise.
   */
  @discardableResult
  public func setValueFromLocalizedText(_ text: String) -> Bool {
    do {
      self.value = try valueFromText(text, numberFormatter: _localizedNumberFormatter)
      return true
    } catch {
      return false
    }
  }

  /**
   Sets `self.minimumValue`, `self.maximumValue`, and `self.precision` based on given values,
   forcing `self.value` to conform to these constraints.

   - parameter minimum: The value to set for `self.minimumValue`.
   - parameter maximum: The value to set for `self.maximumValue`. If non-`nil` values are
   specified for both `minimum` and `maximum`, ensure `maximum >= minimum`.
   - parameter precision: The value to set for `self.precision`. If a non-`nil` value is specified,
   it must be positive.
   - throws:
   `BlocklyError`: Thrown if invalid parameter values are passed for constraints. 
   */
  public func setConstraints(minimum: Double?, maximum: Double?, precision: Double?) throws
  {
    if !self.editable {
      return
    }

    guard (minimum?.isFinite ?? true) &&
      (maximum?.isFinite ?? true) &&
      (precision?.isFinite ?? true) else
    {
      throw BlocklyError(.illegalArgument, "Constraints cannot be infinite nor NaN.")
    }

    if let minimumValue = minimum,
      let maximumValue = maximum,
      minimumValue > maximumValue {
      throw BlocklyError(.illegalArgument,
        "`minimum` value [\(minimumValue)] must be less than `maximum` value [\(maximumValue)].")
    }

    if let precisionValue = precision, precisionValue <= 0 {
      throw BlocklyError(.illegalArgument, "`precision` [\(precisionValue)] must be positive.")
    }

    var effectiveMinimum: Double? = nil
    var effectiveMaximum: Double? = nil

    if let precisionValue = precision {
      if let minValue = minimum {
        if minValue < 0 {
          let multiplier = floor(-minValue / precisionValue)
          effectiveMinimum = precisionValue * -multiplier
        } else {
          let multiplier = ceil(minValue / precisionValue)
          effectiveMinimum = precisionValue * multiplier
        }
      }

      if let maxValue = maximum {
        if maximum < 0 {
          let multiplier = ceil(-maxValue / precisionValue)
          effectiveMaximum = precisionValue * -multiplier
        } else {
          let multiplier = floor(maxValue / precisionValue)
          effectiveMaximum = precisionValue * multiplier
        }
      }

      if let minimumValue = effectiveMinimum,
        let maximumValue = effectiveMaximum,
        minimumValue > maximumValue {
        throw BlocklyError(.illegalArgument, "No valid value in range.")
      }
    } else {
      effectiveMinimum = minimum
      effectiveMaximum = maximum
    }

    self.minimumValue = minimum
    self.maximumValue = maximum
    self.precision = precision
    self._effectiveMinimumValue = effectiveMinimum
    self._effectiveMaximumValue = effectiveMaximum

    // Update `self.value` based on the new constraints
    self.value = constrainedValue(self.value)
  }

  // MARK: - Private

  /**
   Given a value, returns a value based on the current values of `self.minimumValue`,
   `self.maximumValue`, and `self.precision`.
   */
  fileprivate func constrainedValue(_ value: Double) -> Double {
    var constrainedValue = value
    if let precision = self.precision {
      // NOTE: round(...) in iOS will round towards positive infinity for positive values and
      // negative infinity for negative values. Android Blockly's FieldNumber implementation uses
      // Math.round(...) where it rounds all values towards positive infinity.
      constrainedValue = precision * round(constrainedValue / precision)
    }

    if let minimum = _effectiveMinimumValue {
      constrainedValue = max(constrainedValue, minimum)
    }

    if let maximum = _effectiveMaximumValue {
      constrainedValue = min(constrainedValue, maximum)
    }

    // Run the value through formatter to limit significant digits.
    if let formattedValue =
        _serializedNumberFormatter.string(from: NSNumber(value: constrainedValue as Double)),
      let newDoubleValue =
        _serializedNumberFormatter.number(from: formattedValue)?.doubleValue
      , newDoubleValue.isFinite
    {
      constrainedValue = newDoubleValue
    }

    return constrainedValue
  }

  /**
   Updates the internal number formatters based on the current value of `self.precision`.
   */
  fileprivate func updateNumberFormatter() {
    // Figure out minimum/maximum number of fraction digits based on `self.precision`
    let minimumFractionDigits: Int
    let maximumFractionDigits: Int

    if let precision = self.precision {
      let precisionString = String(precision)
      if let decimalRange = precisionString.range(of: ".") , !self.isInteger {
        // Set the min/max number of fraction digits to the same number of digits after the
        // decimal place of `self.precision`
        let significantDigits = precisionString[decimalRange.upperBound...].count
        let fractionDigits = min(significantDigits, FieldNumber.MAXIMUM_FRACTION_DIGITS)
        minimumFractionDigits = fractionDigits
        maximumFractionDigits = fractionDigits
      } else {
        // This is an integer, don't show fraction digits
        minimumFractionDigits = 0
        maximumFractionDigits = 0
      }
    } else {
      minimumFractionDigits = 0
      maximumFractionDigits = FieldNumber.MAXIMUM_FRACTION_DIGITS
    }

    // Update the formatters
    _localizedNumberFormatter.minimumFractionDigits = minimumFractionDigits
    _localizedNumberFormatter.maximumFractionDigits = maximumFractionDigits
    _serializedNumberFormatter.minimumFractionDigits = minimumFractionDigits
    _serializedNumberFormatter.maximumFractionDigits = maximumFractionDigits
  }

  /**
   Parses given text into a `Double` value, using a given `NSNumberFormatter`.

   - parameter text: The text to parse
   - parameter numberFormatter: The number formatter to parse the text
   - returns: The parsed value
   - throws:
   `BlocklyError`: Thrown if the text value could not be parsed into a valid `Double`.
   */
  fileprivate func valueFromText(_ text: String, numberFormatter: NumberFormatter) throws
    -> Double
  {
    let trimmedText =
      text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

    if trimmedText.isEmpty {
      throw BlocklyError(.illegalArgument,
        "An empty value cannot be parsed into a number. The value must be a valid number.")
    }

    guard let value = numberFormatter.number(from: text)?.doubleValue else {
      throw BlocklyError(.illegalArgument,
        "Could not parse value [`\(text)`] into a number. The value must be a valid number.")
    }

    if !value.isFinite {
      throw BlocklyError(.illegalArgument, "Value [`\(text)`] cannot be NaN or infinite.")
    }

    return value
  }
}
