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

// MARK: - WorkspacePoint

/**
 Point in the Workspace coordinate system (which is separate from the UIView coordinate system).
 */
public typealias WorkspacePoint = BKYWorkspacePoint

extension WorkspacePoint {
  public static var zero: WorkspacePoint { return WorkspacePoint(x: 0, y: 0) }
}

extension WorkspacePoint: Equatable {
  public static func == (point1: WorkspacePoint, point2: WorkspacePoint) -> Bool {
    return point1.x == point2.x && point1.y == point2.y
  }
}

/**
 Returns the sum of two points.
 */
public func + (point1: WorkspacePoint, point2: WorkspacePoint) -> WorkspacePoint {
  return WorkspacePoint(x: point1.x + point2.x, y: point1.y + point2.y)
}

/**
 Returns the difference of one point from another point.
 */
public func - (point1: WorkspacePoint, point2: WorkspacePoint) -> WorkspacePoint {
  return WorkspacePoint(x: point1.x - point2.x, y: point1.y - point2.y)
}

// MARK: - WorkspaceSize

/**
 Size in the Workspace coordinate system (which is separate from the UIView coordinate system).
 */
public typealias WorkspaceSize = BKYWorkspaceSize

extension WorkspaceSize {
  public static var zero: WorkspaceSize { return WorkspaceSize(width: 0, height: 0) }
}

extension WorkspaceSize: Equatable {
  public static func == (size1: WorkspaceSize, size2: WorkspaceSize) -> Bool {
    return size1.width == size2.width && size1.height == size2.height
  }
}

// MARK: - WorkspaceEdgeInsets

/**
 Edge insets in the Workspace coordinate system (which is separate from the UIView coordinate
 system).
 */
public typealias WorkspaceEdgeInsets = BKYWorkspaceEdgeInsets
