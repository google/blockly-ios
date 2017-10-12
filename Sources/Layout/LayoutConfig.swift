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
 UI configuration for all layout elements.
 */
@objc(BKYLayoutConfig)
@objcMembers open class LayoutConfig: NSObject {
  // MARK: - Static Properties

  /// Total number of `PropertyKey` values that have been created via `newPropertyKey()`.
  private static var NUMBER_OF_PROPERTY_KEYS = 0

  /// [`Unit`] The distance to bump blocks away from each other
  public static let BlockBumpDistance = LayoutConfig.newPropertyKey()

  /// [`Unit`] The maximum distance allowed for blocks to "snap" toward each other at the end of
  /// drags, if they have compatible connections near each other.
  public static let BlockSnapDistance = LayoutConfig.newPropertyKey()

  /// [`Unit`] Horizontal padding around inline elements (such as fields or inputs)
  public static let InlineXPadding = LayoutConfig.newPropertyKey()

  /// [`Unit`] Vertical padding around inline elements (such as fields or inputs)
  public static let InlineYPadding = LayoutConfig.newPropertyKey()

  /// [`Unit`] Horizontal space between blocks for `WorkspaceFlowLayout`
  public static let WorkspaceFlowXSeparatorSpace = LayoutConfig.newPropertyKey()

  /// [`Unit`] Vertical space between blocks for for `WorkspaceFlowLayout`
  public static let WorkspaceFlowYSeparatorSpace = LayoutConfig.newPropertyKey()

  /// [`Unit`] Minimum height of field rows
  public static let FieldMinimumHeight = LayoutConfig.newPropertyKey()

  /// [`Unit`] If necessary, the rounded corner radius of a field
  public static let FieldCornerRadius = LayoutConfig.newPropertyKey()

  /// [`Unit`] If necessary, the line stroke width of a field
  public static let FieldLineWidth = LayoutConfig.newPropertyKey()

  /// [`UntypedValue`: `AnglePicker.Options`] The options to use whenever an angle picker is
  /// displayed.
  public static let FieldAnglePickerOptions = LayoutConfig.newPropertyKey()

  /// [`Unit`] The border width to use when rendering the `FieldColor` button
  public static let FieldColorButtonBorderWidth = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The border color to use when rendering the `FieldColor` button.
  public static let FieldColorButtonBorderColor = LayoutConfig.newPropertyKey()

  /// [`Size`] The button size to use when rendering a `FieldColor`
  public static let FieldColorButtonSize = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The color to use for the `FieldCheckboxView` switch's "onTintColor". A value of
  /// `nil` means that the system default should be used.
  public static let FieldCheckboxSwitchOnTintColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The color to use for the `FieldCheckboxView` switch's "tintColor". A value of
  /// `nil` means that the system default should be used.
  public static let FieldCheckboxSwitchTintColor = LayoutConfig.newPropertyKey()

  /// [`Unit`] Horizontal spacing inside a dropdown.
  public static let FieldDropdownXSpacing = LayoutConfig.newPropertyKey()

  /// [`Unit`] Vertical spacing inside a dropdown.
  public static let FieldDropdownYSpacing = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The color to use for the dropdown background.
  public static let FieldDropdownBackgroundColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The color to use for the dropdown border.
  public static let FieldDropdownBorderColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The default color for text in field labels.
  public static let FieldLabelTextColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The default color for editable text in fields.
  public static let FieldEditableTextColor = LayoutConfig.newPropertyKey()

  /// [`UntypedValue`: `NumberPad.Options`] The options to use whenever a number pad is
  /// displayed.
  public static let FieldNumberPadOptions = LayoutConfig.newPropertyKey()

  /// [`EdgeInsets`] For fields that use an `InsetTextField`, this is the `insetPadding` that
  /// should be used for each one
  public static let FieldTextFieldInsetPadding = LayoutConfig.newPropertyKey()

  /// [`Unit`] For fields that use a `UITextField`, this is the minimum width that should be
  /// used for each one.
  public static let FieldTextFieldMinimumWidth = LayoutConfig.newPropertyKey()

  /// [`Unit`] For fields that use a `UITextField`, this is the maximum width that should be
  /// used for each one.
  public static let FieldTextFieldMaximumWidth = LayoutConfig.newPropertyKey()

  /// [`Font`] The default font to use for generic text inside Blockly.
  public static let GlobalFont = LayoutConfig.newPropertyKey()

  /// [`Size`] For mutators, this is the size of the default "settings" button.
  public static let MutatorButtonSize = LayoutConfig.newPropertyKey()

  /// [`Font`] The font to use for label text inside popovers.
  public static let PopoverLabelFont = LayoutConfig.newPropertyKey()

  /// [`Font`] The font to use for title text inside popovers.
  public static let PopoverTitleFont = LayoutConfig.newPropertyKey()

  /// [`Font`] The font to use for subtitle text inside popovers.
  public static let PopoverSubtitleFont = LayoutConfig.newPropertyKey()

  /// [`Double`] The animation duration to use when running animatable code inside a `LayoutView`.
  public static let ViewAnimationDuration = LayoutConfig.newPropertyKey()

  /// [`[String]`] The variable blocks to be created in the toolbox when a variable is created.
  public static let VariableBlocks = LayoutConfig.newPropertyKey()

  /// [`[String]`] The variable blocks to be created the first time a variable is created.
  public static let UniqueVariableBlocks = LayoutConfig.newPropertyKey()

  // MARK: - Closures

  /// A closure for creating a `UIFont` from a given scale.
  public typealias FontCreator = (_ scale: CGFloat) -> UIFont

  // MARK: - Aliases

  /// Type alias defining the property key.
  /// To create a new one, call `LayoutConfig.newPropertyKey()`, rather than instantiating
  /// the underlying type directly.
  public typealias PropertyKey = Int

  /// Struct for representing a unit value in both the Workspace coordinate system and UIView
  /// coordinate system.
  public typealias Unit = LayoutConfigUnit

  /// Struct for representing a Size value (i.e. width/height) in both the Workspace coordinate
  /// system and UIView coordinate system.
  public typealias Size = LayoutConfigSize

  /// Struct for representing an `EdgeInsets` value in both the Workspace coordinate system and
  /// UIView coordinate system.
  public typealias ScaledEdgeInsets = LayoutConfigEdgeInsets

  // MARK: - Properties

  // The current scale of all values inside the config
  private var _scale: CGFloat = 1.0

  // The current popover scale of fonts inside the config
  private var _popoverScale: CGFloat = 1.0

  // NOTE: Separate dictionaries were created for each type of value as casting specific values
  // from a Dictionary<PropertyKey, Any> is a big performance hit.

  /// Dictionary mapping property keys to `Bool` values
  public private(set) var bools = Dictionary<PropertyKey, Bool>()

  /// Dictionary mapping property keys to `UIColor` values
  public private(set) var colors = Dictionary<PropertyKey, UIColor>()

  /// Dictionary mapping property keys to `Double` values
  public private(set) var doubles = Dictionary<PropertyKey, Double>()

  /// Dictionary mapping property keys to `ScaledEdgeInsets` values
  public private(set) var edgeInsets = Dictionary<PropertyKey, ScaledEdgeInsets>()

  /// Dictionary mapping property keys to `CGFloat` values
  public private(set) var floats = Dictionary<PropertyKey, CGFloat>()

  /// Dictionary mapping property keys to `ScaledFont` values.
  /// NOTE: Fonts are purposely not exposed publicly as it does not require inline support.
  private var _fonts = Dictionary<PropertyKey, ScaledFont>()

  /// Dictionary mapping property keys to `Size` values
  public private(set) var sizes = Dictionary<PropertyKey, Size>()

  /// Dictionary mapping property keys to `Unit` values
  public private(set) var units = Dictionary<PropertyKey, Unit>()

  /// Dictionary mapping property keys to `[String]` values
  public private(set) var stringArrays = Dictionary<PropertyKey, [String]>()

  /// Dictionary mapping property keys to `String` values
  public private(set) var strings = Dictionary<PropertyKey, String>()

  /// Dictionary mapping property keys to `Any` values
  public private(set) var untypedValues = Dictionary<PropertyKey, Any>()

  // MARK: - Initializers

  public override init() {
    super.init()

    // Set default values for base config keys
    setUnit(Unit(24), for: LayoutConfig.BlockBumpDistance)
    setUnit(Unit(24), for: LayoutConfig.BlockSnapDistance)
    setUnit(Unit(8), for: LayoutConfig.InlineXPadding)
    setUnit(Unit(6), for: LayoutConfig.InlineYPadding)
    setUnit(Unit(10), for: LayoutConfig.WorkspaceFlowXSeparatorSpace)
    setUnit(Unit(10), for: LayoutConfig.WorkspaceFlowYSeparatorSpace)

    setUnit(Unit(30), for: LayoutConfig.FieldMinimumHeight)
    setUnit(Unit(4), for: LayoutConfig.FieldCornerRadius)
    setUnit(Unit(1), for: LayoutConfig.FieldLineWidth)

    setUntypedValue(AnglePicker.Options(), for: LayoutConfig.FieldAnglePickerOptions)

    setSize(Size(width: 30, height: 30), for: LayoutConfig.FieldColorButtonSize)
    setUnit(Unit(2), for: LayoutConfig.FieldColorButtonBorderWidth)
    setColor(ColorPalette.grey.tint100, for: LayoutConfig.FieldColorButtonBorderColor)

    // Use the default system colors by setting these config values to nil
    setColor(nil, for: LayoutConfig.FieldCheckboxSwitchOnTintColor)
    setColor(nil, for: LayoutConfig.FieldCheckboxSwitchTintColor)
    setColor(ColorPalette.grey.tint100, for: LayoutConfig.FieldLabelTextColor)
    setColor(ColorPalette.grey.tint800, for: LayoutConfig.FieldEditableTextColor)

    setColor(ColorPalette.grey.tint50, for: LayoutConfig.FieldDropdownBackgroundColor)
    setColor(ColorPalette.grey.tint400, for: LayoutConfig.FieldDropdownBorderColor)
    setUnit(Unit(6), for: LayoutConfig.FieldDropdownXSpacing)
    setUnit(Unit(2), for: LayoutConfig.FieldDropdownYSpacing)

    setUntypedValue(NumberPad.Options(), for: LayoutConfig.FieldNumberPadOptions)

    setScaledEdgeInsets(ScaledEdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6),
                        for: LayoutConfig.FieldTextFieldInsetPadding)
    setUnit(Unit(26), for: LayoutConfig.FieldTextFieldMinimumWidth)
    setUnit(Unit(300), for: LayoutConfig.FieldTextFieldMaximumWidth)

    setSize(Size(width: 30, height: 30), for: LayoutConfig.MutatorButtonSize)

    setDouble(0.3, for: LayoutConfig.ViewAnimationDuration)

    setStringArray(["variables_get"], for: LayoutConfig.VariableBlocks)
    setStringArray(["variables_set", "math_change"], for: LayoutConfig.UniqueVariableBlocks)

    setFontCreator({ scale in
      return UIFont.boldSystemFont(ofSize: 16 * scale)
    }, for: LayoutConfig.GlobalFont)

    setFontCreator({ scale in
      return UIFont.systemFont(ofSize: 16 * scale)
    }, for: LayoutConfig.PopoverLabelFont)

    setFontCreator({ scale in
      return UIFont.systemFont(ofSize: 13 * scale)
      }, for: LayoutConfig.PopoverTitleFont)

    setFontCreator({ scale in
      return UIFont.systemFont(ofSize: 13 * scale)
      }, for: LayoutConfig.PopoverSubtitleFont)
  }

  // MARK: - Create Property Keys

  /**
   Creates a new `PropertyKey`.
   */
  public static func newPropertyKey() -> PropertyKey {
    let key = NUMBER_OF_PROPERTY_KEYS
    NUMBER_OF_PROPERTY_KEYS += 1
    return key
  }

  // MARK: - Configure Values

  /**
   Maps a `Bool` value to a specific `PropertyKey`.

   - parameter boolValue: The `Bool` value
   - parameter key: The `PropertyKey`.
   - returns: The `Bool` that was set.
   */
  @discardableResult
  public func setBool(_ boolValue: Bool, for key: PropertyKey) -> Bool {
    bools[key] = boolValue
    return boolValue
  }

  /**
   Returns the `Bool` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey`.
   - parameter defaultValue: [Optional] If no `Bool` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `key`'s value
   */
  @inline(__always)
  public func bool(for key: PropertyKey, defaultValue: Bool = false) -> Bool {
    return bools[key] ?? setBool(defaultValue, for: key)
  }

  /**
   Maps a `Double` value to a specific `PropertyKey`.

   - parameter doubleValue: The `Double` value
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.ViewAnimationDuration`)
   - returns: The `Double` that was set.
   */
  @discardableResult
  public func setDouble(_ doubleValue: Double, for key: PropertyKey) -> Double {
    doubles[key] = doubleValue
    return doubleValue
  }

  /**
   Returns the `Double` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.ViewAnimationDuration`)
   - parameter defaultValue: [Optional] If no `Double` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `key`'s value
   */
  @inline(__always)
  public func double(for key: PropertyKey, defaultValue: Double = 0) -> Double {
    return doubles[key] ?? setDouble(defaultValue, for: key)
  }

  /**
   Maps a `UIColor` value to a specific `PropertyKey`.

   - parameter color: The `UIColor` value
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldCheckboxSwitchOnTintColor`)
   - returns: The `color` that was set.
   */
  @discardableResult
  public func setColor(_ color: UIColor?, for key: PropertyKey) -> UIColor? {
    colors[key] = color
    return color
  }

  /**
   Returns the `UIColor` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldCheckboxSwitchOnTintColor`)
   - parameter defaultValue: [Optional] If no `UIColor` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `key`'s value
   */
  @inline(__always)
  public func color(for key: PropertyKey, defaultValue: UIColor? = nil) -> UIColor? {
    return colors[key] ?? (defaultValue != nil ? setColor(defaultValue, for: key) : nil)
  }

  /**
   Maps a `ScaledEdgeInsets` value to a specific `PropertyKey`.

   - parameter edgeInsets: The `ScaledEdgeInsets` value
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldInsetPadding`)
   - returns: The `edgeInsets` value.
   */
  @discardableResult
  public func setScaledEdgeInsets(_ edgeInsets: ScaledEdgeInsets, for key: PropertyKey)
    -> ScaledEdgeInsets {
    self.edgeInsets[key] = edgeInsets
    return edgeInsets
  }

  /**
   Returns the `ScaledEdgeInsets` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldInsetPadding`)
   - parameter defaultValue: [Optional] If no `ScaledEdgeInsets` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `key`'s value.
   */
  @inline(__always)
  public func scaledEdgeInsets(
    for key: PropertyKey, defaultValue: ScaledEdgeInsets = ScaledEdgeInsets.zero)
    -> ScaledEdgeInsets
  {
    return edgeInsets[key] ?? setScaledEdgeInsets(defaultValue, for: key)
  }

  /**
   Returns the `viewEdgeInsets` of the `ScaledEdgeInsets` value that is mapped to a specific
   `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldInsetPadding`)
   - parameter defaultValue: [Optional] If no `ScaledEdgeInsets` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `viewEdgeInsets` of the mapped `ScaledEdgeInsets` value.
   */
  @inline(__always)
  public func viewEdgeInsets(
    for key: PropertyKey, defaultValue: ScaledEdgeInsets = ScaledEdgeInsets.zero) -> EdgeInsets
  {
    return edgeInsets[key]?.viewEdgeInsets
      ?? setScaledEdgeInsets(defaultValue, for: key).viewEdgeInsets
  }

  /**
   Returns the `workspaceEdgeInsets` of the `ScaledEdgeInsets` value that is mapped to a specific
   `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldInsetPadding`)
   - parameter defaultValue: [Optional] If no `ScaledEdgeInsets` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `workspaceEdgeInsets` of the mapped `ScaledEdgeInsets` value.
   */
  @inline(__always)
  public func workspaceEdgeInsets(
    for key: PropertyKey, defaultValue: ScaledEdgeInsets = ScaledEdgeInsets.zero) -> EdgeInsets
  {
    return edgeInsets[key]?.workspaceEdgeInsets
      ?? setScaledEdgeInsets(defaultValue, for: key).workspaceEdgeInsets
  }

  /**
   Maps a `CGFloat` value to a specific `PropertyKey`.

   - parameter floatValue: The `CGFloat` value
   - parameter key: The `PropertyKey` (e.g. `DefaultLayoutConfig.BlockShadowBrightnessMultiplier`)
   - returns: The `CGFloat` that was set.
   */
  @discardableResult
  public func setFloat(_ floatValue: CGFloat, for key: PropertyKey) -> CGFloat {
    floats[key] = floatValue
    return floatValue
  }

  /**
   Returns the `CGFloat` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldMaximumWidth`)
   - parameter defaultValue: [Optional] If no `CGFloat` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `key`'s value
   */
  @inline(__always)
  public func float(for key: PropertyKey, defaultValue: CGFloat = 0) -> CGFloat {
    return floats[key] ?? setFloat(defaultValue, for: key)
  }

  /**
   Maps a closure for creating a `UIFont`, to a specific `PropertyKey`.

   - parameter fontCreator: A closure for creating a `UIFont`, based on a given `scale` value.
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.GlobalFont`)
   */
  public func setFontCreator(_ fontCreator: @escaping FontCreator, for key: PropertyKey) {
    _fonts[key] =
      ScaledFont(creator: fontCreator, fontScale: _scale, popoverFontScale: _popoverScale)
  }

  /**
   Returns the closure for creating a `UIFont` that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.GlobalFont`)
   - returns: If the `key` was found, its associated `FontCreator` value. Otherwise, `nil` is
   returned.
   */
  public func fontCreator(for key: PropertyKey) -> FontCreator? {
    return _fonts[key]?.creator
  }

  /**
   Based on the closure for creating a `UIFont` associated to a specific `PropertyKey`, returns
   a scaled `UIFont`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.GlobalFont`)
   - returns: The scaled `UIFont` using the closure associated with the `key`, or a default `UIFont`
   if the key could not be located.
   */
  public func font(for key: PropertyKey) -> UIFont {
    return _fonts[key]?.font ?? UIFont.systemFont(ofSize: 16 * _scale)
  }

  /**
   Based on the closure for creating a `UIFont` associated to a specific `PropertyKey`, returns
   a scaled `UIFont` for use inside a popover.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.GlobalFont`)
   - returns: The scaled `UIFont` using the closure associated with the `key`, or a default `UIFont`
   if the key could not be located.
   */
  public func popoverFont(for key: PropertyKey) -> UIFont {
    return _fonts[key]?.popoverFont ?? UIFont.systemFont(ofSize: 16 * _popoverScale)
  }

  /**
   Maps a `Size` value to a specific `PropertyKey`.

   - parameter size: The `Size` value
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - returns: The `size` that was set.
   */
  @discardableResult
  public func setSize(_ size: Size, for key: PropertyKey) -> Size {
    sizes[key] = size
    return size
  }

  /**
   Returns the `Size` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - parameter defaultValue: [Optional] If no `Size` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The mapped `Size` value.
   */
  @inline(__always)
  public func size(for key: PropertyKey, defaultValue: Size = Size(width: 0, height: 0)) -> Size {
    return sizes[key] ?? setSize(defaultValue, for: key)
  }

  /**
   Returns the `viewSize` of the `Size` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - parameter defaultValue: [Optional] If no `Size` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `viewSize` of the mapped `Size` value.
   */
  @inline(__always)
  public func viewSize(for key: PropertyKey, defaultValue: Size = Size(width: 0, height: 0))
    -> CGSize
  {
    return size(for: key, defaultValue: defaultValue).viewSize
  }

  /**
   Returns the `workspaceSize` of the `Size` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - parameter defaultValue: [Optional] If no `Size` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `workspaceSize` of the mapped `Size` value.
   */
  @inline(__always)
  public func workspaceSize(for key: PropertyKey, defaultValue: Size = Size(width: 0, height: 0))
    -> WorkspaceSize
  {
    return size(for: key, defaultValue: defaultValue).workspaceSize
  }

  /**
   Maps a `Unit` value to a specific `PropertyKey`.

   - parameter unit: The `Unit` value
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.InlineXPadding`)
   - returns: The `unit` that was set.
   */
  @discardableResult
  public func setUnit(_ unit: Unit, for key: PropertyKey) -> Unit {
    units[key] = unit
    return unit
  }

  /**
   Returns the `Unit` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.InlineXPadding`)
   - parameter defaultValue: [Optional] If no value was found for `key`, this value is automatically
   assigned to `key` and used instead.
   - returns: The mapped `Unit` value.
   */
  @inline(__always)
  public func unit(for key: PropertyKey, defaultValue: Unit = Unit(0)) -> Unit {
    return units[key] ?? setUnit(defaultValue, for: key)
  }

  /**
   Returns the `viewUnit` of the `Unit` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.InlineXPadding`)
   - parameter defaultValue: [Optional] If no value was found for `key`, this value is automatically
   assigned to `key` and used instead.
   - returns: The `viewUnit` of the mapped `Unit` value.
   */
  @inline(__always)
  public func viewUnit(for key: PropertyKey, defaultValue: Unit = Unit(0)) -> CGFloat {
    return unit(for: key, defaultValue: defaultValue).viewUnit
  }

  /**
   Returns the `workspaceUnit` of the `Unit` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.InlineXPadding`)
   - parameter defaultValue: [Optional] If no value was found for `key`, this value is automatically
   assigned to `key` and used instead.
   - returns: The `workspaceUnit` of the mapped `Unit` value.
   */
  @inline(__always)
  public func workspaceUnit(for key: PropertyKey, defaultValue: Unit = Unit(0)) -> CGFloat {
    return unit(for: key, defaultValue: defaultValue).workspaceUnit
  }

  /**
   Maps a `[String]` value to a specific `PropertyKey`.

   - parameter stringArrayValue: The `[String]` value
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.VariableBlocks`)
   - returns: The `[String]` that was set.
   */
  @discardableResult
  public func setStringArray(_ stringArrayValue: [String], for key: PropertyKey) -> [String] {
    stringArrays[key] = stringArrayValue
    return stringArrayValue
  }


  /**
   Returns the `[String]` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.VariableBlocks`)
   - parameter defaultValue: [Optional] If no `[String]` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `key`'s value
   */
  @inline(__always)
  public func stringArray(for key: PropertyKey, defaultValue: [String] = []) -> [String] {
    return stringArrays[key] ?? setStringArray(defaultValue, for: key)
  }

  /**
   Maps a `String` value to a specific `PropertyKey`.

   - parameter stringValue: The `String` value.
   - parameter key: The `PropertyKey` (e.g. `DefaultLayoutConfig.BlockHat`).
   - returns: The `String` that was set.
   */
  @discardableResult
  public func setString(_ stringValue: String, for key: PropertyKey) -> String {
    strings[key] = stringValue
    return stringValue
  }


  /**
   Returns the `String` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `DefaultLayoutConfig.BlockHat`).
   - parameter defaultValue: [Optional] If no `String` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `key`'s value.
   */
  @inline(__always)
  public func string(for key: PropertyKey, defaultValue: String = "") -> String {
    return strings[key] ?? setString(defaultValue, for: key)
  }

  /**
   Maps an `Any?` value to a specific `PropertyKey`.

   - note: Retrieving untyped values is slow and should be avoided whenever possible. It should
   only be done for code that is not performance-reliant.
   - parameter untypedValue: The `Any?` value.
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.`).
   - returns: The `Any?` value that was set.
   */
  @discardableResult
  public func setUntypedValue(_ untypedValue: Any?, for key: PropertyKey) -> Any? {
    untypedValues[key] = untypedValue
    return untypedValue
  }

  /**
   Returns the `Any?` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.VariableBlocks`)
   - parameter defaultValue: [Optional] If no value was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `key`'s value
   */
  @inline(__always)
  public func untypedValue(for key: PropertyKey, defaultValue: Any? = nil) -> Any? {
    return untypedValues[key] ?? setUntypedValue(defaultValue, for: key)
  }

  // MARK: - Update Values

  /**
   Updates the UIView coordinate system values for all config values that have been stored
   in this instance, by using a given `LayoutEngine`.

   - parameter engine: The `LayoutEngine` used to update all config values
   */
  open func updateViewValues(fromEngine engine: LayoutEngine) {
    _scale = engine.scale
    _popoverScale = engine.popoverScale

    for (key, var unit) in units {
      unit.viewUnit = engine.viewUnitFromWorkspaceUnit(unit.workspaceUnit)
      units[key] = unit
    }

    for (key, var size) in sizes {
      size.viewSize = engine.viewSizeFromWorkspaceSize(size.workspaceSize)
      sizes[key] = size
    }

    for (key, var scaledEdgeInsets) in edgeInsets {
      let workspaceEdgeInsets = scaledEdgeInsets.workspaceEdgeInsets
      scaledEdgeInsets.viewEdgeInsets =
        EdgeInsets(top: engine.viewUnitFromWorkspaceUnit(workspaceEdgeInsets.top),
                   leading: engine.viewUnitFromWorkspaceUnit(workspaceEdgeInsets.leading),
                   bottom: engine.viewUnitFromWorkspaceUnit(workspaceEdgeInsets.bottom),
                   trailing: engine.viewUnitFromWorkspaceUnit(workspaceEdgeInsets.trailing))
      edgeInsets[key] = scaledEdgeInsets
    }

    for (_, scaledFont) in _fonts {
      scaledFont.font = scaledFont.creator(_scale)
      scaledFont.popoverFont = scaledFont.creator(_popoverScale)
    }
  }
}

extension LayoutConfig {
  // MARK: - ScaledFont Class

  /**
   Helper class for storing a `FontCreator` and a copy of its currently scaled font.
   */
  fileprivate class ScaledFont {
    let creator: FontCreator
    var font: UIFont
    var popoverFont: UIFont

    init(creator: @escaping FontCreator, fontScale: CGFloat, popoverFontScale: CGFloat) {
      self.creator = creator
      self.font = creator(fontScale)
      self.popoverFont = creator(popoverFontScale)
    }
  }
}
