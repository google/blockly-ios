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

  /// Minimum height of a block
  public static let MinimumBlockHeight = LayoutConfig.newPropertyKey()

  /// Rounded corner radius of a block
  public static let BlockCornerRadius = LayoutConfig.newPropertyKey()

  /// Width of a regular line stroke for a block
  public static let BlockLineWidthRegular = LayoutConfig.newPropertyKey()

  /// Width of a highlighted line stroke for a block
  public static let BlockLineWidthHighlight = LayoutConfig.newPropertyKey()

  /// Height of a horizontal puzzle tab
  public static let PuzzleTabHeight = LayoutConfig.newPropertyKey()

  /// Width of a horizontal puzzle tab
  public static let PuzzleTabWidth = LayoutConfig.newPropertyKey()

  /// Width of vertical tab (including left margin)
  public static let NotchWidth = LayoutConfig.newPropertyKey()

  /// Height of vertical tab
  public static let NotchHeight = LayoutConfig.newPropertyKey()

  /// Height of jagged teeth at the end of collapsed blocks
  public static let BlockJaggedTeethHeight = LayoutConfig.newPropertyKey()

  /// Width of jagged teeth at the end of collapsed blocks
  public static let BlockJaggedTeethWidth = LayoutConfig.newPropertyKey()

  /// The default stroke colour to use when rendering a block
  public static let BlockStrokeDefaultColor = LayoutConfig.newPropertyKey()

  /// The highlight stroke colour to use when rendering a block
  public static let BlockStrokeHighlightColor = LayoutConfig.newPropertyKey()

  // MARK: - Initializers

  public override init() {
    super.init()

    // Set default values for known properties
    setUnit(Unit(25), forKey: DefaultLayoutConfig.MinimumBlockHeight)
    setUnit(Unit(8), forKey: DefaultLayoutConfig.BlockCornerRadius)
    setUnit(Unit(1), forKey: DefaultLayoutConfig.BlockLineWidthRegular)
    setUnit(Unit(3), forKey: DefaultLayoutConfig.BlockLineWidthHighlight)
    setUnit(Unit(20), forKey: DefaultLayoutConfig.PuzzleTabHeight)
    setUnit(Unit(8), forKey: DefaultLayoutConfig.PuzzleTabWidth)
    setUnit(Unit(30), forKey: DefaultLayoutConfig.NotchWidth)
    setUnit(Unit(4), forKey: DefaultLayoutConfig.NotchHeight)
    setUnit(Unit(20), forKey: DefaultLayoutConfig.BlockJaggedTeethHeight)
    setUnit(Unit(15), forKey: DefaultLayoutConfig.BlockJaggedTeethWidth)

    setColor(UIColor.darkGrayColor(), forKey: DefaultLayoutConfig.BlockStrokeDefaultColor)
    setColor(UIColor.blueColor(), forKey: DefaultLayoutConfig.BlockStrokeHighlightColor)
  }
}
