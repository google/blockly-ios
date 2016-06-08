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
 Stores config properties specific to the default layout.
 */
@objc(BKYDefaultLayoutConfig)
public class DefaultLayoutConfig: LayoutConfig {
  // MARK: - Properties

  /// [`Unit`] Rounded corner radius of a block
  public static let BlockCornerRadius = LayoutConfig.newPropertyKey()

  /// [`Unit`] Width of a regular line stroke for a block
  public static let BlockLineWidthRegular = LayoutConfig.newPropertyKey()

  /// [`Unit`] Width of a highlighted line stroke for a block
  public static let BlockLineWidthHighlight = LayoutConfig.newPropertyKey()

  /// [`Unit`] Height of a horizontal puzzle tab
  public static let PuzzleTabHeight = LayoutConfig.newPropertyKey()

  /// [`Unit`] Width of a horizontal puzzle tab
  public static let PuzzleTabWidth = LayoutConfig.newPropertyKey()

  /// [`Unit`] Width of vertical tab (including left margin)
  public static let NotchWidth = LayoutConfig.newPropertyKey()

  /// [`Unit`] Height of vertical tab
  public static let NotchHeight = LayoutConfig.newPropertyKey()

  /// [`Unit`] Height of jagged teeth at the end of collapsed blocks
  public static let BlockJaggedTeethHeight = LayoutConfig.newPropertyKey()

  /// [`Unit`] Width of jagged teeth at the end of collapsed blocks
  public static let BlockJaggedTeethWidth = LayoutConfig.newPropertyKey()

  /// [`Unit`] Vertical space to use for each of the top, middle, and bottom sections of the C-shaped
  /// statement input
  public static let StatementSectionHeight = LayoutConfig.newPropertyKey()

  /// [`Unit`] The minimum width of the top section of the C-shaped statement input (not
  /// including the statement's notch width).
  public static let StatementMinimumConnectorWidth = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The default stroke color to use when rendering a block
  public static let BlockStrokeDefaultColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The stroke color to use when rendering a highlighted block
  public static let BlockStrokeHighlightColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The stroke color to use when rendering a disabled block
  public static let BlockStrokeDisabledColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The fill color to use when rendering a disabled block
  public static let BlockFillDisabledColor = LayoutConfig.newPropertyKey()

  /// [`Float`] The default alpha value to use when rendering a block
  public static let BlockDefaultAlpha = LayoutConfig.newPropertyKey()

  /// [`Float`] The alpha value to use when rendering a disabled block
  public static let BlockDisabledAlpha = LayoutConfig.newPropertyKey()

  /// [`Float`] The alpha value to use when rendering the fill color of a dragged block
  public static let BlockDraggingFillColorAlpha = LayoutConfig.newPropertyKey()

  /// [`Float`] The alpha value to use when rendering the stroke color of a dragged block
  public static let BlockDraggingStrokeColorAlpha = LayoutConfig.newPropertyKey()

  /// [`Float`] The saturation multiplier to use when calculating a shadow block's fill/stroke
  /// colors
  public static let BlockShadowSaturationMultiplier = LayoutConfig.newPropertyKey()

  /// [`Float`] The brightness multiplier to use when calculating a shadow block's fill/stroke
  /// colors
  public static let BlockShadowBrightnessMultiplier = LayoutConfig.newPropertyKey()

  /// [`Size`] Minimum size of the inline connector
  public static let MinimumInlineConnectorSize = LayoutConfig.newPropertyKey()

  // MARK: - Initializers

  public override init() {
    super.init()

    // Set default values for known properties
    setUnit(Unit(8), forKey: DefaultLayoutConfig.BlockCornerRadius)
    setUnit(Unit(1), forKey: DefaultLayoutConfig.BlockLineWidthRegular)
    setUnit(Unit(3), forKey: DefaultLayoutConfig.BlockLineWidthHighlight)
    setUnit(Unit(20), forKey: DefaultLayoutConfig.PuzzleTabHeight)
    setUnit(Unit(8), forKey: DefaultLayoutConfig.PuzzleTabWidth)
    setUnit(Unit(30), forKey: DefaultLayoutConfig.NotchWidth)
    setUnit(Unit(4), forKey: DefaultLayoutConfig.NotchHeight)
    setUnit(Unit(20), forKey: DefaultLayoutConfig.BlockJaggedTeethHeight)
    setUnit(Unit(15), forKey: DefaultLayoutConfig.BlockJaggedTeethWidth)
    setUnit(Unit(10), forKey: DefaultLayoutConfig.StatementSectionHeight)
    setUnit(Unit(10), forKey: DefaultLayoutConfig.StatementMinimumConnectorWidth)
    setSize(Size(WorkspaceSizeMake(10, 25)), forKey: DefaultLayoutConfig.MinimumInlineConnectorSize)

    setColor(UIColor.darkGrayColor(), forKey: DefaultLayoutConfig.BlockStrokeDefaultColor)
    setColor(UIColor.blueColor(), forKey: DefaultLayoutConfig.BlockStrokeHighlightColor)
    setColor(ColorHelper.colorFromRGB("555555"),
             forKey: DefaultLayoutConfig.BlockStrokeDisabledColor)
    setColor(ColorHelper.colorFromRGB("dddddd"),
             forKey: DefaultLayoutConfig.BlockFillDisabledColor)
    setFloat(0.7, forKey: DefaultLayoutConfig.BlockDraggingFillColorAlpha)
    setFloat(0.8, forKey: DefaultLayoutConfig.BlockDraggingStrokeColorAlpha)
    setFloat(1.0, forKey: DefaultLayoutConfig.BlockDefaultAlpha)
    setFloat(0.5, forKey: DefaultLayoutConfig.BlockDisabledAlpha)
    setFloat(0.4, forKey: DefaultLayoutConfig.BlockShadowSaturationMultiplier)
    setFloat(1.2, forKey: DefaultLayoutConfig.BlockShadowBrightnessMultiplier)
  }
}
