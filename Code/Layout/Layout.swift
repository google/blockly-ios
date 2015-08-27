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

/** Point in the Blockly coordinate system. */
public typealias BKYPoint = CGPoint
public var BKYPointZero: BKYPoint { return CGPointZero }
public func BKYPointMake(x: CGFloat, _ y: CGFloat) -> BKYPoint {
  return CGPointMake(x, y)
}

/** Size in the Blockly coordinate system. */
public typealias BKYSize = CGSize
public var BKYSizeZero: BKYSize { return CGSizeZero }
public func BKYSizeMake(width: CGFloat, _ height: CGFloat) -> BKYSize {
  return CGSizeMake(width, height)
}

/**
Abstract base class that defines a node in a tree-hierarchy. It is used for storing layout
information on how to render and position itself relative to other nodes in this hierarchy. Nodes
can represent fields, blocks, or a workspace (which are always root nodes).

The coordinate system used inside a `Layout` object is in the "Blockly" space. To obtain a
translation of a `Layout` object's absolute position and size from "Blockly" coordinates to `UIView`
coordinates, use the method `viewFrameAtScale(:)`.
*/
@objc(BKYLayout)
public class Layout: NSObject {
  // MARK: - Properties

  /// The parent node of this layout. If this value is nil, this layout is the root node.
  public weak var parentLayout: Layout?

  /// Position relative to `self.parentLayout`
  public var relativePosition: BKYPoint = CGPointZero
  /// Size required by this layout
  public var size: BKYSize = CGSizeZero
  // TODO:(vicng) Replace this property with a CGRect viewFrame.
  /// Stored position relative to its parent *view* node. For example, the parent view node for a
  /// Field is a Block, while the parent view node for a Block is a Workspace. */
  public var absolutePosition: BKYPoint = BKYPointZero {
    didSet {
      if absolutePosition != oldValue {
        // TODO:(vicng) Generate change event
      }
    }
  }
  /// Z-position of the layout. Those with higher values should render on top of those with lower
  /// values.
  public var zPosition: CGFloat = 0

  /// Flag indicating if this layout's corresponding view needs to be completely re-drawn.
  public var needsDisplay: Bool = false
  /// Flag indicating if this layout's corresponding view needs to be repositioned.
  public var needsRepositioning: Bool = false

  // MARK: - Initializers

  public init(parentLayout: Layout? = nil) {
    self.parentLayout = parentLayout
    super.init()
  }

  // MARK: - Abstract

  /**
  Returns an array containing all direct children |Layout| objects underneath this one.

  - Note: This method needs to be implemented by a subclass of |Layout|.
  */
  internal var childLayouts: [Layout] {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
    return []
  }

  /**
  For every layout in this tree hierarchy (including this one), this method recalculates its `size`
  and `relativePosition` values.

  - Note: This method needs to be implemented by a subclass of |Layout|.
  */
  internal func layoutChildren() {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
  }

  // MARK: - Public

  /**
  Returns a UIView frame (ie. absolute position/size) scaled by a specific value.
  */
  public func viewFrameAtScale(scale: CGFloat) -> CGRect {
    return CGRectMake(
      ceil(self.absolutePosition.x * scale),
      ceil(self.absolutePosition.y * scale),
      ceil(self.size.width * scale),
      ceil(self.size.height * scale))
  }

  /**
  For every layout in this tree hierarchy (including this one), this method recalculates its `size`,
  `relativePosition`, and `absolutePosition`, based on the current state of `self.parentLayout`.
  */
  public func updateLayout() {
    layoutChildren()
    refreshAbsolutePositionsOfLayoutTree()
  }

  // MARK: - Internal

  /**
  For every layout in this tree hierarchy (including this one), updates the absolute position
  based on the current state of `self.parentLayout`.
  */
  internal func refreshAbsolutePositionsOfLayoutTree() {
    if parentLayout != nil {
      self.absolutePosition = BKYPointMake(
        parentLayout!.absolutePosition.x + relativePosition.x,
        parentLayout!.absolutePosition.y + relativePosition.y)
    } else {
      self.absolutePosition = BKYPointZero
    }

    for layout in self.childLayouts {
      layout.refreshAbsolutePositionsOfLayoutTree()
    }

    // TODO:(vicng) Potentially generate a change event back to the corresponding view
  }

  /**
  Returns the minimum amount of space needed to render `self.childLayouts`.
  */
  internal func sizeThatFitsForChildLayouts() -> BKYSize {
    var size = BKYSizeZero

    for layout in self.childLayouts {
      size.width = max(size.width, layout.relativePosition.x + layout.size.width)
      size.height = max(size.height, layout.relativePosition.y + layout.size.height)
    }
    
    return size
  }
}
