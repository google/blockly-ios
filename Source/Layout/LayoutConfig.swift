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
open class LayoutConfig: NSObject {
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

  /// [`Unit`] The border width to use when rendering the `FieldColor` button
  public static let FieldColorButtonBorderWidth = LayoutConfig.newPropertyKey()

  /// [`Size`] The button size to use when rendering a `FieldColor`
  public static let FieldColorButtonSize = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The color to use for the `FieldCheckboxView` switch's "onTintColor". A value of
  /// `nil` means that the system default should be used.
  public static let FieldCheckboxSwitchOnTintColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The color to use for the `FieldCheckboxView` switch's "tintColor". A value of
  /// `nil` means that the system default should be used.
  public static let FieldCheckboxSwitchTintColor = LayoutConfig.newPropertyKey()

  /// [`EdgeInsets`] For fields that use an `InsetTextField`, this is the `insetPadding` that
  /// should be used for each one
  public static let FieldTextFieldInsetPadding = LayoutConfig.newPropertyKey()

  /// [`Unit`] For fields that use a `UITextField`, this is the maximum width that should be
  /// used for each one.
  public static let FieldTextFieldMaximumWidth = LayoutConfig.newPropertyKey()

  /// [`Font`] The default font to use for all text inside Blockly.
  public static let GlobalFont = LayoutConfig.newPropertyKey()

  /// [`Double`] The animation duration to use when running animatable code inside a `LayoutView`.
  public static let ViewAnimationDuration = LayoutConfig.newPropertyKey()

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

  // MARK: - Properties

  // The current scale of all values inside the config
  private var _scale: CGFloat = 1.0;

  // NOTE: Separate dictionaries were created for each type of value as casting specific values
  // from a Dictionary<PropertyKey, Any> is a big performance hit.

  /// Dictionary mapping property keys to `Unit` values
  private var _units = Dictionary<PropertyKey, Unit>()

  /// Dictionary mapping property keys to `Size` values
  private var _sizes = Dictionary<PropertyKey, Size>()

  /// Dictionary mapping property keys to `UIColor` values
  private var _colors = Dictionary<PropertyKey, UIColor>()

  /// Dictionary mapping property keys to `EdgeInsets` values
  private var _edgeInsets = Dictionary<PropertyKey, EdgeInsets>()

  /// Dictionary mapping property keys to `CGFloat` values
  private var _floats = Dictionary<PropertyKey, CGFloat>()

  /// Dictionary mapping property keys to `Double` values
  private var _doubles = Dictionary<PropertyKey, Double>()

  /// Dictionary mapping property keys to `ScaledFont` values
  private var _fonts = Dictionary<PropertyKey, ScaledFont>()

  // MARK: - Initializers

  public override init() {
    super.init()

    // Set default values for base config keys
    setUnit(Unit(25), for: LayoutConfig.BlockBumpDistance)
    setUnit(Unit(25), for: LayoutConfig.BlockSnapDistance)
    setUnit(Unit(10), for: LayoutConfig.InlineXPadding)
    setUnit(Unit(5), for: LayoutConfig.InlineYPadding)
    setUnit(Unit(10), for: LayoutConfig.WorkspaceFlowXSeparatorSpace)
    setUnit(Unit(10), for: LayoutConfig.WorkspaceFlowYSeparatorSpace)

    setUnit(Unit(18), for: LayoutConfig.FieldMinimumHeight)
    setUnit(Unit(5), for: LayoutConfig.FieldCornerRadius)
    setUnit(Unit(1), for: LayoutConfig.FieldLineWidth)
    setSize(Size(44, 44), for: LayoutConfig.FieldColorButtonSize)
    setUnit(Unit(2), for: LayoutConfig.FieldColorButtonBorderWidth)

    // Use the default system colors by setting these config values to nil
    setColor(nil, for: LayoutConfig.FieldCheckboxSwitchOnTintColor)
    setColor(nil, for: LayoutConfig.FieldCheckboxSwitchTintColor)

    setEdgeInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8),
                  for: LayoutConfig.FieldTextFieldInsetPadding)
    setUnit(Unit(300), for: LayoutConfig.FieldTextFieldMaximumWidth)

    setDouble(0.3, for: LayoutConfig.ViewAnimationDuration)

    setFontCreator({ scale in
      return UIFont.systemFont(ofSize: 14 * scale)
    }, for: LayoutConfig.GlobalFont)
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
   Maps a `Double` value to a specific `PropertyKey`.

   - parameter doubleValue: The `Double` value
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.ViewAnimationDuration`)
   - returns: The `Double` that was set.
   */
  @discardableResult
  public func setDouble(_ doubleValue: Double, for key: PropertyKey) -> Double {
    _doubles[key] = doubleValue
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
    return _doubles[key] ?? setDouble(defaultValue, for: key)
  }
  
  /**
   Maps a `UIColor` value to a specific `PropertyKey`.

   - parameter color: The `UIColor` value
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldCheckboxSwitchOnTintColor`)
   - returns: The `color` that was set.
   */
  @discardableResult
  public func setColor(_ color: UIColor?, for key: PropertyKey) -> UIColor? {
    _colors[key] = color
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
    return _colors[key] ?? (defaultValue != nil ? setColor(defaultValue, for: key) : nil)
  }
  
  /**
   Maps a `EdgeInsets` value to a specific `PropertyKey`.

   - parameter edgeInsets: The `EdgeInsets` value
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldInsetPadding`)
   - returns: The `edgeInset` that was set.
   */
  @discardableResult
  public func setEdgeInsets(_ edgeInsets: EdgeInsets, for key: PropertyKey) -> EdgeInsets {
    _edgeInsets[key] = edgeInsets
    return edgeInsets
  }

  /**
   Returns the `EdgeInsets` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldInsetPadding`)
   - parameter defaultValue: [Optional] If no `EdgeInsets` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `key`'s value
   */
  @inline(__always)
  public func edgeInsets(for key: PropertyKey, defaultValue: EdgeInsets = EdgeInsets())
    -> EdgeInsets
  {
    return _edgeInsets[key] ?? setEdgeInsets(defaultValue, for: key)
  }

  /**
   Maps a `CGFloat` value to a specific `PropertyKey`.

   - parameter floatValue: The `CGFloat` value
   - parameter key: The `PropertyKey` (e.g. `DefaultLayoutConfig.BlockShadowBrightnessMultiplier`)
   - returns: The `CGFloat` that was set.
   */
  @discardableResult
  public func setFloat(_ floatValue: CGFloat, for key: PropertyKey) -> CGFloat {
    _floats[key] = floatValue
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
    return _floats[key] ?? setFloat(defaultValue, for: key)
  }

  /**
   Maps a closure for creating a `UIFont`, to a specific `PropertyKey`.

   - parameter fontCreator: A closure for creating a `UIFont`, based on a given `scale` value.
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.GlobalFont`)
   */
  public func setFontCreator(_ fontCreator: @escaping FontCreator, for key: PropertyKey) {
    _fonts[key] = ScaledFont(creator: fontCreator, currentScale: _scale)
  }

  /**
   Returns the closure for creating a `UIFont` that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.GlobalFont`)
   - returns: If the `key` was found, its associated `FontCreator` value. Otherwise, `nil` is
   returned.
   */
  @inline(__always)
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
  @inline(__always)
  public func font(for key: PropertyKey) -> UIFont {
    return _fonts[key]?.font ?? UIFont.systemFont(ofSize: 14 * _scale)
  }

  /**
   Maps a `Size` value to a specific `PropertyKey`.

   - parameter size: The `Size` value
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - returns: The `size` that was set.
   */
  @discardableResult
  public func setSize(_ size: Size, for key: PropertyKey) -> Size {
    _sizes[key] = size
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
  public func size(for key: PropertyKey, defaultValue: Size = Size(0, 0)) -> Size {
    return _sizes[key] ?? setSize(defaultValue, for: key)
  }

  /**
   Returns the `viewSize` of the `Size` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - parameter defaultValue: [Optional] If no `Size` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `viewSize` of the mapped `Size` value.
   */
  @inline(__always)
  public func viewSize(for key: PropertyKey, defaultValue: Size = Size(0, 0))
    -> CGSize
  {
    return size(for: key).viewSize
  }

  /**
   Returns the `workspaceSize` of the `Size` value that is mapped to a specific `PropertyKey`.

   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - parameter defaultValue: [Optional] If no `Size` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - returns: The `workspaceSize` of the mapped `Size` value.
   */
  @inline(__always)
  public func workspaceSize(for key: PropertyKey, defaultValue: Size = Size(0, 0))
    -> WorkspaceSize
  {
    return size(for: key).workspaceSize
  }
  
  /**
   Maps a `Unit` value to a specific `PropertyKey`.

   - parameter unit: The `Unit` value
   - parameter key: The `PropertyKey` (e.g. `LayoutConfig.InlineXPadding`)
   - returns: The `unit` that was set.
   */
  @discardableResult
  public func setUnit(_ unit: Unit, for key: PropertyKey) -> Unit {
    _units[key] = unit
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
    return _units[key] ?? setUnit(defaultValue, for: key)
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

  // MARK: - Update Values

  /**
   Updates the UIView coordinate system values for all config values that have been stored
   in this instance, by using a given `LayoutEngine`.

   - parameter engine: The `LayoutEngine` used to update all config values
   */
  open func updateViewValues(fromEngine engine: LayoutEngine) {
    _scale = engine.scale

    for (key, var unit) in _units {
      unit.viewUnit = engine.viewUnitFromWorkspaceUnit(unit.workspaceUnit)
      _units[key] = unit
    }

    for (key, var size) in _sizes {
      size.viewSize = engine.viewSizeFromWorkspaceSize(size.workspaceSize)
      _sizes[key] = size
    }

    for (_, scaledFont) in _fonts {
      scaledFont.font = scaledFont.creator(_scale)
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

    init(creator: @escaping FontCreator, currentScale: CGFloat) {
      self.creator = creator
      self.font = creator(currentScale)
    }
  }
}
