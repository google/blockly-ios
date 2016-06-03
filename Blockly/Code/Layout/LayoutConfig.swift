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
public class LayoutConfig: NSObject {
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

  // MARK: - Initializers

  public override init() {
    super.init()

    // Set default values for base config keys
    setUnit(Unit(10), forKey: LayoutConfig.InlineXPadding)
    setUnit(Unit(5), forKey: LayoutConfig.InlineYPadding)
    setUnit(Unit(10), forKey: LayoutConfig.WorkspaceFlowXSeparatorSpace)
    setUnit(Unit(10), forKey: LayoutConfig.WorkspaceFlowYSeparatorSpace)

    setUnit(Unit(18), forKey: LayoutConfig.FieldMinimumHeight)
    setUnit(Unit(5), forKey: LayoutConfig.FieldCornerRadius)
    setUnit(Unit(1), forKey: LayoutConfig.FieldLineWidth)
    setSize(Size(WorkspaceSizeMake(44, 44)), forKey: LayoutConfig.FieldColorButtonSize)
    setUnit(Unit(2), forKey: LayoutConfig.FieldColorButtonBorderWidth)

    // Use the default system colors by setting these config values to nil
    setColor(nil, forKey: LayoutConfig.FieldCheckboxSwitchOnTintColor)
    setColor(nil, forKey: LayoutConfig.FieldCheckboxSwitchTintColor)

    setEdgeInsets(EdgeInsets(4, 8, 4, 8), forKey: LayoutConfig.FieldTextFieldInsetPadding)
    setFloat(300, forKey: LayoutConfig.FieldTextFieldMaximumWidth)
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
  public func setUnit(unit: Unit?, forKey key: PropertyKey) -> Unit? {
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
  public func unitFor(key: PropertyKey, defaultValue: Unit = Unit(0, 0)) -> Unit {
    return _units[key] ?? setUnit(defaultValue, forKey: key)!
  }

  /**
   Returns the `viewUnit` of the `Unit` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.InlineXPadding`)
   - Parameter defaultValue: [Optional] If no value was found for `key`, this value is automatically
   assigned to `key` and used instead.
   - Returns: The `viewUnit` of the mapped `Unit` value.
   */
  @inline(__always)
  public func viewUnitFor(key: PropertyKey, defaultValue: Unit = Unit(0)) -> CGFloat {
    return unitFor(key, defaultValue: defaultValue).viewUnit
  }

  /**
   Returns the `workspaceUnit` of the `Unit` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.InlineXPadding`)
   - Parameter defaultValue: [Optional] If no value was found for `key`, this value is automatically
   assigned to `key` and used instead.
   - Returns: The `workspaceUnit` of the mapped `Unit` value.
   */
  @inline(__always)
  public func workspaceUnitFor(key: PropertyKey, defaultValue: Unit = Unit(0)) -> CGFloat {
    return unitFor(key, defaultValue: defaultValue).workspaceUnit
  }

  /**
   Maps a `Size` value to a specific `PropertyKey`.

   - Parameter size: The `Size` value
   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - Returns: The `size` that was set.
   */
  public func setSize(size: Size?, forKey key: PropertyKey) -> Size? {
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
  public func sizeFor(key: PropertyKey, defaultValue: Size = Size(WorkspaceSizeZero)) -> Size {
    return _sizes[key] ?? setSize(defaultValue, forKey: key)!
  }

  /**
   Returns the `viewSize` of the `Size` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - Parameter defaultValue: [Optional] If no `Size` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - Returns: The `viewSize` of the mapped `Size` value.
   */
  @inline(__always)
  public func viewSizeFor(key: PropertyKey, defaultValue: Size = Size(WorkspaceSizeZero)) -> CGSize
  {
    return sizeFor(key).viewSize
  }

  /**
   Returns the `workspaceSize` of the `Size` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldColorButtonSize`)
   - Parameter defaultValue: [Optional] If no `Size` was found for `key`, this value is
   automatically assigned to `key` and used instead.
   - Returns: The `workspaceSize` of the mapped `Size` value.
   */
  @inline(__always)
  public func workspaceSizeFor(key: PropertyKey, defaultValue: Size = Size(WorkspaceSizeZero))
    -> WorkspaceSize
  {
    return sizeFor(key).workspaceSize
  }

  /**
   Maps a `UIColor` value to a specific `PropertyKey`.

   - Parameter color: The `UIColor` value
   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldCheckboxSwitchOnTintColor`)
   - Returns: The `color` that was set.
   */
  public func setColor(color: UIColor?, forKey key: PropertyKey) -> UIColor? {
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
  public func colorFor(key: PropertyKey, defaultValue: UIColor? = nil) -> UIColor? {
    return _colors[key] ?? (defaultValue != nil ? setColor(defaultValue, forKey: key) : nil)
  }

  /**
   Maps a `EdgeInsets` value to a specific `PropertyKey`.

   - Parameter edgeInset: The `EdgeInsets` value
   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldInsetPadding`)
   - Returns: The `edgeInset` that was set.
   */
  public func setEdgeInsets(edgeInsets: EdgeInsets, forKey key: PropertyKey) -> EdgeInsets {
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
  public func edgeInsetsFor(key: PropertyKey, defaultValue: EdgeInsets = EdgeInsets())
    -> EdgeInsets
  {
    return _edgeInsets[key] ?? setEdgeInsets(defaultValue, forKey: key)
  }

  /**
   Maps a `CGFloat` value to a specific `PropertyKey`.

   - Parameter float: The `CGFloat` value
   - Parameter key: The `PropertyKey` (e.g. `LayoutConfig.FieldTextFieldMaximumWidth`)
   - Returns: The `float` that was set.
   */
  public func setFloat(float: CGFloat, forKey key: PropertyKey) -> CGFloat {
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
  public func floatFor(key: PropertyKey, defaultValue: CGFloat = 0) -> CGFloat {
    return _floats[key] ?? setFloat(defaultValue, forKey: key)
  }

  /**
   Updates the UIView coordinate system values for all config values that have been stored
   in this instance, by using a given `LayoutEngine`.

   - Parameter engine: The `LayoutEngine` used to update all config values
   */
  public func updateViewValuesFromEngine(engine: LayoutEngine) {
    for (_, var unit) in _units {
      unit.viewUnit = engine.viewUnitFromWorkspaceUnit(unit.workspaceUnit)
    }

    for (_, var size) in _sizes {
      size.viewSize = engine.viewSizeFromWorkspaceSize(size.workspaceSize)
    }
  }
}
