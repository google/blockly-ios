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
Protocol for measuring the size of a `Layout` when it is rendered.

- TODO:(vicng) The Obj-C bridging header isn't generated properly for this protocol, where the
protocol is not forward declared before the class that uses it. This is a bug with Xcode 7 beta 6.
When it's fixed, add in "@objc(BKYLayoutMeasurer)".
*/
public protocol FieldLayoutMeasurer {
  /**
  Measures and returns the amount of space needed to render a FieldLayout, in a UIView.

  - Parameter layout: The layout to measure
  - Parameter scale: The current scale of the layout, relative to Blockly coordinates.
  eg.
  1.0 means the Blockly layout is zoomed in at "100%".
  0.5 means the Blockly layout is zoomed in at "50%".
  2.0 means the Blockly layout is zoomed in at "200%".
  - Returns: The amount of space needed, in UIView coordinates.
  */
  static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize
}

/**
Abstract class for a `Field`-based `Layout`.
*/
@objc(BKYFieldLayout)
public class FieldLayout: Layout {
  // MARK: - Properties

  /// Object responsible for measuring the layout of this object.
  public var measurer: FieldLayoutMeasurer.Type

  // MARK: - Initializers

  public init(parentLayout: Layout?, measurer: FieldLayoutMeasurer.Type) {
    self.measurer = measurer
    super.init(parentLayout: parentLayout)
  }

  // MARK: - Super

  public override var childLayouts: [Layout] {
    // Fields are leaf nodes in the layout tree hierarchy, return an empty array.
    return []
  }

  public override func layoutChildren() {
    // TODO:(vicng) Pass scale in from a workspace value, and translate this value back into Blockly
    // coordinates
    self.size = measurer.measureLayout(self, scale: 1.0)
  }
}
