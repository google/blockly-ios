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

  /// [`UIColor`] The default stroke colour to use when rendering a block
  public static let BlockStrokeDefaultColor = LayoutConfig.newPropertyKey()

  /// [`UIColor`] The highlight stroke colour to use when rendering a block
  public static let BlockStrokeHighlightColor = LayoutConfig.newPropertyKey()

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
  }
}
