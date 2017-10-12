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

extension Field {
  // MARK: - Static Properties

  // Field types
  fileprivate static let FIELD_TYPE_ANGLE = "field_angle"
  fileprivate static let FIELD_TYPE_CHECKBOX = "field_checkbox"
  // To maintain compatibility with Web Blockly, this value is spelled as "field_colour" and not
  // "field_color"
  fileprivate static let FIELD_TYPE_COLOR = "field_colour"
  fileprivate static let FIELD_TYPE_DATE = "field_date"
  fileprivate static let FIELD_TYPE_DROPDOWN = "field_dropdown"
  fileprivate static let FIELD_TYPE_IMAGE = "field_image"
  fileprivate static let FIELD_TYPE_INPUT = "field_input"
  fileprivate static let FIELD_TYPE_LABEL = "field_label"
  fileprivate static let FIELD_TYPE_NUMBER = "field_number"
  fileprivate static let FIELD_TYPE_VARIABLE = "field_variable"

  // JSON parameters
  fileprivate static let PARAMETER_ALT_TEXT = "alt"
  fileprivate static let PARAMETER_ANGLE = "angle"
  fileprivate static let PARAMETER_CHECKED = "checked"
  // To maintain compatibility with Web Blockly, this value is spelled as "colour" and not "color"
  fileprivate static let PARAMETER_COLOR = "colour"
  fileprivate static let PARAMETER_DATE = "date"
  fileprivate static let PARAMETER_HEIGHT = "height"
  fileprivate static let PARAMETER_IMAGE_URL = "src"
  fileprivate static let PARAMETER_IMAGE_FLIP_RTL = "flipRtl"
  fileprivate static let PARAMETER_MINIMUM_VALUE = "min"
  fileprivate static let PARAMETER_MAXIMUM_VALUE = "max"
  fileprivate static let PARAMETER_NAME = "name"
  fileprivate static let PARAMETER_OPTIONS = "options"
  fileprivate static let PARAMETER_PRECISION = "precision"
  fileprivate static let PARAMETER_TEXT = "text"
  fileprivate static let PARAMETER_TYPE = "type"
  fileprivate static let PARAMETER_VALUE = "value"
  fileprivate static let PARAMETER_VARIABLE = "variable"
  fileprivate static let PARAMETER_WIDTH = "width"

  // MARK: - Internal

  /**
  Creates a new `Field` from a JSON dictionary.

  - parameter json: JSON dictionary
  - throws:
  `BlocklyError`: Occurs if malformed JSON data was passed in.
  - returns: A `Field` instance based on the JSON dictionary, or `nil` if there wasn't sufficient
  data in the dictionary.
  */
  internal static func makeField(json: [String: Any]) throws -> Field? {
    let type = json[PARAMETER_TYPE] as? String ?? ""
    if let creationHandler = Field.JSONRegistry.shared[type] {
      return try creationHandler(json)
    } else {
      return nil
    }
  }
}

extension Field {
  /**
   Manages the registration of fields.

   This class is designed as a singleton instance, accessible via
   `Field.JSONRegistry.shared`.
   */
  @objc(BKYFieldJSONRegistry)
  @objcMembers public final class JSONRegistry: NSObject {
    // MARK: - Static Properties

    /// Shared instance.
    public static let shared = JSONRegistry()

    // MARK: - Closures

    /// Callback for creating a Field instance from JSON
    public typealias CreationHandler = (_ json: [String: Any]) throws -> Field

    // MARK: - Properties

    /// Dictionary mapping JSON field types to its creation handler.
    fileprivate var _registry = [String: CreationHandler]()
    public subscript(key: String) -> CreationHandler? {
      get { return _registry[key.lowercased()] }
      set { _registry[key.lowercased()] = newValue }
    }

    // MARK: - Initializers

    /**
     A singleton instance for this class is accessible via `Field.JSONRegistry.shared.`
     */
    private override init() {
      super.init()

      // Fill the JSON registry with the built-in Blockly types.

      // Angle
      registerType(FIELD_TYPE_ANGLE) {
        (json: [String: Any]) throws -> Field in
        // NOTE: name and angle are declared in their own variables here to get around an
        // Xcode 8.3/Swift 3.1 whole-module-optimization compiler bug.
        let name = (json[PARAMETER_NAME] as? String ?? "NAME")
        let angle = JSONRegistry.parseDouble(json[PARAMETER_ANGLE]) ?? 90
        return FieldAngle(name: name, angle: angle)
      }

      // Checkbox
      registerType(FIELD_TYPE_CHECKBOX) {
        (json: [String: Any]) throws -> Field in
        return FieldCheckbox(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          checked: (json[PARAMETER_CHECKED] as? Bool ?? true))
      }

      // Color
      registerType(FIELD_TYPE_COLOR) {
        (json: [String: Any]) throws -> Field in
        let colorString = json[PARAMETER_COLOR] as? String ?? ""
        let color = ColorHelper.makeColor(rgb: colorString)
        return FieldColor(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          color: (color ?? UIColor.red))
      }

      // Date
      registerType(FIELD_TYPE_DATE) {
        (json: [String: Any]) throws -> Field in
        return FieldDate(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          stringDate: (json[PARAMETER_DATE] as? String ?? ""))
      }

      // Dropdown
      registerType(FIELD_TYPE_DROPDOWN) {
        (json: [String: Any]) throws -> Field in
        // Options should be an array of string arrays.
        // eg. [["Name 1", "Value 1"], ["Name 2", "Value 2"]]
        let options = json[PARAMETER_OPTIONS] as? Array<[String]> ?? []

        // Check that all arrays contain exactly two values and that the second value is not empty
        if (options.filter { ($0.count != 2) || ($0[1] == "") }.count > 0) {
          throw BlocklyError(.invalidBlockDefinition, "Each dropdown field option must contain " +
            "exactly two String values and the second value must not be empty.")
        }

        return FieldDropdown(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          // Reconstruct options into array of (String, String) tuples
          // eg. [(displayName: "Name 1", value: "Value 1"),
          //     (displayName: "Name 2", value: "Value 2")]
          options: options.map {
            (displayName: MessageManager.shared.decodedString($0[0]), value: $0[1])
          },
          selectedIndex: 0)
      }

      // Image
      registerType(FIELD_TYPE_IMAGE) {
        (json: [String: Any]) throws -> Field in
        return FieldImage(
          name: (json[PARAMETER_NAME] as? String ?? ""),
          imageLocation: (Block.decodedJSONValue(json[PARAMETER_IMAGE_URL]) as? String ??
            "https://www.gstatic.com/codesite/ph/images/star_on.gif"),
          size: WorkspaceSize(
            width: CGFloat((json[PARAMETER_WIDTH] as? Int) ?? 15),
            height: CGFloat((json[PARAMETER_HEIGHT] as? Int) ?? 15)),
          altText: (Block.decodedJSONValue(json[PARAMETER_ALT_TEXT]) as? String ?? "*"),
          flipRtl: (json[PARAMETER_IMAGE_FLIP_RTL] as? Bool ?? false))
      }

      // Input
      registerType(FIELD_TYPE_INPUT) {
        (json: [String: Any]) throws -> Field in
        return FieldInput(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          text: (Block.decodedJSONValue(json[PARAMETER_TEXT]) as? String ?? "default"))
      }

      // Label
      registerType(FIELD_TYPE_LABEL) {
        (json: [String: Any]) throws -> Field in
        return FieldLabel(
          name: (json[PARAMETER_NAME] as? String ?? ""),
          text: (Block.decodedJSONValue(json[PARAMETER_TEXT]) as? String ?? ""))
      }

      // Number
      registerType(FIELD_TYPE_NUMBER) {
        (json: [String: Any]) throws -> Field in

        let value = JSONRegistry.parseDouble(json[PARAMETER_VALUE]) ?? 0.0
        let minimum = JSONRegistry.parseDouble(json[PARAMETER_MINIMUM_VALUE])
        let maximum = JSONRegistry.parseDouble(json[PARAMETER_MAXIMUM_VALUE])
        let precision = JSONRegistry.parseDouble(json[PARAMETER_PRECISION])

        let fieldNumber = FieldNumber(name: (json[PARAMETER_NAME] as? String ?? ""), value: value)
        try fieldNumber.setConstraints(minimum: minimum, maximum: maximum, precision: precision)
        return fieldNumber
      }

      // Variable
      registerType(FIELD_TYPE_VARIABLE) {
        (json: [String: Any]) throws -> Field in
        return FieldVariable(
          name: (json[PARAMETER_NAME] as? String ?? "NAME"),
          variable: (Block.decodedJSONValue(json[PARAMETER_VARIABLE]) as? String ?? "item"))
      }
    }

    // MARK: - Public

    /**
    Registers a JSON creation handler for a given field key.

    - parameter type: The key for a field type.
    - parameter creationHandler: The `CreationHandler` to use for this field key.
    */
    public func registerType(_ type: String, creationHandler: @escaping CreationHandler) {
      _registry[type] = creationHandler
    }

    /**
    Unregisters a JSON creation handler for a given field key.

    - parameter type: The key for a field type.
    */
    public func unregisterType(_ type: String) {
      _registry[type] = nil
    }

    // MARK: - Private

    fileprivate static func parseDouble(_ any: Any?) -> Double? {
      if let double = any as? Double {
        return double
      } else if let integer = any as? Int {
        // Use-case where Swift parsed `any` as an Int first, so we need to reconstruct it as a
        // Double.
        return Double(integer)
      }
      return nil
    }

    fileprivate static func parseInt(_ any: Any?) -> Int? {
      // NOTE: While the code below (`any as? Int`) could simply be done at the location of the
      // caller, there's a bug with the Xcode 8.3.1/Swift 3.1 compiler where this doesn't work
      // properly when whole-module-optimization is turned on.
      // Moving this code into a function seems to fix the problem.
      if let integer = any as? Int {
        return integer
      }
      return nil
    }
  }
}
