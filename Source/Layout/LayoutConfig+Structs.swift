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

// MARK: - LayoutConfig.Unit

extension LayoutConfig {
  /**
   Struct for representing a unit value in both the Workspace coordinate system and UIView
   coordinate system.
   */
  public typealias Unit = BKYLayoutConfigUnit
}

extension LayoutConfig.Unit {
  /**
   Creates a unit for use inside a `LayoutConfig`.

   - parameter workspaceUnit: The value to use for `self.workspaceUnit`.
   - note: `self.viewUnit` is automatically initialized to the correct value based on the given
   `workspaceUnit`.
   */
  public init(_ workspaceUnit: CGFloat) {
    self.workspaceUnit = workspaceUnit
    // Always set viewUnit to workspaceUnit initially. It will get scaled to the correct value
    // eventually by its owning `LayoutConfig`.
    self.viewUnit = workspaceUnit
  }
}

// MARK: - LayoutConfig.Size

extension LayoutConfig {
  /**
   Struct for representing a Size value (i.e. width/height) in both the Workspace coordinate
   system and UIView coordinate system.
   */
  public typealias Size = BKYLayoutConfigSize
}

extension LayoutConfig.Size {
  /**
   Creates a size for use inside a `LayoutConfig`.

   - parameter workspaceWidth: The width value to use for `self.workspaceSize`.
   - parameter workspaceHeight: The height value to use for `self.workspaceSize`.
   - note: `self.viewSize` is automatically initialized to the correct value based on the generated
   `workspaceSize`.
   */
  public init(_ workspaceWidth: CGFloat, _ workspaceHeight: CGFloat) {
    self.workspaceSize = WorkspaceSize(width: workspaceWidth, height: workspaceHeight)
    // Always set viewSize to workspaceSize initially. It will get scaled to the correct value
    // eventually by its owning `LayoutConfig`.
    self.viewSize = CGSize(width: workspaceSize.width, height: workspaceSize.height)
  }
}
