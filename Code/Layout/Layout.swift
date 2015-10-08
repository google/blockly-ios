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
Protocol for events that occur on a `Layout`.
*/
@objc(BKYLayoutDelegate)
public protocol LayoutDelegate {
  /**
  Event that is called when an entire layout's display needs to be updated from the UI side.

  - Parameter layout: The `Layout` that changed.
  */
  func layoutDisplayChanged(layout: Layout)

  /**
  Event that is called when a layout's needs to be repositioned from the UI side.

  - Parameter layout: The `Layout` that changed.
  */
  func layoutPositionChanged(layout: Layout)
}

/**
Abstract base class that defines a node in a tree-hierarchy. It is used for storing layout
information on how to render and position itself relative to other nodes in this hierarchy. Nodes
can represent fields, blocks, or a workspace (which are always root nodes).

The coordinate system used inside a `Layout` object is in the "Workspace coordinate system".
There are many properties inside a `Layout` object that should not be accessed or
modified by UI views during rendering (eg. `relativePosition`, `size`, `absolutePosition`). Instead,
a UI view can simply access the property `viewFrame` to determine its "UIView coordinate system"
position and size.
*/
@objc(BKYLayout)
public class Layout: NSObject {
  // MARK: - Properties

  /// A unique identifier used to identify this block for its lifetime
  public let uuid: String
  /// The workspace node which this node belongs to.
  public weak var workspaceLayout: WorkspaceLayout!
  /// The parent node of this layout. If this value is nil, this layout is the root node.
  public weak var parentLayout: Layout?

  /// Position relative to `self.parentLayout`
  internal var relativePosition: WorkspacePoint = WorkspacePointZero
  /// Content size of this layout
  internal var contentSize: WorkspaceSize = WorkspaceSizeZero {
    didSet {
      updateTotalSize()
    }
  }
  /// Inline edge insets for the layout.
  internal var edgeInsets: WorkspaceEdgeInsets = WorkspaceEdgeInsetsZero {
    didSet {
      updateTotalSize()
    }
  }
  /// Absolute position relative to the root node.
  internal private(set) var absolutePosition: WorkspacePoint = WorkspacePointZero
  /// Total size used by this layout. This value is calculated by combining `edgeInsets` and
  /// `contentSize`.
  internal private(set) var totalSize: WorkspaceSize = WorkspaceSizeZero

  /**
  UIView frame for this layout relative to its parent *view* node's layout. For example, the parent
  view node layout for a Field is a Block, while the parent view node for a Block is a Workspace.
  */
  public internal(set) var viewFrame: CGRect = CGRectZero {
    didSet {
      if viewFrame != oldValue {
        // Mark this layout for repositioning
        self.needsRepositioning = true
      }
    }
  }

  /**
  Flag indicating if this layout's corresponding view needs to be completely re-drawn.
  Setting this value to true schedules a change event to be called on the `delegate` at the
  beginning of the next run loop.
  */
  public var needsDisplay: Bool = false {
    didSet {
      if self.needsDisplay {
        LayoutEventManager.sharedInstance.scheduleChangeEventForLayout(self)
      }
    }
  }
  /**
  Flag indicating if this layout's corresponding view needs to be repositioned.
  Setting this value to true schedules a change event to be called on the `delegate` at the
  beginning of the next run loop.
  */
  public var needsRepositioning: Bool = false {
    didSet {
      if self.needsRepositioning {
        LayoutEventManager.sharedInstance.scheduleChangeEventForLayout(self)
      }
    }
  }

  /// The delegate for events that occur on this instance
  public weak var delegate: LayoutDelegate?

  // MARK: - Initializers

  public init(workspaceLayout: WorkspaceLayout!, parentLayout: Layout? = nil) {
    self.uuid = NSUUID().UUIDString
    self.parentLayout = parentLayout
    self.workspaceLayout = workspaceLayout
    super.init()
  }

  // MARK: - Abstract

  /**
  Returns an array containing all direct children `Layout` objects underneath this one.

  - Note: This method needs to be implemented by a subclass of `Layout`.
  */
  internal var childLayouts: [Layout] {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
    return []
  }

  /**
  For every `Layout` in its tree hierarchy (including itself), this method recalculates its `size`
  and `relativePosition` values.

  - Note: This method needs to be implemented by a subclass of `Layout`.
  */
  internal func layoutChildren() {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
  }

  // MARK: - Public

  /**
  For every `Layout` in its tree hierarchy (including itself), this method recalculates its
  `size`, `relativePosition`, `absolutePosition`, and `viewFrame`, based on the current state of
  `self.parentLayout`.
  */
  public func updateLayout() {
    // TODO:(vicng) Rename these methods to properly reflect their nuances and how they should be
    // called
    layoutChildren()
    refreshViewBoundsForTree()
  }

  // MARK: - Internal

  /**
  For every `Layout` in its tree hierarchy (including itself), updates the `absolutePosition` and
  `viewFrame` based on the current state of this object.
  */
  internal func refreshViewBoundsForTree() {
    // Update absolute position
    if parentLayout != nil {
      self.absolutePosition = WorkspacePointMake(
        parentLayout!.absolutePosition.x + relativePosition.x + edgeInsets.left,
        parentLayout!.absolutePosition.y + relativePosition.y + edgeInsets.top)
    } else {
      self.absolutePosition = WorkspacePointMake(edgeInsets.left, edgeInsets.top)
    }

    // Update the view frame
    refreshViewFrame()

    for layout in self.childLayouts {
      layout.refreshViewBoundsForTree()
    }
  }

  /**
  Refreshes `viewFrame` based on the current state of this object.
  */
  internal func refreshViewFrame() {
    // Update the view frame
    self.viewFrame =
      workspaceLayout.viewFrameFromWorkspacePoint(self.absolutePosition, size: self.contentSize)
  }

  /**
  If `needsDisplay` or `needsRepositioning` has been set for this layout, the appropriate change
  event is sent to the `delegate`.

  After this method has finished execution, both `needsDisplay` and `needsRepositioning` are set
  back to false.
  */
  internal func sendChangeEvent() {
    if self.needsDisplay {
      self.delegate?.layoutDisplayChanged(self)
    } else if self.needsRepositioning {
      self.delegate?.layoutPositionChanged(self)
    }

    self.needsDisplay = false
    self.needsRepositioning = false
  }

  // MARK: - Private

  /**
  Updates the `totalSize` value based on the current state of `contentSize` and `edgeInsets`.
  */
  private func updateTotalSize() {
    totalSize.width = contentSize.width + edgeInsets.left + edgeInsets.right
    totalSize.height = contentSize.height + edgeInsets.top + edgeInsets.bottom
  }
}
