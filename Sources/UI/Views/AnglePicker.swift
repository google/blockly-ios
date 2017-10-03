/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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
import QuartzCore

/**
 UI Control that is used for picking an angle from a clock-like dial.
 */
@objc(BKYAnglePicker)
@objcMembers public class AnglePicker: UIControl {

  /**
   Options for configuring the behavior of the angle picker.
   */
  public struct Options {
    /// The color of the ticks.
    public var tickColor: UIColor = ColorPalette.green.tint300

    /// The fill color of the angle.
    public var angleColor: UIColor = ColorPalette.green.tint600

    /// The fill color of the background circle.
    public var circleColor: UIColor = ColorPalette.grey.tint100

    /// The total number of ticks to render. These ticks act as snappable hotspots, whose
    /// behavior can be configured via `self.snapToThreshold` and `self.snapAwayThreshold`.
    public var numberOfTicks: Int = 24

    /// The number of major ticks to render. These ticks are larger in appearance.
    /// They are evenly distributed based on the total number of ticks, rounded down.
    public var numberOfMajorTicks: Int = 8

    /// The direction in which the angle increases.
    /// `true` for clockwise, or `false` for counterclockwise (the default).
    public var clockwise = false

    /// Offset the location of 0° (and all angles) by a constant.
    /// Usually either `0` (0° = right) or `90` (0° = up), for clockwise. Defaults to `0`.
    public var offset: Double = 0

    /// How close, in degrees, before the chosen angle should snap to a hotspot tick.
    public var snapToThreshold: Double = 0

    /// How far, in degrees, before the chosen angle should snap away from a hotspot tick.
    public var snapAwayThreshold: Double = 5

    /// Maximum allowed angle before wrapping.
    /// Usually either 360 (for 0 to 359.9) or 180 (for -179.9 to 180).
    public var wrap: Double = 360

    public init() {
    }
  }

  // MARK: - Properties

  /// The angle in degrees.
  public var angle = Double(0) {
    didSet {
      if angle == oldValue {
        return
      }

      renderAngle()

      // Notify of changes to the control.
      sendActions(for: .valueChanged)
    }
  }

  /// The configurable options of the angle picker.
  public let options: Options

  /// Layer for rendering the angle.
  fileprivate lazy var _angleLayer: CAShapeLayer = {
    let layer = CAShapeLayer()
    layer.allowsEdgeAntialiasing = true
    layer.fillColor = self.options.angleColor.cgColor
    layer.strokeColor = self.options.angleColor.cgColor
    layer.lineWidth = 1
    return layer
  }()

  /// Layer for rendering the background circle.
  fileprivate lazy var _backgroundCircleLayer: CAShapeLayer = {
    let layer = CAShapeLayer()
    layer.allowsEdgeAntialiasing = true
    layer.drawsAsynchronously = true
    layer.fillColor = self.options.circleColor.cgColor
    layer.strokeColor = nil
    layer.lineWidth = 0
    return layer
  }()

  /// Layer for rendering the ticks.
  fileprivate lazy var _tickLayer: CAShapeLayer = {
    let layer = CAShapeLayer()
    layer.allowsEdgeAntialiasing = true
    layer.drawsAsynchronously = true
    layer.strokeColor = self.options.tickColor.cgColor
    layer.fillColor = self.options.tickColor.cgColor
    layer.lineWidth = 2
    return layer
  }()

  /// The last hotspot angle that was touched.
  fileprivate var _lastHotspotTouched: Double?

  /// The number of degrees separating each tick.
  fileprivate var _tickSeparation: Double {
    return 360.0 / Double(options.numberOfTicks)
  }

  /// The radius of the angle picker.
  private var _radius: CGFloat {
    return min(bounds.width, bounds.height) / CGFloat(2)
  }

  // MARK: - Initializer

  public override init(frame: CGRect) {
    self.options = Options()
    super.init(frame: frame)
    commonInit()
  }

  public init(frame: CGRect, options: Options) {
    self.options = options
    super.init(frame: frame)
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    self.options = Options()
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    // Add render layers
    _backgroundCircleLayer.addSublayer(_angleLayer)
    _backgroundCircleLayer.addSublayer(_tickLayer)
    layer.addSublayer(_backgroundCircleLayer)

    // Render each layer
    renderBackground()
    renderTicks()
    renderAngle()
  }

  public override func layoutSubviews() {
    super.layoutSubviews()

    if _backgroundCircleLayer.frame == self.bounds {
      return
    }

    _backgroundCircleLayer.frame = self.bounds

    renderBackground()
    renderTicks()
    renderAngle()
  }

  // MARK: - Render Operations

  fileprivate func renderBackground() {
    let diameter = _radius * 2
    let frame = CGRect(x: (bounds.width - diameter) / 2,
                       y: (bounds.height - diameter) / 2,
                       width: diameter,
                       height: diameter)
    let circlePath = UIBezierPath(ovalIn: frame)
    _backgroundCircleLayer.path = circlePath.cgPath
    _backgroundCircleLayer.setNeedsDisplay()
    setNeedsDisplay()
  }

  fileprivate func renderTicks() {
    let numberOfTicks = options.numberOfTicks
    let numberOfMajorTicks = options.numberOfMajorTicks
    let clockwise = options.clockwise
    let offset = options.offset
    let majorTickStart = _radius - 24
    let majorTickEnd = _radius - 8
    let minorTickStart = _radius - 20
    let minorTickEnd = _radius - 12
    let radiansPerTick = CGFloat(Double.pi) * 2.0 / CGFloat(numberOfTicks)
    let circleCenter = CGPoint(x: bounds.width / 2, y: bounds.height / 2)

    var majorTickRate = -1
    if numberOfMajorTicks > 0 {
      majorTickRate = numberOfTicks / min(numberOfMajorTicks, numberOfTicks)
    }

    let tickPath = UIBezierPath(rect: CGRect.zero)
    for i in 0 ..< numberOfTicks {
      let isMajorTick = majorTickRate > 0 && i % majorTickRate == 0
      let tickStart = isMajorTick ? majorTickStart : minorTickStart
      let tickEnd = isMajorTick ? majorTickEnd : minorTickEnd
      let radian = (CGFloat(i) * radiansPerTick * (clockwise ? 1 : -1)) + CGFloat(toRadians(offset))
      let x1 = cos(radian) * tickStart + circleCenter.x
      let y1 = sin(radian) * tickStart + circleCenter.y
      let x2 = cos(radian) * tickEnd + circleCenter.x
      let y2 = sin(radian) * tickEnd + circleCenter.y
      tickPath.move(to: CGPoint(x: x1, y: y1))
      tickPath.addLine(to: CGPoint(x: x2, y: y2))
    }
    _tickLayer.path = tickPath.cgPath
    _tickLayer.setNeedsDisplay()
    setNeedsDisplay()
  }

  fileprivate func renderAngle() {
    // Create bezier path of angle
    let clockwise = options.clockwise
    let offset = options.offset
    let startAngle = offset.truncatingRemainder(dividingBy: 360)
    let endAngle = (startAngle + angle).truncatingRemainder(dividingBy: 360)

    let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    let startingPoint = CGPoint(
      x: cos(CGFloat(toRadians(startAngle)) * (clockwise ? 1: -1)) * _radius + center.x,
      y: sin(CGFloat(toRadians(startAngle)) * (clockwise ? 1: -1)) * _radius + center.y)

    let anglePath = UIBezierPath(rect: CGRect.zero)
    anglePath.move(to: center)
    anglePath.addLine(to: startingPoint)
    anglePath.addArc(
      withCenter: center,
      radius: _radius,
      startAngle: CGFloat(toRadians(startAngle)) * (clockwise ? 1: -1),
      endAngle: CGFloat(toRadians(endAngle)) * (clockwise ? 1: -1),
      clockwise: clockwise)
    anglePath.close()

    // Set the path
    _angleLayer.path = anglePath.cgPath

    // Make the line width thicker if it's a 0° angle.
    _angleLayer.lineWidth = startAngle == endAngle ? 2 : 1

    _angleLayer.setNeedsDisplay()

    setNeedsDisplay()
  }

  // MARK: - Angle Calculations

  fileprivate func toRadians(_ degrees: Double) -> Double {
    return degrees * .pi / 180.0
  }

  /**
   Returns the angle of a given point, relative to the center of the view.
   */
  fileprivate func angleRelativeToCenter(of point: CGPoint) -> Double {
    let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    let dx = point.x - center.x
    let dy = (point.y - center.y) * (options.clockwise ? 1: -1)
    var angle = Double(atan(dy/dx)) / .pi * 180.0

    if dx < 0 {
      // Adjust the angle if it's obtuse
      angle += 180
    }

    // Remove the original offset from the angle
    angle -= options.offset

    // Round to the nearest degree.
    angle = round(angle)

    return clampedAngle(angle)
  }

  /**
   Returns the closest hotspot angle to a given angle, within a certain threshold.

   - parameter angle: The angle to check.
   - parameter within: The threshold.
   - returns: The closest hotspot, or `nil` if none could be found based on the parameters.
   */
  fileprivate func hotspotAngle(for angle: Double, within: Double) -> Double? {
    guard options.numberOfTicks > 0 else {
      return nil
    }

    // Calculate the normalized version of this angle, and the two hotspot angles surrounding this
    // angle.
    let normalized = normalizedAngle(angle)
    let lowerAngle = floor(normalized / _tickSeparation) * _tickSeparation
    let higherAngle = (floor(normalized / _tickSeparation) + 1) * _tickSeparation

    // Figure out which hotspot is closer and within the threshold.
    let lowerDifference = abs(normalized - lowerAngle)
    let higherDifference = abs(normalized - higherAngle)

    guard lowerDifference <= within || higherDifference <= within else {
      // Both hotspots aren't within the threshold.
      return nil
    }

    let hotspotAngle = lowerDifference < higherDifference ? lowerAngle : higherAngle
    return clampedAngle(hotspotAngle)
  }

  /**
   Normalizes a given angle to be within 0 and 360 degrees.
   */
  fileprivate func normalizedAngle(_ angle: Double) -> Double {
    let normalized = angle.truncatingRemainder(dividingBy: 360)
    return normalized > 0 ? normalized : (normalized + 360)
  }

  /**
   Returns the normalized difference between two angles.
   */
  fileprivate func differenceBetweenAngles(_ angle1: Double, _ angle2: Double) -> Double {
    let normalized1 = normalizedAngle(angle1)
    let normalized2 = normalizedAngle(angle2)
    let difference = abs(normalized1 - normalized2)
    return difference > 180 ? abs(difference - 360) : difference
  }

  /**
   Clamps the given angle so it's between the range defined by `self.options.wrap`.
   */
  fileprivate func clampedAngle(_ angle: Double) -> Double {
    var clamped = normalizedAngle(angle)

    if clamped < 0 {
      clamped += 360
    }
    if clamped >= options.wrap {
      clamped -= 360
    }
    if clamped == 0 {
      // Edge case where angle could be "-0.0".
      clamped = abs(clamped)
    }

    return clamped
  }
}

extension AnglePicker {
  // MARK: - Touch Tracking

  public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    let relativeLocation = touch.location(in: self)

    guard let bezierPath = _backgroundCircleLayer.path,
      bezierPath.contains(relativeLocation) else {
      // Touch is outside the background circle, do nothing.
      return false
    }

    var angle = angleRelativeToCenter(of: relativeLocation)

    // Check if this angle is close enough to a hotspot (both snap-to and snap-away thresholds
    // are used here to prevent weird snapping UX).
    let threshold = max(options.snapToThreshold, options.snapAwayThreshold)
    if let hotspot = hotspotAngle(for: angle, within: threshold) {
      angle = hotspot
      _lastHotspotTouched = angle
    } else {
      _lastHotspotTouched = nil
    }

    self.angle = angle

    return true
  }

  public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    let relativeLocation = touch.location(in: self)
    var angle = angleRelativeToCenter(of: relativeLocation)

    if let lastHotspotTouched = _lastHotspotTouched,
      differenceBetweenAngles(angle, lastHotspotTouched) < options.snapAwayThreshold {
      // The angle is still close to a hotspot, keep it as-is.
      return true
    }

    // We've moved away from a hotspot. See if it's within a new hotspot.
    if let hotspot = hotspotAngle(for: angle, within: options.snapToThreshold) {
      angle = hotspot
      _lastHotspotTouched = hotspot
    } else {
      _lastHotspotTouched = nil
    }

    self.angle = angle

    return true
  }

  public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
    if let relativeLocation = touch?.location(in: self) {
      let angle = angleRelativeToCenter(of: relativeLocation)

      if let lastHotspotTouched = _lastHotspotTouched,
        differenceBetweenAngles(angle, lastHotspotTouched) < options.snapAwayThreshold {
        // The angle is still close to a hotspot, keep it as-is.
      } else {
        self.angle = angle
      }
    }

    _lastHotspotTouched = nil
  }

  public override func cancelTracking(with event: UIEvent?) {
    _lastHotspotTouched = nil
  }
}
