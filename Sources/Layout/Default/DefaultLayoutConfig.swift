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
@objcMembers open class DefaultLayoutConfig: LayoutConfig {
  // MARK: - Properties

  /// [`Unit`] Rounded corner radius of a block
  public static let BlockCornerRadius = LayoutConfig.newPropertyKey()

  /// [`Unit`] Width of a regular line stroke for a block
  public static let BlockLineWidthRegular = LayoutConfig.newPropertyKey()

  /// [`Unit`] Width of a highlighted line stroke for a block
  public static let BlockLineWidthHighlight = LayoutConfig.newPropertyKey()

  /// [`Unit`] Width of the line stroke for a highlighted connection.
  public static let BlockConnectionLineWidthHighlight = LayoutConfig.newPropertyKey()

  /// [`Unit`] Height of a horizontal puzzle tab
  public static let PuzzleTabHeight = LayoutConfig.newPropertyKey()

  /// [`Unit`] Width of a horizontal puzzle tab
  public static let PuzzleTabWidth = LayoutConfig.newPropertyKey()

  /// [`Unit`] The x-offset from which to start drawing the notch, relative to the left edge.
  /// This value should be greater than or equal to the value specified for
  /// `DefaultLayoutConfig.BlockCornerRadius`.
  public static let NotchXOffset = LayoutConfig.newPropertyKey()

  /// [`Unit`] The width of the notch (including both diagonal lines and the bottom line).
  public static let NotchWidth = LayoutConfig.newPropertyKey()

  /// [`Unit`] The height of the notch.
  public static let NotchHeight = LayoutConfig.newPropertyKey()

  /// [`Unit`] Vertical space to use for each of the top, middle, and bottom sections of the
  /// C-shaped statement input
  public static let StatementSectionHeight = LayoutConfig.newPropertyKey()

  /// [`Unit`] The minimum amount of horizontal space to use for the spine of the C-shaped
  /// statement input.
  public static let StatementMinimumSectionWidth = LayoutConfig.newPropertyKey()

  /// [`Unit`] The minimum width of the top section of the C-shaped statement input (not
  /// including the statement's notch width).
  public static let StatementMinimumConnectorWidth = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The default stroke color to use when rendering a block
  public static let BlockStrokeDefaultColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The stroke color to use when rendering a highlighted block
  public static let BlockStrokeHighlightColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The stroke color to use when rendering a disabled block
  public static let BlockStrokeDisabledColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The stroke color to use when rendering a highlighted connection on a block.
  public static let BlockConnectionHighlightStrokeColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The fill color to use when rendering a disabled block
  public static let BlockFillDisabledColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The color to render above of a block when it is highlighted.
  public static let BlockMaskHighlightColor = LayoutConfig.newPropertyKey()

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

  /// [`String`] Default value for how blocks with no output or previous connection should be
  /// rendered with a "hat". This value should correspond to a value of type `Block.Style.HatType`
  /// (eg. `Block.Style.hatCap` or `Block.Style.hatNone`).
  public static let BlockHat = LayoutConfig.newPropertyKey()

  /// [`Size`] The size to use when rendering a "hat" of type `Block.Style.cap`.
  public static let BlockHatCapSize = LayoutConfig.newPropertyKey()

  /// [`Size`] Minimum size of the inline connector
  public static let InlineConnectorMinimumSize = LayoutConfig.newPropertyKey()

  /// [`Unit`] Horizontal padding around inline connector. For inline connector rendering, this
  /// value overrides the one specified by the key `LayoutConfig.InlineXPadding`.
  public static let InlineConnectorXPadding = LayoutConfig.newPropertyKey()

  /// [`Unit`] Vertical padding around inline connector. For inline connector rendering, this value
  /// overrides the one specified by the key `LayoutConfig.InlineYPadding`.
  public static let InlineConnectorYPadding = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The color to tint the mutator settings button.
  public static let MutatorSettingsButtonColor = LayoutConfig.newPropertyKey()

  // MARK: - Initializers

  /// Initializes the default layout config.
  public override init() {
    super.init()

    // Set default values for known properties
    setUnit(Unit(4), for: DefaultLayoutConfig.BlockCornerRadius)
    setUnit(Unit(1), for: DefaultLayoutConfig.BlockLineWidthRegular)
    setUnit(Unit(4), for: DefaultLayoutConfig.BlockLineWidthHighlight)
    setUnit(Unit(4), for: DefaultLayoutConfig.BlockConnectionLineWidthHighlight)
    setUnit(Unit(12), for: DefaultLayoutConfig.PuzzleTabHeight)
    setUnit(Unit(8), for: DefaultLayoutConfig.PuzzleTabWidth)
    setUnit(Unit(16), for: DefaultLayoutConfig.NotchXOffset)
    setUnit(Unit(15), for: DefaultLayoutConfig.NotchWidth)
    setUnit(Unit(4), for: DefaultLayoutConfig.NotchHeight)
    setUnit(Unit(12), for: DefaultLayoutConfig.StatementSectionHeight)
    setUnit(Unit(8), for: DefaultLayoutConfig.StatementMinimumSectionWidth)
    setUnit(Unit(12), for: DefaultLayoutConfig.StatementMinimumConnectorWidth)
    setSize(Size(width: 14, height: 28), for: DefaultLayoutConfig.InlineConnectorMinimumSize)
    setUnit(Unit(8), for: DefaultLayoutConfig.InlineConnectorXPadding)
    setUnit(Unit(3), for: DefaultLayoutConfig.InlineConnectorYPadding)

    setColor(ColorPalette.grey.tint400, for: DefaultLayoutConfig.BlockStrokeDefaultColor)
    setColor(ColorPalette.yellow.tint700.withAlphaComponent(0.95),
             for: DefaultLayoutConfig.BlockStrokeHighlightColor)
    setColor(ColorPalette.grey.tint200.withAlphaComponent(0.25),
             for: DefaultLayoutConfig.BlockMaskHighlightColor)
    setColor(ColorPalette.indigo.accent700,
             for: DefaultLayoutConfig.BlockConnectionHighlightStrokeColor)
    setColor(ColorPalette.grey.tint700, for: DefaultLayoutConfig.BlockStrokeDisabledColor)
    setColor(ColorPalette.grey.tint400, for: DefaultLayoutConfig.BlockFillDisabledColor)
    setFloat(0.7, for: DefaultLayoutConfig.BlockDraggingFillColorAlpha)
    setFloat(0.8, for: DefaultLayoutConfig.BlockDraggingStrokeColorAlpha)
    setFloat(1.0, for: DefaultLayoutConfig.BlockDefaultAlpha)
    setFloat(0.5, for: DefaultLayoutConfig.BlockDisabledAlpha)
    setFloat(0.4, for: DefaultLayoutConfig.BlockShadowSaturationMultiplier)
    setFloat(1.2, for: DefaultLayoutConfig.BlockShadowBrightnessMultiplier)

    setString(Block.Style.hatNone, for: DefaultLayoutConfig.BlockHat)
    setSize(Size(width: 100, height: 16), for: DefaultLayoutConfig.BlockHatCapSize)

    setColor(ColorPalette.grey.tint100, for: DefaultLayoutConfig.MutatorSettingsButtonColor)
  }
}
