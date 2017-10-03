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
Layer used to draw a `UIBezierPath`.
*/
@objc(BKYBezierPathLayer)
@objcMembers open class BezierPathLayer: CAShapeLayer {
  // MARK: - Properties

  /// The bezier path to draw
  open private(set) var bezierPath: UIBezierPath?

  /// The duration of the bezier path animation
  open var animationDuration = 0.3

  // MARK: - Initializers

  /// Default initializer for bezier path layer.
  public override init() {
    super.init()
    commonInit()
  }

  /**
   Initializes the path with a layer.

   - parameter layer: The layer from which custom fields should be copied.
   */
  public override init(layer: Any) {
    super.init(layer: layer)
    commonInit()
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  private func commonInit() {
    fillRule = kCAFillRuleEvenOdd
    drawsAsynchronously = true
  }

  // MARK: - Public

  /**
   Draws `self.path` using a given bezier path.

   - parameter bezierPath: The `UIBezierPath` to draw.
   - parameter animated: Flag determining if the draw should be animated or not.
   */
  open func setBezierPath(_ bezierPath: UIBezierPath?, animated: Bool) {
    if self.bezierPath == bezierPath {
      return
    }

    self.bezierPath = bezierPath

    // Keep track of the bezier path that's currently being presented on-screen. This method
    // may be interrupting an already running bezier path animation that was set earlier and we
    // want to start any new path animations from the layer's current state (not necessarily what
    // was previously set in `self.bezierPath`).
    let fromBezierPath = presentation()?.path

    // Kill off any potentially on-going animation
    removeAnimation(forKey: "path")

    if !animated || fromBezierPath == nil || bezierPath == nil {
      // No need to animate anything. Simply set the path.
      path = bezierPath?.cgPath
    } else {
      // Animate new bezier path
      let animation = CABasicAnimation(keyPath: "path")
      animation.fromValue = fromBezierPath
      animation.toValue = bezierPath?.cgPath
      animation.duration = animationDuration
      animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
      animation.fillMode = kCAFillModeBoth // Keeps `self.path` set to `toValue` on completion
      animation.isRemovedOnCompletion = false // Keeps `self.path` set to `toValue` on completion
      add(animation, forKey: animation.keyPath)
    }

    // Force re-draw
    setNeedsDisplay()
  }
}
