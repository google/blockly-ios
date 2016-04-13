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

  /// Horizontal space between elements
  public static let XSeparatorSpace = LayoutConfig.newPropertyKey()

  /// Vertical space between elements
  public static let YSeparatorSpace = LayoutConfig.newPropertyKey()

  /// Horizontal padding around inline elements
  public static let InlineXPadding = LayoutConfig.newPropertyKey()

  /// Vertical padding around inline elements
  public static let InlineYPadding = LayoutConfig.newPropertyKey()

  /// Horizontal space between blocks for `WorkspaceFlowLayout`
  public static let WorkspaceFlowXSeparatorSpace = LayoutConfig.newPropertyKey()

  /// Vertical space between blocks for for `WorkspaceFlowLayout`
  public static let WorkspaceFlowYSeparatorSpace = LayoutConfig.newPropertyKey()

  /// Minimum height of field rows
  public static let FieldMinimumHeight = LayoutConfig.newPropertyKey()

  /// If necessary, the rounded corner radius of a field
  public static let FieldCornerRadius = LayoutConfig.newPropertyKey()

  /// If necessary, the line stroke width of a field
  public static let FieldLineWidth = LayoutConfig.newPropertyKey()

  /// The border width to use when rendering the colour button
  public static let FieldColourButtonBorderWidth = LayoutConfig.newPropertyKey()

  /// The button size to use when rendering a colour field
  public static let FieldColourButtonSize = LayoutConfig.newPropertyKey()

  /// The colour to use for the `FieldCheckboxView` switch's "onTintColor". A value of nil means
  /// that the system default should be used.
  public static let FieldCheckboxSwitchOnTintColor = LayoutConfig.newPropertyKey()

  /// The colour to use for the `FieldCheckboxView` switch "tintColor". A value of nil means
  /// that the system default should be used.
  public static let FieldCheckboxSwitchTintColor = LayoutConfig.newPropertyKey()

  // MARK: - Properties

  /// Dictionary mapping property keys to `Unit` values
  private var _units = Dictionary<PropertyKey, Unit>()

  /// Dictionary mapping property keys to `Size` values
  private var _sizes = Dictionary<PropertyKey, Size>()

  /// Dictionary mapping property keys to `UIColor` values
  private var _colors = Dictionary<PropertyKey, UIColor>()

  // MARK: - Initializers

  public override init() {
    super.init()

    // Set default values for base config keys
    setUnit(Unit(10), forKey: LayoutConfig.XSeparatorSpace)
    setUnit(Unit(10), forKey: LayoutConfig.YSeparatorSpace)
    setUnit(Unit(10), forKey: LayoutConfig.InlineXPadding)
    setUnit(Unit(5), forKey: LayoutConfig.InlineYPadding)
    setUnit(Unit(10), forKey: LayoutConfig.WorkspaceFlowXSeparatorSpace)
    setUnit(Unit(10), forKey: LayoutConfig.WorkspaceFlowYSeparatorSpace)

    setUnit(Unit(18), forKey: LayoutConfig.FieldMinimumHeight)
    setUnit(Unit(5), forKey: LayoutConfig.FieldCornerRadius)
    setUnit(Unit(1), forKey: LayoutConfig.FieldLineWidth)
    setSize(Size(WorkspaceSizeMake(44, 44)), forKey: LayoutConfig.FieldColourButtonSize)
    setUnit(Unit(2), forKey: LayoutConfig.FieldColourButtonBorderWidth)

    // Use the default system colours by setting these config values to nil
    setColor(nil, forKey: LayoutConfig.FieldCheckboxSwitchOnTintColor)
    setColor(nil, forKey: LayoutConfig.FieldCheckboxSwitchTintColor)
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
   - Parameter key: The `PropertyKey`
   - Returns: The `unit` that was set.
   */
  public func setUnit(unit: Unit?, forKey key: PropertyKey) -> Unit? {
    _units[key] = unit
    return unit
  }

  /**
   Returns the `Unit` value that is mapped to a specific `PropertyKey`.
   If none was found, a `Unit` value is automatically created and returned for the key.

   - Parameter key: The `PropertyKey`
   - Returns: The `Unit` that is mapped to `key`
   */
  @inline(__always)
  public func unitFor(key: PropertyKey) -> Unit {
    return _units[key] ?? setUnit(Unit(0, 0), forKey: key)!
  }

  /**
   Returns the `Unit` value that is mapped to a specific `PropertyKey`, expressed as a UIView
   coordinate system unit.
   If none was found, a default value is automatically created and returned for the key.

   - Parameter key: The `PropertyKey`
   - Returns: The `key`'s value, expressed as a UIView coordinate system unit
   */
  @inline(__always)
  public func viewUnitFor(key: PropertyKey) -> CGFloat {
    return unitFor(key).viewUnit
  }

  /**
   Returns the `Unit` value that is mapped to a specific `PropertyKey`, expressed as a Workspace
   coordinate system unit.
   If none was found, a default value is automatically created and returned for the key.

   - Parameter key: The `PropertyKey`
   - Returns: The `key`'s value, expressed as a Workspace coordinate system unit
   */
  @inline(__always)
  public func workspaceUnitFor(key: PropertyKey) -> CGFloat {
    return unitFor(key).workspaceUnit
  }

  /**
   Maps a `Size` value to a specific `PropertyKey`.

   - Parameter size: The `Size` value
   - Parameter key: The `PropertyKey`
   - Returns: The `size` that was set.
   */
  public func setSize(size: Size?, forKey key: PropertyKey) -> Size? {
    _sizes[key] = size
    return size
  }

  /**
   Returns the `Size` value that is mapped to a specific `PropertyKey`.
   If none was found, a `Size` value is automatically created and returned for the key.

   - Parameter key: The `PropertyKey`
   - Returns: The `Size` that is mapped to `key`
   */
  @inline(__always)
  public func sizeFor(key: PropertyKey) -> Size {
    return _sizes[key] ?? setSize(Size(WorkspaceSizeZero, CGSizeZero), forKey: key)!
  }

  /**
   Returns the `Size` value that is mapped to a specific `PropertyKey`, expressed as a UIView
   coordinate system size.
   If none was found, a default value is automatically created and returned for the key.

   - Parameter key: The `PropertyKey`
   - Returns: The `key`'s value, expressed as a UIView coordinate system size
   */
  @inline(__always)
  public func viewSizeFor(key: PropertyKey) -> CGSize {
    return sizeFor(key).viewSize
  }

  /**
   Returns the `Size` value that is mapped to a specific `PropertyKey`, expressed as a Workspace
   coordinate system size.
   If none was found, a default value is automatically created and returned for the key.

   - Parameter key: The `PropertyKey`
   - Returns: The `key`'s value, expressed as a Workspace coordinate system size
   */
  @inline(__always)
  public func workspaceSizeFor(key: PropertyKey) -> WorkspaceSize {
    return sizeFor(key).workspaceSize
  }

  /**
   Maps a `UIColor` value to a specific `PropertyKey`.

   - Parameter color: The `UIColor` value
   - Parameter key: The `PropertyKey`
   - Returns: The `color` that was set.
   */
  public func setColor(color: UIColor?, forKey key: PropertyKey) -> UIColor? {
    _colors[key] = color
    return color
  }

  /**
   Returns the `UIColor` value that is mapped to a specific `PropertyKey`.

   - Parameter key: The `PropertyKey`
   - Returns: The `key`'s value
   */
  @inline(__always)
  public func colorFor(key: PropertyKey) -> UIColor? {
    return _colors[key]
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
