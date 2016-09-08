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
public class BezierPathLayer: CAShapeLayer {
  // MARK: - Properties

  /// The bezier path to draw
  public private(set) var bezierPath: UIBezierPath?

  /// The duration of the bezier path animation
  public var animationDuration = 0.3

  // MARK: - Initializers

  public override init() {
    super.init()
    self.fillRule = kCAFillRuleEvenOdd
  }

  public override init(layer: AnyObject) {
    super.init(layer: layer)
    self.fillRule = kCAFillRuleEvenOdd
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.fillRule = kCAFillRuleEvenOdd
  }

  // MARK: - Public

  /**
   Draws `self.path` using a given bezier path.

   - Parameter bezierPath: The `UIBezierPath` to draw.
   - Parameter animated: Flag determining if the draw should be animated or not.
   */
  public func setBezierPath(bezierPath: UIBezierPath?, animated: Bool) {
    if self.bezierPath == bezierPath {
      return
    }

    self.bezierPath = bezierPath

    // Keep track of the bezier path that's currently being presented on-screen. This method
    // may be interrupting an already running bezier path animation that was set earlier and we
    // want to start any new path animations from the layer's current state (not necessarily what
    // was previously set in `self.bezierPath`).
    let fromBezierPath = (presentationLayer() as? CAShapeLayer)?.path

    // Kill off any potentially on-going animation
    removeAnimationForKey("path")

    if !animated || fromBezierPath == nil || bezierPath == nil {
      // No need to animate anything. Simply set the path.
      path = bezierPath?.CGPath
    } else {
      // Animate new bezier path
      let animation = CABasicAnimation(keyPath: "path")
      animation.fromValue = fromBezierPath
      animation.toValue = bezierPath?.CGPath
      animation.duration = animationDuration
      animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
      animation.fillMode = kCAFillModeBoth // Keeps `self.path` set to `toValue` on completion
      animation.removedOnCompletion = false // Keeps `self.path` set to `toValue` on completion
      addAnimation(animation, forKey: animation.keyPath)
    }

    // Force re-draw
    setNeedsDisplay()
  }
}
