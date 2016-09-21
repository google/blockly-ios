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
  // MARK: - Structs

  /**
   Struct for representing a unit value in both the Workspace coordinate system and UIView
   coordinate system.
   */
  public struct Unit {
    /// The unit value specified in the Workspace coordinate system
    public var workspaceUnit: CGFloat
    /// The unit value specified in the UIView coordinate system
    public var viewUnit: CGFloat

    public init(_ workspaceUnit: CGFloat, _ viewUnit: CGFloat? = nil) {
      self.workspaceUnit = workspaceUnit
      self.viewUnit = viewUnit ?? workspaceUnit
    }
  }

  /**
   Struct for representing a Size value (i.e. width/height) in both the Workspace coordinate
   system and UIView coordinate system.
   */
  public struct Size {
    /// The size value specified in the Workspace coordinate system
    public var workspaceSize: WorkspaceSize
    /// The size value specified in the UIView coordinate system
    public var viewSize: CGSize

    public init(_ workspaceSize: WorkspaceSize, _ viewSize: CGSize? = nil) {
      self.workspaceSize = workspaceSize
      self.viewSize = viewSize ?? workspaceSize
    }
  }

  // MARK: - Type Alias

  /// Type alias defining the property key.
  /// To create a new one, call `LayoutConfig.newPropertyKey()`, rather than instantiating
  /// the underlying type directly.
  public typealias PropertyKey = Int

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

  /// [`CGFloat`] For fields that use a `UITextField`, this is the maximum width that should be
  /// used for each one, specified as a UIView coordinate system unit.
  public static let FieldTextFieldMaximumWidth = LayoutConfig.newPropertyKey()

  /// [`Double`] The animation duration to use when running animatable code inside a `LayoutView`.
  public static let ViewAnimationDuration = LayoutConfig.newPropertyKey()

  // MARK: - Properties

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
    setSize(Size(WorkspaceSize(width: 44, height: 44)), for: LayoutConfig.FieldColorButtonSize)
    setUnit(Unit(2), for: LayoutConfig.FieldColorButtonBorderWidth)

    // Use the default system colors by setting these config values to nil
    setColor(nil, for: LayoutConfig.FieldCheckboxSwitchOnTintColor)
    setColor(nil, for: LayoutConfig.FieldCheckboxSwitchTintColor)

    setEdgeInsets(EdgeInsets(4, 8, 4, 8), for: LayoutConfig.FieldTextFieldInsetPadding)
    setFloat(300, for: LayoutConfig.FieldTextFieldMaximumWidth)

    setDouble(0.3, for: LayoutConfig.ViewAnimationDuration)
  }

  // MARK: - Public

  /**
  Creates a new `PropertyKey`.
  */
  public static func newPropertyKey() -> PropertyKey {
    let key = NUMBER_OF_PROPERTY_KEYS
    NUMBER_OF_PROPERTY_KEYS += 1
    return key
  }

  /**
   Maps a `Unit` value to a specific `PropertyKey`.

   - Parameter unit: The `Unit` value
   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.InlineXPadding`)
   - Returns: The `unit` that was set.
   */
  @discardableResult
  public func setUnit(_ unit: Unit?, for key: PropertyKey) -> Unit? {
    _units[key] = unit
    return unit
  }

  /**
   Returns the `Unit` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.InlineXPadding`)
   - Parameter defaultValue: [Optional] If no value was found for `key`, this value is automatically
   assigned to `key` and used instead.
   - Returns: The mapped `Unit` value.
   */
  @inline(__always)
  public func unit(for key: PropertyKey, defaultValue: Unit = Unit(0, 0)) -> Unit {
    return _units[key] ?? setUnit(defaultValue, for: key)!
  }

  /**
   Returns the `viewUnit` of the `Unit` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.InlineXPadding`)
   - Parameter defaultValue: [Optional] If no value was found for `key`, this value is automatically
   assigned to `key` and used instead.
   - Returns: The `viewUnit` of the mapped `Unit` value.
   */
  @inline(__always)
  public func viewUnit(for key: PropertyKey, defaultValue: Unit = Unit(0)) -> CGFloat {
    return unit(for: key, defaultValue: defaultValue).viewUnit
  }

  /**
   Returns the `workspaceUnit` of the `Unit` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.InlineXPadding`)
   - Parameter defaultValue: [Optional] If no value was found for `key`, this value is automatically
   assigned to `key` and used instead.
   - Returns: The `workspaceUnit` of the mapped `Unit` value.
   */
  @inline(__always)
  public func workspaceUnit(for key: PropertyKey, defaultValue: Unit = Unit(0)) -> CGFloat {
    return unit(for: key, defaultValue: defaultValue).workspaceUnit
  }

  /**
   Maps a `Size` value to a specific `PropertyKey`.

   - Parameter size: The `Size` value
   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - Returns: The `size` that was set.
   */
  @discardableResult
  public func setSize(_ size: Size?, for key: PropertyKey) -> Size? {
    _sizes[key] = size
    return size
  }

  /**
   Returns the `Size` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - Parameter defaultValue: [Optional] If no `Size` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - Returns: The mapped `Size` value.
   */
  @inline(__always)
  public func size(for key: PropertyKey, defaultValue: Size = Size(WorkspaceSizeZero)) -> Size {
    return _sizes[key] ?? setSize(defaultValue, for: key)!
  }

  /**
   Returns the `viewSize` of the `Size` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - Parameter defaultValue: [Optional] If no `Size` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - Returns: The `viewSize` of the mapped `Size` value.
   */
  @inline(__always)
  public func viewSize(for key: PropertyKey, defaultValue: Size = Size(WorkspaceSizeZero))
    -> CGSize
  {
    return size(for: key).viewSize
  }

  /**
   Returns the `workspaceSize` of the `Size` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - Parameter defaultValue: [Optional] If no `Size` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - Returns: The `workspaceSize` of the mapped `Size` value.
   */
  @inline(__always)
  public func workspaceSize(for key: PropertyKey, defaultValue: Size = Size(WorkspaceSizeZero))
    -> WorkspaceSize
  {
    return size(for: key).workspaceSize
  }

  /**
   Maps a `UIColor` value to a specific `PropertyKey`.

   - Parameter color: The `UIColor` value
   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldCheckboxSwitchOnTintColor`)
   - Returns: The `color` that was set.
   */
  @discardableResult
  public func setColor(_ color: UIColor?, for key: PropertyKey) -> UIColor? {
    _colors[key] = color
    return color
  }

  /**
   Returns the `UIColor` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldCheckboxSwitchOnTintColor`)
   - Parameter defaultValue: [Optional] If no `UIColor` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - Returns: The `key`'s value
   */
  @inline(__always)
  public func color(for key: PropertyKey, defaultValue: UIColor? = nil) -> UIColor? {
    return _colors[key] ?? (defaultValue != nil ? setColor(defaultValue, for: key) : nil)
  }

  /**
   Maps a `Double` value to a specific `PropertyKey`.

   - Parameter double: The `Double` value
   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.ViewAnimationDuration`)
   - Returns: The `Double` that was set.
   */
  @discardableResult
  public func setDouble(_ double: Double, for key: PropertyKey) -> Double {
    _doubles[key] = double
    return double
  }

  /**
   Returns the `Double` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.ViewAnimationDuration`)
   - Parameter defaultValue: [Optional] If no `Double` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - Returns: The `key`'s value
   */
  @inline(__always)
  public func double(for key: PropertyKey, defaultValue: Double = 0) -> Double {
    return _doubles[key] ?? setDouble(defaultValue, for: key)
  }

  /**
   Maps a `EdgeInsets` value to a specific `PropertyKey`.

   - Parameter edgeInset: The `EdgeInsets` value
   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldInsetPadding`)
   - Returns: The `edgeInset` that was set.
   */
  @discardableResult
  public func setEdgeInsets(_ edgeInsets: EdgeInsets, for key: PropertyKey) -> EdgeInsets {
    _edgeInsets[key] = edgeInsets
    return edgeInsets
  }

  /**
   Returns the `EdgeInsets` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldInsetPadding`)
   - Parameter defaultValue: [Optional] If no `EdgeInsets` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - Returns: The `key`'s value
   */
  @inline(__always)
  public func edgeInsets(for key: PropertyKey, defaultValue: EdgeInsets = EdgeInsets())
    -> EdgeInsets
  {
    return _edgeInsets[key] ?? setEdgeInsets(defaultValue, for: key)
  }

  /**
   Maps a `CGFloat` value to a specific `PropertyKey`.

   - Parameter float: The `CGFloat` value
   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldMaximumWidth`)
   - Returns: The `float` that was set.
   */
  @discardableResult
  public func setFloat(_ float: CGFloat, for key: PropertyKey) -> CGFloat {
    _floats[key] = float
    return float
  }

  /**
   Returns the `CGFloat` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldMaximumWidth`)
   - Parameter defaultValue: [Optional] If no `CGFloat` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - Returns: The `key`'s value
   */
  @inline(__always)
  public func float(for key: PropertyKey, defaultValue: CGFloat = 0) -> CGFloat {
    return _floats[key] ?? setFloat(defaultValue, for: key)
  }

  /**
   Updates the UIView coordinate system values for all config values that have been stored
   in this instance, by using a given `LayoutEngine`.

   - Parameter engine: The `LayoutEngine` used to update all config values
   */
  open func updateViewValues(fromEngine engine: LayoutEngine) {
    for (_, var unit) in _units {
      unit.viewUnit = engine.viewUnitFromWorkspaceUnit(unit.workspaceUnit)
    }

    for (_, var size) in _sizes {
      size.viewSize = engine.viewSizeFromWorkspaceSize(size.workspaceSize)
    }
  }
}
