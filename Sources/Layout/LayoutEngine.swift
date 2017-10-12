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
@objcMembers open class LayoutEngine: NSObject {

  // MARK: - Properties

  /// The minimum scale that the engine can have, relative to the Workspace coordinate system.
  public fileprivate(set) final var minimumScale: CGFloat = 0.5

  /// The maximum scale that the engine can have, relative to the Workspace coordinate system.
  public fileprivate(set) final var maximumScale: CGFloat = 2.0

  /// The current scale of the UI, relative to the Workspace coordinate system.
  /// eg. scale = 2.0 means that a (10, 10) UIView point scales to a (5, 5) Workspace point.
  public final var scale: CGFloat = 1.0 {
    didSet {
      // Do not allow a scale less than minimumScale, or greater than maximumScale
      if scale < self.minimumScale {
        scale = self.minimumScale
      }

      if scale > self.maximumScale {
        scale = self.maximumScale
      }

      if scale != oldValue {
        // Now that the scale has changed, update all the view values in the config,
        config.updateViewValues(fromEngine: self)
      }
    }
  }

  /// The scale that should be used inside popovers
  public final var popoverScale: CGFloat {
    // Use the same scale as `self.scale`, but don't scale less than 1.0
    return max(scale, 1.0)
  }

  /// Flag determining if `Layout` instances associated with this layout engine should be rendered
  /// in right-to-left (`true`) or left-to-right (`false`)..
  public final var rtl: Bool

  /// The UI configuration to use for this layout engine
  public final var config: LayoutConfig

  // MARK: - Initializers

  /**
   Creates a `LayoutEngine` instance.

   - parameter config: Optional parameter for setting `self.config`. If no value is specified,
   a `LayoutConfig` is created automatically.
   - parameter rtl: Optional parameter for setting `self.rtl`. If no value is specified, `self.rtl`
   is automatically set using the system's layout direction.
   - parameter minScale: The minimum scale for the engine, relative to Workspace coordinate system.
   Defaults to 0.5.
   - parameter maxScale: The maximum scale for the engine, relative to Workspace coordinate system.
   Degaults to 2.0.
   */
  public init(
    config: LayoutConfig = LayoutConfig(), rtl: Bool? = nil, minimumScale: CGFloat = 0.5,
    maximumScale: CGFloat = 2.0) {
    self.config = config
    self.rtl =
      rtl ?? (UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft)
    super.init()

    config.updateViewValues(fromEngine: self)

    self.minimumScale = minimumScale
    self.maximumScale = maximumScale
  }

  // MARK: - Public

  /**
  Using the current `scale` value, this method scales a point from the UIView coordinate system to
  the Workspace coordinate system.

  - parameter point: A point from the UIView coordinate system.
  - returns: A point in the Workspace coordinate system.
  - note: This does not translate a UIView point directly into a Workspace point, it only scales the
  magnitude of a UIView point into the Workspace coordinate system. For example, in RTL, more
  calculation would need to be done to get the UIView point's translated Workspace point.
  */
  @inline(__always)
  public final func scaledWorkspaceVectorFromViewVector(_ point: CGPoint) -> WorkspacePoint {
    if scale == 0 {
      return WorkspacePoint.zero
    } else {
      return WorkspacePoint(
        x: workspaceUnitFromViewUnit(point.x),
        y: workspaceUnitFromViewUnit(point.y))
    }
  }

  /**
   Using the current `scale` value, this method scales a size from the UIView coordinate system
   to the Workspace coordinate system.

   - parameter size: A size from the UIView coordinate system.
   - returns: A size in the Workspace coordinate system.
   */
  @inline(__always)
  public final func workspaceSizeFromViewSize(_ size: CGSize) -> WorkspaceSize {
    if scale == 0 {
      return WorkspaceSize.zero
    } else {
      return WorkspaceSize(width: workspaceUnitFromViewUnit(size.width),
                           height: workspaceUnitFromViewUnit(size.height))
    }
  }

  /**
   Using the current `scale` value, this method scales a unit value from the UIView coordinate
   system to the Workspace coordinate system.

   - parameter unit: A unit value from the UIView coordinate system.
   - returns: A unit value in the Workspace coordinate system.
   */
  @inline(__always)
  public final func workspaceUnitFromViewUnit(_ unit: CGFloat) -> CGFloat {
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

   - parameter unit: A unit value from the Workspace coordinate system.
   - returns: A unit value in the UIView coordinate system.
   */
  @inline(__always)
  public final func viewUnitFromWorkspaceUnit(_ unit: CGFloat) -> CGFloat {
    if scale == 0 {
      return 0
    } else if scale == 1 {
      return unit
    } else {
      return unit * scale
    }
  }

  /**
   Using the current `scale` value, this method scales a left-to-right point from the Workspace
   coordinate system to the UIView coordinate system.

   - parameter point: A point from the Workspace coordinate system.
   - returns: A point in the UIView coordinate system.
   */
  @inline(__always)
  public final func viewPointFromWorkspacePoint(_ point: WorkspacePoint) -> CGPoint {
    if scale == 0 {
      return CGPoint.zero
    } else {
      return CGPoint(x: viewUnitFromWorkspaceUnit(point.x), y: viewUnitFromWorkspaceUnit(point.y))
    }
  }

  /**
   Using the current `scale` value, this method scales a (x, y) point from the Workspace coordinate
   system to the UIView coordinate system.

   - parameter x: The x-coordinate of the point
   - parameter y: The y-coordinate of the point
   - returns: A point in the UIView coordinate system.
   */
  @inline(__always)
  public final func viewPointFromWorkspacePoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    if scale == 0 {
      return CGPoint.zero
    } else {
      return CGPoint(x: viewUnitFromWorkspaceUnit(x), y: viewUnitFromWorkspaceUnit(y))
    }
  }

  /**
   Using the current `scale` value, this method scales a size from the Workspace coordinate
   system to the UIView coordinate system.

   - parameter size: A size from the Workspace coordinate system.
   - returns: A size in the UIView coordinate system.
   */
  @inline(__always)
  public final func viewSizeFromWorkspaceSize(_ size: WorkspaceSize) -> CGSize {
    if scale == 0 {
      return CGSize.zero
    } else {
      return CGSize(width: viewUnitFromWorkspaceUnit(size.width),
                    height: viewUnitFromWorkspaceUnit(size.height))
    }
  }
}
