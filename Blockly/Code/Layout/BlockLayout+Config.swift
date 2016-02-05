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
UI configuration for elements within a block, based within the Workspace coordinate system.
*/
extension BlockLayout {
  @objc(BKYBlockLayoutConfig)
  public class Config: NSObject {
    /// Horizontal space between elements, specified as a Workspace coordinate system unit.
    public final var xSeparatorSpace: CGFloat = 10

    /// Vertical space between elements, specified as a Workspace coordinate system unit.
    public final var ySeparatorSpace: CGFloat = 10

    /// Horizontal padding around inline elements, specified as a Workspace coordinate system unit.
    public final var inlineXPadding: CGFloat = 10

    /// Vertical padding around inline elements, specified as a Workspace coordinate system unit.
    public final var inlineYPadding: CGFloat = 5

    /// Minimum height of a block, specified as a Workspace coordinate system unit.
    public final var minimumBlockHeight: CGFloat = 25

    /// Rounded corner radius of a block, specified as a Workspace coordinate system unit.
    public final var blockCornerRadius: CGFloat = 8

    /// Width of a regular line stroke for a block, specified as a Workspace coordinate system unit
    public final var blockLineWidthRegular: CGFloat = 1

    /// Width of a highlighted line stroke for a block, specified as a Workspace coordinate system
    /// unit
    public final var blockLineWidthHighlight: CGFloat = 3

    // WARNING:(vicng) This value or puzzleTabHeight in WebBlockly is set to 20
    /// Height of a horizontal puzzle tab, specified as a Workspace coordinate system unit.
    public final var puzzleTabHeight: CGFloat = 20

    /// Width of a horizontal puzzle tab, specified as a Workspace coordinate system unit.
    public final var puzzleTabWidth: CGFloat = 8

    /// Width of vertical tab (including left margin), specified as a Workspace coordinate system
    /// unit.
    public final var notchWidth: CGFloat = 30;

    /// Height of vertical tab, specified as a Workspace coordinate system unit.
    public final var notchHeight: CGFloat = 4;

    /// Minimum height of field rows, specified as a Workspace coordinate system unit.
    public final var minimumFieldHeight: CGFloat = 18

    /// Height of jagged teeth at the end of collapsed blocks, specified as a Workspace coordinate
    /// system unit.
    public final var jaggedTeethHeight: CGFloat = 20

    /// Width of jagged teeth at the end of collapsed blocks, specified as a Workspace coordinate
    /// system unit.
    public final var jaggedTeethWidth: CGFloat = 15

    /// If necessary, the rounded corner radius of a field, specified as a Workspace coordinate
    /// system unit.
    public final var fieldCornerRadius: CGFloat = 5

    /// If necessary, the line stroke width of a field, specified as a Workspace coordinate system
    /// unit.
    public final var fieldLineWidth: CGFloat = 1

    /// The button size to use when rendering a colour field, expressed as a Workspace coordinate
    /// system unit.
    public final var colourButtonSize = WorkspaceSizeMake(44, 44)

    /// The border width to use when rendering the colour button, expressed as a Workspace
    /// coordinate system unit.
    public final var colourButtonBorderWidth = CGFloat(2)

    /// The colour to use for the `FieldCheckboxView` switch's "onTintColor". A value of nil means
    /// that the system default should be used.
    public final var checkboxSwitchOnTintColour: UIColor? = nil

    /// The colour to use for the `FieldCheckboxView` switch "tintColor". A value of nil means
    /// that the system default should be used.
    public final var checkboxSwitchTintColour: UIColor? = nil

    /// The default stroke colour to use when rendering a block
    public final var blockStrokeDefaultColour: UIColor = UIColor.darkGrayColor()

    /// The highlight stroke colour to use when rendering a block
    public final var blockStrokeHighlightColour: UIColor = UIColor.blueColor()
  }
}
