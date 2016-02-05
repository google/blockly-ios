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

  internal var bezierPath: UIBezierPath? {
    didSet {
      if bezierPath == oldValue {
        return
      }

      self.path = bezierPath?.CGPath
      setNeedsDisplay()
    }
  }

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
}
