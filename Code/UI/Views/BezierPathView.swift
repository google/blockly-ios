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
View used to draw a |UIBezierPath|, via drawRect.
*/
@objc(BKYBezierPathView)
public class BezierPathView: UIView {
  // MARK: - Properties

  internal var bezierPath: UIBezierPath?
  internal var fillColour: UIColor?
  internal var strokeColour: UIColor?
  internal var rtl: Bool = false

  // MARK: - Initializers

  public required init() {
    super.init(frame: CGRectZero)

    self.translatesAutoresizingMaskIntoConstraints = false
    self.backgroundColor = UIColor.clearColor()
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func drawRect(rect: CGRect) {
    guard let path = self.bezierPath else {
      return
    }

    // TODO:(vicng) If the bezier path doesn't intersect with "rect", don't draw it

    let context = UIGraphicsGetCurrentContext()

    // Save the current state before changing the transform.
    CGContextSaveGState(context)

    if (self.rtl) {
      // Flip across the horizontal axis
      CGContextTranslateCTM(context, self.bounds.width, 0)
      CGContextScaleCTM(context, -1.0, 1.0)
    }

    // Adjust the drawing options as needed.
    path.lineWidth = 1

    // Fill the path before stroking it so that the fill
    // color does not obscure the stroked line.
    if self.fillColour != nil {
      self.fillColour?.setFill()
      path.fill()
    }

    if self.strokeColour != nil {
      self.strokeColour!.setStroke()
      path.stroke()
    }

    // Restore the graphics state before drawing any other content.
    CGContextRestoreGState(context)
  }
}

// MARK: - Recyclable implementation

extension BezierPathView: Recyclable {
  public func recycle() {
    // TODO:(vicng) Implement this
  }
}
