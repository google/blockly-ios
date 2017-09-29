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
@objcMembers public final class WorkspaceBezierPath: NSObject {
  // MARK: - Properties

  /// The translated bezier path in the UIView coordinate system.
  public let viewBezierPath: UIBezierPath
  /// The current point of the bezier path, specified in the Workspace coordinate system.
  public private(set) var currentWorkspacePoint: WorkspacePoint = WorkspacePoint.zero
  /// The `LayoutEngine` used to calculate scaling between a Workspace and the UIView
  private let _layoutEngine: LayoutEngine
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

  - parameter engine: The `LayoutEngine` used to calculate scaling between a Workspace and the
  UIView
  */
  public required init(engine: LayoutEngine) {
    self._layoutEngine = engine
    self.viewBezierPath = UIBezierPath()
  }

  // MARK: - Public

  /**
  Appends a straight line to the receiver’s path.

  - parameter point: The destination point of the line segment, specified in the Workspace
  coordinate system.
  - parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  public func addLine(to point: WorkspacePoint, relative: Bool) {
    viewBezierPath.addLine(to: viewPointFromWorkspacePoint(point, relative: relative))

    setCurrentWorkspacePoint(point, relative: relative)
    _reflectionOfLastCurveControlPoint = nil
  }

  /**
  Appends a straight line to the receiver’s path.

  - parameter x: The destination x-point of the line segment, specified in the Workspace
  coordinate system.
  - parameter y: The destination y-point of the line segment, specified in the Workspace
  coordinate system.
  - parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  public func addLineTo(x: CGFloat, y: CGFloat, relative: Bool) {
    addLine(to: WorkspacePoint(x: x, y: y), relative: relative)
  }

  /**
  Appends an arc to the receiver’s path.

  - parameter center: Specifies the center point of the circle (in the Workspace coordinate system)
  used to define the arc.
  - parameter radius: Specifies the radius of the circle used to define the arc.
  - parameter startAngle: Specifies the starting angle of the arc (measured in radians).
  - parameter endAngle: Specifies the end angle of the arc (measured in radians).
  - parameter clockwise: The direction in which to draw the arc.
  - parameter relative: True if the specified center point should be relative to the `currentPoint`.
  False if it should be an absolute point.
  */
  public func addArc(
    withCenter center: WorkspacePoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat,
    clockwise: Bool, relative: Bool) {
      viewBezierPath.addArc(
        withCenter: viewPointFromWorkspacePoint(center, relative: relative),
        radius: radius * _layoutEngine.scale,
        startAngle: startAngle,
        endAngle: endAngle,
        clockwise: clockwise)

      setCurrentWorkspacePoint(
        _layoutEngine.scaledWorkspaceVectorFromViewVector(viewBezierPath.currentPoint),
        relative: false)
      _reflectionOfLastCurveControlPoint = nil
  }

  /**
  Appends a cubic Bézier curve to the receiver’s path.

  - parameter endPoint: The end point of the curve, specified in the Workspace coordinate system.
  - parameter controlPoint1: The first control point to use when computing the curve, specified in
  the Workspace coordinate system.
  - parameter controlPoint2: The second control point to use when computing the curve, specified in
  the Workspace coordinate system.
  - parameter relative: True if all specified points should be relative to the `currentPoint`. False
  if they should be are absolute points.
  */
  public func addCurve(
    to endPoint: WorkspacePoint, controlPoint1: WorkspacePoint, controlPoint2: WorkspacePoint,
    relative: Bool) {
    let viewEndPoint = viewPointFromWorkspacePoint(endPoint, relative: relative)
    let viewControlPoint1 = viewPointFromWorkspacePoint(controlPoint1, relative: relative)
    let viewControlPoint2 = viewPointFromWorkspacePoint(controlPoint2, relative: relative)
    viewBezierPath.addCurve(
      to: viewEndPoint, controlPoint1: viewControlPoint1, controlPoint2: viewControlPoint2)

    setCurrentWorkspacePoint(endPoint, relative: relative)
    _reflectionOfLastCurveControlPoint =
      viewBezierPath.currentPoint + viewEndPoint - viewControlPoint2
  }

  /**
  Appends a quadratic Bézier curve to the receiver’s path.

  - parameter endPoint: The end point of the curve, specified in the Workspace coordinate system.
  - parameter controlPoint: The control point of the curve, specified in the Workspace coordinate
  system.
  - parameter relative: True if the specified points should be relative to the `currentPoint`.
  False if they should be absolute points.
  */
  public func addQuadCurve(
    to endPoint: WorkspacePoint, controlPoint: WorkspacePoint, relative: Bool) {
    let viewEndPoint = viewPointFromWorkspacePoint(endPoint, relative: relative)
    let viewControlPoint = viewPointFromWorkspacePoint(controlPoint, relative: relative)
    viewBezierPath.addQuadCurve(to: viewEndPoint, controlPoint:viewControlPoint)

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

  - parameter endPoint: The end point of the curve, specified in the Workspace coordinate system.
  - parameter controlPoint2: The second control point to use when computing the curve, specified in
  the Workspace coordinate system (the first control point is determined automatically).
  - parameter relative: True if all specified points should be relative to the `currentPoint`. False
  if they should be absolute points.
  */
  public func addSmoothCurve(
    to endPoint: WorkspacePoint, controlPoint2: WorkspacePoint, relative: Bool) {
    let viewEndPoint = viewPointFromWorkspacePoint(endPoint, relative: relative)
    let viewControlPoint1 = _reflectionOfLastCurveControlPoint ?? viewBezierPath.currentPoint
    let viewControlPoint2 = viewPointFromWorkspacePoint(controlPoint2, relative: relative)
    viewBezierPath.addCurve(
      to: viewEndPoint, controlPoint1: viewControlPoint1, controlPoint2: viewControlPoint2)

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

  - parameter endPoint: The end point of the curve, specified in the Workspace coordinate system.
  - parameter relative: True if all specified points should be relative to the `currentPoint`. False
  if they should be absolute points.
  */
  public func addSmoothQuadCurve(to endPoint: WorkspacePoint, relative: Bool) {
    let viewEndPoint = viewPointFromWorkspacePoint(endPoint, relative: relative)
    let viewControlPoint = _reflectionOfLastCurveControlPoint ?? viewBezierPath.currentPoint
    viewBezierPath.addQuadCurve(to: viewEndPoint, controlPoint:viewControlPoint)

    setCurrentWorkspacePoint(endPoint, relative: relative)
    _reflectionOfLastCurveControlPoint =
      viewBezierPath.currentPoint + viewEndPoint - viewControlPoint
  }

  /**
  Appends the contents of the specified path object to the receiver’s path.

  - parameter bezierPath: The path to add to the receiver.
  */
  public func append(_ bezierPath: WorkspaceBezierPath) {
    viewBezierPath.append(bezierPath.viewBezierPath)

    self.currentWorkspacePoint = bezierPath.currentWorkspacePoint
    _reflectionOfLastCurveControlPoint = nil
  }

  /**
  Closes the most recently added subpath.
  */
  public func closePath() {
    viewBezierPath.close()

    self.currentWorkspacePoint =
      _layoutEngine.scaledWorkspaceVectorFromViewVector(viewBezierPath.currentPoint)
    _reflectionOfLastCurveControlPoint = nil
  }

  /**
  Moves the receiver’s current point to the specified location.

  - parameter point: A point in the Workspace coordinate system.
  - parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  public func move(to point: WorkspacePoint, relative: Bool) {
    viewBezierPath.move(to: viewPointFromWorkspacePoint(point, relative: relative))

    self.currentWorkspacePoint = point
    _reflectionOfLastCurveControlPoint = nil
  }

  /**
  Moves the receiver’s current point to the specified location.

  - parameter x: The destination x-point of the line segment, specified in the Workspace
  coordinate system.
  - parameter y: The destination y-point of the line segment, specified in the Workspace
  coordinate system.
  - parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  public func moveTo(x: CGFloat, y: CGFloat, relative: Bool) {
    move(to: WorkspacePoint(x: x, y: y), relative: relative)
  }

  /**
  Removes all points from the receiver, effectively deleting all subpaths.
  */
  public func removeAllPoints() {
    viewBezierPath.removeAllPoints()

    currentWorkspacePoint = WorkspacePoint.zero
    _reflectionOfLastCurveControlPoint = nil
  }

  // MARK: - Private

  /**
  Converts a Workspace point to a UIView point, using the current workspace layout.

  - parameter point: A point specified in the Workspace coordinate system.
  - parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  private func viewPointFromWorkspacePoint(_ point: WorkspacePoint, relative: Bool) -> CGPoint {
    let viewPoint = _layoutEngine.viewPointFromWorkspacePoint(point)
    return relative && !viewBezierPath.isEmpty ?
      (viewBezierPath.currentPoint + viewPoint) : viewPoint
  }

  /**
  Sets the current workspace point from the given point.

  - parameter point: A point specified in the Workspace coordinate system.
  - parameter relative: True if the specified point should be relative to the `currentPoint`. False
  if it should be an absolute point.
  */
  private func setCurrentWorkspacePoint(_ point: WorkspacePoint, relative: Bool) {
    self.currentWorkspacePoint = relative ? currentWorkspacePoint + point : point
  }
}
