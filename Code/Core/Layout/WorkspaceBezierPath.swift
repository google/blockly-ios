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
Object for constructing a bezier path from a Workspace coordinate system and translating that path
into the UIView coordinate system.

Under the hood, this class uses a `UIBezierPath` object, but it has added the following:
- enables the ability to add segments by relative location, based on the current point
- adds SVG-equivalent methods for "smooth curveto" and "smooth quadratic curveto"
*/
@objc(BKYWorkspaceBezierPath)
public class WorkspaceBezierPath: NSObject {
  // MARK: - Properties

  /// The translated bezier path in the UIView coordinate system.
  public let viewBezierPath: UIBezierPath
  /// The current point of the bezier path, specified in the Workspace coordinate system.
  public private(set) var currentWorkspacePoint: WorkspacePoint = WorkspacePointZero
  /// The workspace layout used to calculate scaling between a Workspace and the UIView
  private let _layout: WorkspaceLayout
  /**
  This value is used to support SVG-equivalent methods for "smooth curveto" and
  "smooth quadratic curveto", and is specified in the UIView coordinate system.

  If the last method called on this object was to add a cubic or quadratic curve to the path,
  this value stores the reflection of the end control point used by those methods.

  If the last method did not add a cubic or quadratic curve to the path, this value is nil.
  */
  private var _reflectionOfLastCurveControlPoint: CGPoint?

  // MARK: - Initializers

  /**
  Designated initializer.

  - Parameter layout: The workspace layout used to calculate scaling between a Workspace and the
  UIView
  */
  public required init(layout: WorkspaceLayout) {
    self._layout = layout
    self.viewBezierPath = UIBezierPath()
  }

  // MARK: - Public

  /**
  Appends a straight line to the receiver’s path.

  - Parameter point: The destination point of the line segment, specified in the Workspace
  coordinate system.
  - Parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  public func addLineToPoint(point: WorkspacePoint, relative: Bool) {
//    bky_print("[current point=\(self.currentWorkspacePoint)], [point=\(point)], " +
//      "[relative=\(relative)], ")
    viewBezierPath.addLineToPoint(viewPointFromWorkspacePoint(point, relative: relative))

    setCurrentWorkspacePoint(point, relative: relative)
    _reflectionOfLastCurveControlPoint = nil
  }

  /**
  Appends a straight line to the receiver’s path.

  - Parameter x: The destination x-point of the line segment, specified in the Workspace
  coordinate system.
  - Parameter y: The destination y-point of the line segment, specified in the Workspace
  coordinate system.
  - Parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  public func addLineToPoint(x: CGFloat, _ y: CGFloat, relative: Bool) {
    addLineToPoint(WorkspacePointMake(x, y), relative: relative)
  }

  /**
  Appends an arc to the receiver’s path.

  - Parameter center: Specifies the center point of the circle (in the Workspace coordinate system)
  used to define the arc.
  - Parameter radius: Specifies the radius of the circle used to define the arc.
  - Parameter startAngle: Specifies the starting angle of the arc (measured in radians).
  - Parameter endAngle: Specifies the end angle of the arc (measured in radians).
  - Parameter clockwise: The direction in which to draw the arc.
  - Parameter relative: True if the specified center point should be relative to the `currentPoint`.
  False if it should be an absolute point.
  */
  public func addArcWithCenter(center: WorkspacePoint, radius: CGFloat, startAngle: CGFloat,
    endAngle: CGFloat, clockwise: Bool, relative: Bool) {
      viewBezierPath.addArcWithCenter(
        viewPointFromWorkspacePoint(center, relative: relative),
        radius: radius * _layout.scale,
        startAngle: startAngle,
        endAngle: endAngle,
        clockwise: clockwise)

      setCurrentWorkspacePoint(
        _layout.scaledWorkspaceVectorFromViewVector(viewBezierPath.currentPoint),
        relative: relative)
      _reflectionOfLastCurveControlPoint = nil
  }

  /**
  Appends a cubic Bézier curve to the receiver’s path.

  - Parameter endPoint: The end point of the curve, specified in the Workspace coordinate system.
  - Parameter controlPoint1: The first control point to use when computing the curve, specified in
  the Workspace coordinate system.
  - Parameter controlPoint2: The second control point to use when computing the curve, specified in
  the Workspace coordinate system.
  - Parameter relative: True if all specified points should be relative to the `currentPoint`. False
  if they should be are absolute points.
  */
  public func addCurveToPoint(endPoint: WorkspacePoint, controlPoint1: WorkspacePoint,
    controlPoint2: WorkspacePoint, relative: Bool) {
      let viewEndPoint = viewPointFromWorkspacePoint(endPoint, relative: relative)
      let viewControlPoint1 = viewPointFromWorkspacePoint(controlPoint1, relative: relative)
      let viewControlPoint2 = viewPointFromWorkspacePoint(controlPoint2, relative: relative)
      viewBezierPath.addCurveToPoint(
        viewEndPoint, controlPoint1: viewControlPoint1, controlPoint2: viewControlPoint2)

      setCurrentWorkspacePoint(endPoint, relative: relative)
      _reflectionOfLastCurveControlPoint =
        viewBezierPath.currentPoint + viewEndPoint - viewControlPoint2
  }

  /**
  Appends a quadratic Bézier curve to the receiver’s path.

  - Parameter endPoint: The end point of the curve, specified in the Workspace coordinate system.
  - Parameter controlPoint: The control point of the curve, specified in the Workspace coordinate
  system.
  - Parameter relative: True if the specified points should be relative to the `currentPoint`.
  False if they should be absolute points.
  */
  public func addQuadCurveToPoint(
    endPoint: WorkspacePoint, controlPoint: WorkspacePoint, relative: Bool) {
      let viewEndPoint = viewPointFromWorkspacePoint(endPoint, relative: relative)
      let viewControlPoint = viewPointFromWorkspacePoint(controlPoint, relative: relative)
      viewBezierPath.addQuadCurveToPoint(viewEndPoint, controlPoint:viewControlPoint)

      setCurrentWorkspacePoint(endPoint, relative: relative)
      _reflectionOfLastCurveControlPoint =
        viewBezierPath.currentPoint + viewEndPoint - viewControlPoint
  }

  /**
  Appends a cubic Bézier curve to the receiver’s path. Similar to SVG's "smooth curveto" method, if
  the previous method call appended a cubic or quadratic Bézier curve, this method will create a
  smooth transition between both curves.

  Note: This method should only be called directly after appending a cubic or quadratic Bézier
  curve. Otherwise, `addCurveToPoint(...)` is a more suitable method to use.

  - Parameter endPoint: The end point of the curve, specified in the Workspace coordinate system.
  - Parameter controlPoint2: The second control point to use when computing the curve, specified in
  the Workspace coordinate system (the first control point is determined automatically).
  - Parameter relative: True if all specified points should be relative to the `currentPoint`. False
  if they should be absolute points.
  */
  public func addSmoothCurveToPoint(
    endPoint: WorkspacePoint, controlPoint2: WorkspacePoint, relative: Bool) {
      let viewEndPoint = viewPointFromWorkspacePoint(endPoint, relative: relative)
      let viewControlPoint1 = _reflectionOfLastCurveControlPoint ?? viewBezierPath.currentPoint
      let viewControlPoint2 = viewPointFromWorkspacePoint(controlPoint2, relative: relative)
      viewBezierPath.addCurveToPoint(
        viewEndPoint, controlPoint1: viewControlPoint1, controlPoint2: viewControlPoint2)

      setCurrentWorkspacePoint(endPoint, relative: relative)
      _reflectionOfLastCurveControlPoint =
        viewBezierPath.currentPoint + viewEndPoint - viewControlPoint2
  }

  /**
  Appends a quadratic Bézier curve to the receiver’s path. Similar to SVG's "smooth quadratic
  curveto" method, if the previous method call appended a cubic or quadratic Bézier curve, this
  method will create a smooth transition between both curves.

  Note: This method should only be called directly after appending a cubic or quadratic Bézier
  curve. Otherwise, `addQuadCurveToPoint(...)` is a more suitable method to use.

  - Parameter endPoint: The end point of the curve, specified in the Workspace coordinate system.
  - Parameter controlPoint: The control point of the curve, specified in the Workspace coordinate
  system.
  - Parameter relative: True if all specified points should be relative to the `currentPoint`. False
  if they should be absolute points.
  */
  public func addSmoothQuadCurveToPoint(endPoint: WorkspacePoint, relative: Bool) {
    let viewEndPoint = viewPointFromWorkspacePoint(endPoint, relative: relative)
    let viewControlPoint = _reflectionOfLastCurveControlPoint ?? viewBezierPath.currentPoint
    viewBezierPath.addQuadCurveToPoint(viewEndPoint, controlPoint:viewControlPoint)

    setCurrentWorkspacePoint(endPoint, relative: relative)
    _reflectionOfLastCurveControlPoint =
      viewBezierPath.currentPoint + viewEndPoint - viewControlPoint
  }

  /**
  Appends the contents of the specified path object to the receiver’s path.

  - Parameter bezierPath: The path to add to the receiver.
  */
  public func appendPath(bezierPath: WorkspaceBezierPath) {
    viewBezierPath.appendPath(bezierPath.viewBezierPath)

    self.currentWorkspacePoint = bezierPath.currentWorkspacePoint
    _reflectionOfLastCurveControlPoint = nil
  }

  /**
  Closes the most recently added subpath.
  */
  public func closePath() {
    viewBezierPath.closePath()

    self.currentWorkspacePoint =
      _layout.scaledWorkspaceVectorFromViewVector(viewBezierPath.currentPoint)
    _reflectionOfLastCurveControlPoint = nil
  }

  /**
  Moves the receiver’s current point to the specified location.

  - Parameter point: A point in the Workspace coordinate system.
  - Parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  public func moveToPoint(point: WorkspacePoint, relative: Bool) {
    viewBezierPath.moveToPoint(viewPointFromWorkspacePoint(point, relative: relative))

    self.currentWorkspacePoint = point
    _reflectionOfLastCurveControlPoint = nil
  }

  /**
  Moves the receiver’s current point to the specified location.

  - Parameter x: The destination x-point of the line segment, specified in the Workspace
  coordinate system.
  - Parameter y: The destination y-point of the line segment, specified in the Workspace
  coordinate system.
  - Parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  public func moveToPoint(x: CGFloat, _ y: CGFloat, relative: Bool) {
    moveToPoint(WorkspacePointMake(x, y), relative: relative)
  }

  /**
  Removes all points from the receiver, effectively deleting all subpaths.
  */
  public func removeAllPoints() {
    viewBezierPath.removeAllPoints()

    self.currentWorkspacePoint = CGPointZero
    _reflectionOfLastCurveControlPoint = nil
  }

  // MARK: - Private

  /**
  Converts a Workspace point to a UIView point, using the current workspace layout.

  - Parameter point: A point specified in the Workspace coordinate system.
  - Parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  private func viewPointFromWorkspacePoint(point: WorkspacePoint, relative: Bool) -> CGPoint {
    let viewPoint = _layout.viewPointFromWorkspacePoint(point)
    return relative && !viewBezierPath.empty ?
      (viewBezierPath.currentPoint + viewPoint) : viewPoint
  }

  /**
  Sets the current workspace point from the given point.

  - Parameter point: A point specified in the Workspace coordinate system.
  - Parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  private func setCurrentWorkspacePoint(point: WorkspacePoint, relative: Bool) {
    self.currentWorkspacePoint = relative ? currentWorkspacePoint + point : point
  }
}
