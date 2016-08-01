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
 Core object that is required by `Layout` instances in order to provide:
 - Unit scaling between Blockly's Workspace coordinate system and the UIView coordinate system
 - UI configuration

 All `Layout` instances in a single `Layout` tree should share the same single instance of
 `LayoutEngine`. If any of the nodes in a single tree use different instances of `LayoutEngine`,
 unexpected results may occur.
 */
@objc(BKYLayoutEngine)
public class LayoutEngine: NSObject {

  // MARK: - Properties


  /// The minimum and maximum scale that the engine can have, relative to the Workspace coordinate
  /// system.
  public private(set) final var minimumScale: CGFloat = 0.5
  public private(set) final var maximumScale: CGFloat = 2.0

  /// The current scale of the UI, relative to the Workspace coordinate system.
  /// eg. scale = 2.0 means that a (10, 10) UIView point scales to a (5, 5) Workspace point.
  public final var scale: CGFloat = 1.0 {
    didSet {
      // Do not allow a scale less than 0.5
      if scale < self.minimumScale {
        scale = self.minimumScale
      }

      if scale > self.maximumScale {
        scale = self.maximumScale
      }

      if scale != oldValue {
        // Now that the scale has changed, update all the view values in the config,
        config.updateViewValuesFromEngine(self)
      }
    }
  }

  /// Flag determining if `Layout` instances associated with this layout engine should be rendered
  /// in right-to-left (`true`) or left-to-right (`false`)..
  public final var rtl: Bool

  /// The UI configuration to use for this layout engine
  public final var config: LayoutConfig

  // MARK: - Initializers

  /**
   Creates a `LayoutEngine` instance.

   - Parameter config: Optional parameter for setting `self.config`. If no value is specified,
   a `LayoutConfig` is created automatically.
   - Parameter rtl: Optional parameter for setting `self.rtl`. If no value is specified, `self.rtl`
   is automatically set using the system's layout direction.
   - Parameter minScale: The minimum scale for the engine, relative to Workspace coordinate system.
   Defaults to 0.5.
   - Parameter maxScale: The maximum scale for the engine, relative to Workspace coordinate system.
   Degaults to 2.0.
   */
  public init(config: LayoutConfig = LayoutConfig(), rtl: Bool? = nil, minScale: CGFloat = 0.5,
              maxScale: CGFloat = 2.0) {
    self.config = config
    self.rtl =
      rtl ?? (UIApplication.sharedApplication().userInterfaceLayoutDirection == .RightToLeft)
    super.init()

    config.updateViewValuesFromEngine(self)

    self.minimumScale = minScale
    self.maximumScale = maxScale
  }

  // MARK: - Public

  /**
  Using the current `scale` value, this method scales a point from the UIView coordinate system to
  the Workspace coordinate system.

  - Parameter point: A point from the UIView coordinate system.
  - Returns: A point in the Workspace coordinate system.
  - Note: This does not translate a UIView point directly into a Workspace point, it only scales the
  magnitude of a UIView point into the Workspace coordinate system. For example, in RTL, more
  calculation would need to be done to get the UIView point's translated Workspace point.
  */
  public final func scaledWorkspaceVectorFromViewVector(point: CGPoint) -> WorkspacePoint {
    if scale == 0 {
      return WorkspacePointZero
    } else if scale == 1 {
      return point
    } else {
      return WorkspacePointMake(
        workspaceUnitFromViewUnit(point.x),
        workspaceUnitFromViewUnit(point.y))
    }
  }

  /**
   Using the current `scale` value, this method scales a size from the UIView coordinate system
   to the Workspace coordinate system.

   - Parameter size: A size from the UIView coordinate system.
   - Returns: A size in the Workspace coordinate system.
   */
  public final func workspaceSizeFromViewSize(size: CGSize) -> WorkspaceSize {
    if scale == 0 {
      return WorkspaceSizeZero
    } else if scale == 1 {
      return size
    } else {
      return WorkspaceSizeMake(
        workspaceUnitFromViewUnit(size.width),
        workspaceUnitFromViewUnit(size.height))
    }
  }

  /**
   Using the current `scale` value, this method scales a unit value from the UIView coordinate
   system to the Workspace coordinate system.

   - Parameter unit: A unit value from the UIView coordinate system.
   - Returns: A unit value in the Workspace coordinate system.
   */
  public final func workspaceUnitFromViewUnit(unit: CGFloat) -> CGFloat {
    if scale == 0 {
      return 0
    } else if scale == 1 {
      return unit
    } else {
      return unit / scale
    }
  }

  /**
   Using the current `scale` value, this method scales a unit value from the Workspace coordinate
   system to the UIView coordinate system.

   - Parameter unit: A unit value from the Workspace coordinate system.
   - Returns: A unit value in the UIView coordinate system.
   */
  public final func viewUnitFromWorkspaceUnit(unit: CGFloat) -> CGFloat {
    if scale == 0 {
      return 0
    } else if scale == 1 {
      return unit
    } else {
      // Round unit values when going from workspace to view coordinates. This helps keep
      // things consistent when scaling points and sizes.
      return round(unit * scale)
    }
  }

  /**
   Using the current `scale` value, this method scales a left-to-right point from the Workspace
   coordinate system to the UIView coordinate system.

   - Parameter point: A point from the Workspace coordinate system.
   - Returns: A point in the UIView coordinate system.
   */
  public final func viewPointFromWorkspacePoint(point: WorkspacePoint) -> CGPoint {
    if scale == 0 {
      return CGPointZero
    } else if scale == 1 {
      return point
    } else {
      return CGPointMake(viewUnitFromWorkspaceUnit(point.x), viewUnitFromWorkspaceUnit(point.y))
    }
  }

  /**
   Using the current `scale` value, this method scales a (x, y) point from the Workspace coordinate
   system to the UIView coordinate system.

   - Parameter x: The x-coordinate of the point
   - Parameter y: The y-coordinate of the point
   - Returns: A point in the UIView coordinate system.
   */
  public final func viewPointFromWorkspacePoint(x: CGFloat, _ y: CGFloat) -> CGPoint {
    if scale == 0 {
      return CGPointZero
    } else if scale == 1 {
      return CGPointMake(x, y)
    } else {
      return CGPointMake(viewUnitFromWorkspaceUnit(x), viewUnitFromWorkspaceUnit(y))
    }
  }

  /**
   Using the current `scale` value, this method scales a size from the Workspace coordinate
   system to the UIView coordinate system.

   - Parameter size: A size from the Workspace coordinate system.
   - Returns: A size in the UIView coordinate system.
   */
  public final func viewSizeFromWorkspaceSize(size: WorkspaceSize) -> CGSize {
    if scale == 0 {
      return CGSizeZero
    } else if scale == 1 {
      return size
    } else {
      return CGSizeMake(
        viewUnitFromWorkspaceUnit(size.width),
        viewUnitFromWorkspaceUnit(size.height))
    }
  }
}
