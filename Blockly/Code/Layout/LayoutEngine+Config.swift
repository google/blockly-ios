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

extension LayoutEngine {
  /**
   UI configuration for all layout elements underneath a `LayoutEngine`.
   */
  @objc(BKYLayoutEngineConfig)
  public class Config: NSObject {
    // MARK: - Structs

    /**
     Struct for representing a float value in both the Workspace coordinate system and UIView
     coordinate system.
     */
    public struct Float {
      /// The `LayoutEngine.Config` that owns this value (a strong reference here is used for
      /// performance reasons)
      public let config: Config
      /// The float value specified in the Workspace coordinate system
      public var workspaceUnit: CGFloat
      /// The float value specified in the UIView coordinate system
      public var viewUnit: CGFloat {
        return self.config.engine.viewUnitFromWorkspaceUnit(workspaceUnit)
      }
      public init(_ config: Config, _ workspaceUnit: CGFloat) {
        self.config = config
        self.workspaceUnit = workspaceUnit
      }
    }

    /**
     Struct for representing a Size value (i.e. width/height) in both the Workspace coordinate
     system and UIView coordinate system.
     */
    public struct Size {
      /// The `LayoutEngine.Config` that owns this value (a strong reference here is used for
      /// performance reasons)
      public let config: Config
      /// The size value specified in the Workspace coordinate system
      public var workspaceSize: WorkspaceSize
      /// The size value specified in the UIView coordinate system
      public var viewSize: CGSize {
        return self.config.engine.viewSizeFromWorkspaceSize(workspaceSize)
      }
      public init(_ config: Config, _ workspaceSize: WorkspaceSize) {
        self.config = config
        self.workspaceSize = workspaceSize
      }
    }

    // MARK: - Properties

    /// The `LayoutEngine` that owns this `LayoutConfig`.
    /// - Note: This value is automatically set by `LayoutEngine`'s initializer.
    public final weak var engine: LayoutEngine!

    /// Horizontal space between elements
    public final lazy var xSeparatorSpace: Config.Float = { return Float(self, 10) }()

    /// Vertical space between elements
    public final lazy var ySeparatorSpace: Config.Float = { return Float(self, 10) }()

    /// Horizontal padding around inline elements
    public final lazy var inlineXPadding: Config.Float = { return Float(self, 10) }()

    /// Vertical padding around inline elements
    public final lazy var inlineYPadding: Config.Float = { return Float(self, 5) }()

    /// Minimum height of a block
    public final lazy var minimumBlockHeight: Config.Float = { return Float(self, 25) }()

    /// Rounded corner radius of a block
    public final lazy var blockCornerRadius: Config.Float = { return Float(self, 8) }()

    /// Width of a regular line stroke for a block
    public final lazy var blockLineWidthRegular: Config.Float = { return Float(self, 1) }()

    /// Width of a highlighted line stroke for a block
    public final lazy var blockLineWidthHighlight: Config.Float = { return Float(self, 3) }()

    /// The default stroke colour to use when rendering a block
    public final var blockStrokeDefaultColour: UIColor = UIColor.darkGrayColor()

    /// The highlight stroke colour to use when rendering a block
    public final var blockStrokeHighlightColour: UIColor = UIColor.blueColor()

    /// Height of a horizontal puzzle tab
    public final lazy var puzzleTabHeight: Config.Float = { return Float(self, 20) }()

    /// Width of a horizontal puzzle tab
    public final lazy var puzzleTabWidth: Config.Float = { return Float(self, 8) }()

    /// Width of vertical tab (including left margin)
    public final lazy var notchWidth: Config.Float = { return Float(self, 30) }()

    /// Height of vertical tab
    public final lazy var notchHeight: Config.Float = { return Float(self, 4) }()

    /// Minimum height of field rows
    public final lazy var minimumFieldHeight: Config.Float = { return Float(self, 18) }()

    /// Height of jagged teeth at the end of collapsed blocks
    public final lazy var blockJaggedTeethHeight: Config.Float = { return Float(self, 20) }()

    /// Width of jagged teeth at the end of collapsed blocks
    public final lazy var blockJaggedTeethWidth: Config.Float = { return Float(self, 15) }()

    /// If necessary, the rounded corner radius of a field
    public final lazy var fieldCornerRadius: Config.Float = { return Float(self, 5) }()

    /// If necessary, the line stroke width of a field
    public final lazy var fieldLineWidth: Config.Float = { return Float(self, 1) }()

    /// The button size to use when rendering a colour field
    public final lazy var fieldColourButtonSize: Config.Size = {
      return Size(self, WorkspaceSizeMake(44, 44))
    }()

    /// The border width to use when rendering the colour button
    public final lazy var fieldColourButtonBorderWidth: Float = { return Float(self, 2) }()

    /// The colour to use for the `FieldCheckboxView` switch's "onTintColor". A value of nil means
    /// that the system default should be used.
    public final var fieldCheckboxSwitchOnTintColour: UIColor? = nil

    /// The colour to use for the `FieldCheckboxView` switch "tintColor". A value of nil means
    /// that the system default should be used.
    public final var fieldCheckboxSwitchTintColour: UIColor? = nil
  }
}
