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
    public var xSeparatorSpace: CGFloat = 10

    /// Vertical space between elements, specified as a Workspace coordinate system unit.
    public var ySeparatorSpace: CGFloat = 10

    /// Vertical padding around inline elements, specified as a Workspace coordinate system unit.
    public var inlineYPadding: CGFloat = 5

    /// Minimum height of a block, specified as a Workspace coordinate system unit.
    public var minimumBlockHeight: CGFloat = 25

    /// Rounded corner radius of a block, specified as a Workspace coordinate system unit.
    public var blockCornerRadius: CGFloat = 8

    /// Width of a regular line stroke for a block, specified as a Workspace coordinate system unit
    public var blockLineWidthRegular: CGFloat = 1

    /// Width of a highlighted line stroke for a block, specified as a Workspace coordinate system
    /// unit
    public var blockLineWidthHighlight: CGFloat = 3

    // WARNING:(vicng) This value or puzzleTabHeight in WebBlockly is set to 20
    /// Height of a horizontal puzzle tab, specified as a Workspace coordinate system unit.
    public var puzzleTabHeight: CGFloat = 20

    /// Width of a horizontal puzzle tab, specified as a Workspace coordinate system unit.
    public var puzzleTabWidth: CGFloat = 8

    /// Width of vertical tab (including left margin), specified as a Workspace coordinate system
    /// unit.
    public var notchWidth: CGFloat = 30;

    /// Height of vertical tab, specified as a Workspace coordinate system unit.
    public var notchHeight: CGFloat = 4;

    /// Minimum height of field rows, specified as a Workspace coordinate system unit.
    public var minimumFieldHeight: CGFloat = 18

    /// Height of jagged teeth at the end of collapsed blocks, specified as a Workspace coordinate
    /// system unit.
    public var jaggedTeethHeight: CGFloat = 20

    /// Width of jagged teeth at the end of collapsed blocks, specified as a Workspace coordinate
    /// system unit.
    public var jaggedTeethWidth: CGFloat = 15
  }
}
