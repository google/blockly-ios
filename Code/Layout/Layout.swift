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
public protocol LayoutDelegate: class {
  /**
  Event that is called when a layout has changed.

  - Parameter layout: The `Layout` that changed.
  - Parameter flags: Set of flags indicating which parts of the layout that need to be updated from
  the UI side.
  */
  func layoutDidChange(layout: Layout, withFlags flags: LayoutFlag)

  // TODO:(vicng) Add an event for when a layout is deleted
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
  // MARK: - Static Properties

  /// Flag that should be used when the layout's entire display needs to be updated from the UI side
  public static let Flag_NeedsDisplay = LayoutFlag(highestOrderBitIndex: 0)

  /// Flag that should be used when `self.viewFrame` has been updated
  public static let Flag_UpdateViewFrame = LayoutFlag(highestOrderBitIndex: 1)

  // MARK: - Properties

  /// A unique identifier used to identify this layout for its lifetime
  public final let uuid: String
  /// The workspace node which this node belongs to.
  public final weak var workspaceLayout: WorkspaceLayout!
  /// The parent node of this layout. If this value is nil, this layout is the root node.
  public internal(set) final weak var parentLayout: Layout? {
    didSet {
      if parentLayout == oldValue {
        return
      }

      // Remove self from old parent's childLayouts
      oldValue?.childLayouts.remove(self)

      // Add self to new parent's childLayouts
      parentLayout?.childLayouts.insert(self)
    }
  }

  /// Layouts whose `parentLayout` is set to this layout
  public private(set) final var childLayouts = Set<Layout>()

  /// Position relative to `self.parentLayout`
  internal final var relativePosition: WorkspacePoint = WorkspacePointZero
  /// Content size of this layout
  internal final var contentSize: WorkspaceSize = WorkspaceSizeZero {
    didSet {
      updateTotalSize()
    }
  }
  /// Inline edge insets for the layout.
  internal final var edgeInsets: WorkspaceEdgeInsets = WorkspaceEdgeInsetsZero {
    didSet {
      updateTotalSize()
    }
  }

  // TODO(vicng): If ConnectionLayout is created, change absolutePosition to be final
  /// Absolute position of this layout, relative to the root node, in the Workspace coordinate
  /// system.
  internal var absolutePosition: WorkspacePoint = WorkspacePointZero
  /// Total size used by this layout. This value is calculated by combining `edgeInsets` and
  /// `contentSize`.
  internal private(set) final var totalSize: WorkspaceSize = WorkspaceSizeZero

  /// The absolute position of this layout, relative to the root node, in the View coordinate
  /// system.
  private final var viewAbsolutePosition = CGPointZero
  /**
  UIView frame for this layout relative to its parent *view* node's layout. For example, the parent
  view node layout for a Field is a Block, while the parent view node for a Block is a Workspace.
  */
  public internal(set) final var viewFrame: CGRect = CGRectZero {
    didSet {
      if viewFrame != oldValue {
        scheduleChangeEventWithFlags(Layout.Flag_UpdateViewFrame)
      }
    }
  }

  /// All flags that this layout's corresponding view needs to update when a change event is sent.
  private final var layoutFlags = LayoutFlag.None

  // TODO:(vicng) Consider making the LayoutView a property of the layout instead of using a
  // delegate.
  /// The delegate for events that occur on this instance
  public final weak var delegate: LayoutDelegate?

  // MARK: - Initializers

  public init(workspaceLayout: WorkspaceLayout!) {
    self.uuid = NSUUID().UUIDString
    self.workspaceLayout = workspaceLayout
    super.init()
  }

  // MARK: - Abstract

  /**
  This method repositions its children and recalculates its `contentSize` based on the positions
  of its children.

  - Parameter includeChildren: A flag indicating whether `performLayout(:)` should be called on any
  child layouts, prior to repositioning them. It is the responsibility of subclass implementations
  to honor this flag.
  - Note: This method needs to be implemented by a subclass of `Layout`.
  */
  public func performLayout(includeChildren includeChildren: Bool) {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
  }

  // MARK: - Public

  /**
  For every `Layout` in its tree hierarchy (including itself), this method recalculates its
  `contentSize`, `relativePosition`, `absolutePosition`, and `viewFrame`, based on the current state
  of `self.parentLayout`.
  */
  public func updateLayoutDownTree() {
    performLayout(includeChildren: true)
    refreshViewPositionsForTree()
  }

  /**
  Performs the layout of its direct children (and not of its grandchildren) and repeats this for
  every parent up the tree. When the top is reached, the `absolutePosition` and `viewFrame` for
  each layout in the tree is re-calculated.
  */
  public final func updateLayoutUpTree() {
    // Re-position content at this level
    performLayout(includeChildren: false)

    if let parentLayout = self.parentLayout {
      // Recursively do the same thing up the tree hierarchy
      parentLayout.updateLayoutUpTree()
    } else {
      // The top of the tree has been reached. Re-calculate view positions for the entire tree.
      refreshViewPositionsForTree()
    }
  }

  /**
  Schedules to send a change event to `self.delegate` via `LayoutEventManager.sharedInstance`
  (if one hasn't already been scheduled) and appends any additional flags to that scheduled event's
  set of flags.

  - Parameter flags: Additional flags to append to the next scheduled change event.
  */
  public final func scheduleChangeEventWithFlags(flags: LayoutFlag) {
    if delegate == nil {
      return
    }

    // Append the flags to the current set of flags
    self.layoutFlags.unionInPlace(flags)

    if self.layoutFlags.hasFlagSet() {
      LayoutEventManager.sharedInstance.scheduleChangeEventForLayout(self)
    }
  }

  // MARK: - Internal

  /**
  For every `Layout` in its tree hierarchy (including itself), updates the `absolutePosition`,
  `viewFrameOrigin`, and `viewFrame` based on the current state of this object.

  - Parameter includeFields: If true, recursively update view frames for field layouts. If false,
  skip them.
  */
  internal final func refreshViewPositionsForTree(includeFields includeFields: Bool = true) {
    refreshViewPositionsForTree(
      parentAbsolutePosition: (parentLayout?.absolutePosition ?? WorkspacePointZero),
      parentViewAbsolutePosition: (parentLayout?.viewAbsolutePosition ?? CGPointZero),
      parentContentSize: (parentLayout?.contentSize ?? self.contentSize),
      rtl: self.workspaceLayout.workspace.isRTL,
      includeFields: includeFields)
  }

  /**
  Sends a change event to `self.delegate` (with all flags that were set via
  `scheduleChangeEventWithFlags(_)`). If no flags were set since that last call to
  `sendChangeEvent()`, nothing happens.
  */
  internal final func sendChangeEvent() {
    // Grab the current state of self.layoutFlags
    let changedLayoutFlags = self.layoutFlags

    // Reset the layout flags now, so the delegate below could potentially call
    // scheduleChangeEventWithFlags(_) without consequence of them being reset afterward
    self.layoutFlags = LayoutFlag.None

    // Send change event
    if changedLayoutFlags.hasFlagSet() {
      self.delegate?.layoutDidChange(self, withFlags: changedLayoutFlags)
    }
  }

  // MARK: - Private

  /**
  For every `Layout` in its tree hierarchy (including itself), updates the `absolutePosition`,
  `viewFrameOrigin`, and `viewFrame` based on the current state of this object.

  - Parameter parentAbsolutePosition: The absolute position of its parent layout (specified as a
  Workspace coordinate system point)
  - Parameter parentViewAbsolutePosition: The absolute position of its parent's view (specified as a
  UIView coordinate system point)
  - Parameter parentContentSize: The content size of its parent layout (specified as a Workspaced
  coordinate system size)
  - Parameter rtl: Flag for if the layout should be positioned in RTL mode.
  - Parameter includeFields: If true, recursively update view positions for field layouts. If false,
  skip them.
  - Note: All parent parameters are defined in the method signature so we can eliminate direct
  references to `self.parentLayout` inside this method. This results in better performance.
  */
  private final func refreshViewPositionsForTree(
    parentAbsolutePosition parentAbsolutePosition: WorkspacePoint,
    parentViewAbsolutePosition: CGPoint,
    parentContentSize: WorkspaceSize,
    rtl: Bool, includeFields: Bool)
  {
    // TODO:(vicng) Optimize this method so it only recalculates view positions for layouts that
    // are "dirty"

    // Update the layout's absolute position in the workspace
    self.absolutePosition = WorkspacePointMake(
      parentAbsolutePosition.x + relativePosition.x + edgeInsets.left,
      parentAbsolutePosition.y + relativePosition.y + edgeInsets.top)

    // Update the layout's absolute position in the view coordinate system
    var viewRelativePosition = CGPointZero
    if rtl {
      // In RTL, the x position is calculated relative to the top-right corner of its parent
      viewRelativePosition.x = workspaceLayout.viewUnitFromWorkspaceUnit(
        parentContentSize.width - (relativePosition.x + edgeInsets.left + contentSize.width))
    } else {
      viewRelativePosition.x =
        workspaceLayout.viewUnitFromWorkspaceUnit(relativePosition.x + edgeInsets.left)
    }
    viewRelativePosition.y = workspaceLayout.viewUnitFromWorkspaceUnit(
      relativePosition.y + edgeInsets.top)
    self.viewAbsolutePosition = parentViewAbsolutePosition + viewRelativePosition

    // Update the view frame (InputLayouts and BlockGroupLayouts do not need to update their view
    // frames as they do not get rendered)
    if !(self is InputLayout) && !(self is BlockGroupLayout) &&
      (includeFields || !(self is FieldLayout))
    {
      var viewFrameOrigin = self.viewAbsolutePosition

      // View frames for fields are calculated relative to its parent's parent
      // (InputLayout -> BlockLayout)
      if (self is FieldLayout) {
        if let grandparentLayout = parentLayout?.parentLayout {
          viewFrameOrigin.x -= grandparentLayout.viewAbsolutePosition.x
          viewFrameOrigin.y -= grandparentLayout.viewAbsolutePosition.y
        }
      }

      let viewSize = workspaceLayout.viewSizeFromWorkspaceSize(self.contentSize)
      self.viewFrame =
        CGRectMake(viewFrameOrigin.x, viewFrameOrigin.y, viewSize.width, viewSize.height)
    }

    for layout in self.childLayouts {
      // Automatically skip if this is a field and we're not allowing them
      if includeFields || !(layout is FieldLayout) {
        layout.refreshViewPositionsForTree(
          parentAbsolutePosition: self.absolutePosition,
          parentViewAbsolutePosition: self.viewAbsolutePosition,
          parentContentSize: self.contentSize,
          rtl: rtl,
          includeFields: includeFields)
      }
    }
  }

  /**
  Updates the `totalSize` value based on the current state of `contentSize` and `edgeInsets`.
  */
  private func updateTotalSize() {
    totalSize.width = contentSize.width + edgeInsets.left + edgeInsets.right
    totalSize.height = contentSize.height + edgeInsets.top + edgeInsets.bottom
  }
}

// MARK: - Layout Flag

/**
Flags for marking which parts of a `Layout` that need to be updated by its delegate.

A total of 64 flags can be defined:
- Common flags are defined by Layout.Flag_*, up to a maximum of 14 flags, which start at the highest
order bit (ie. 63, 62, etc).
- Subclasses of `Layout` can define up to 50 custom layout flags, which start at the lowest order
bit (ie. 0, 1, etc).
*/
public struct LayoutFlag: OptionSetType {
  // MARK: - Static Properties
  public static let None = LayoutFlag(rawValue: 0)
  public static let All = LayoutFlag(rawValue: UInt64.max)
  private static let MaximumNumberOfCustomFlags: UInt64 = 50

  // MARK: - Properties
  public let rawValue: UInt64

  // MARK: - Initializers

  /**
  Initializer for the `Layout` class looking to define a common layout flag.

  - Parameter highestOrderBitIndex: The bit index to use when defining this layout flag, starting
  from the highest order bit.
  - Note: An assertion is made in this method that `highestOrderBitIndex < 14`.
  */
  private init(highestOrderBitIndex: UInt64) {
    // Event flags defined in `Layout` should start at the highest order bit (which is why this
    // initializer is marked as private). These flags are reserved from use by any subclass.
    let bitShiftIndex = (63 - highestOrderBitIndex)
    self.rawValue = 1 << bitShiftIndex

    // Double check that this bit isn't crossing over into the custom layout flags
    bky_assert(highestOrderBitIndex < (64 - LayoutFlag.MaximumNumberOfCustomFlags),
      message: "Layout flag bit index \(bitShiftIndex) is reserved for custom flags.")
  }

  /**
   Initializer for `Layout` subclasses looking to define a custom layout flag.

   - Parameter lowestOrderBitIndex: The bit index to use when defining this layout flag, starting
   from the lowest order bit.
   - Note: An assertion is made in this method that `lowestOrderBitIndex < 50`.
  */

  public init(_ lowestOrderBitIndex: UInt64) {
    // Event flags defined by subclasses of `Layout` should start at the lowest order bit
    self.rawValue = (1 << lowestOrderBitIndex)

    // Double check that this bit isn't crossing over into the common layout flags
    bky_assert(lowestOrderBitIndex < LayoutFlag.MaximumNumberOfCustomFlags,
      message: "Layout flag bit index \(lowestOrderBitIndex) is reserved for common flags and " +
               "may not be used by any subclass.")
  }

  public init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  // MARK: - Public

  /**
  Return if a flag has been set for this value.

  - Returns: The equivalent of `self != LayoutFlag.None`.
  */
  public func hasFlagSet() -> Bool {
    return self != LayoutFlag.None
  }

  /**
  - Returns: True if `self` shares at least one common flag with `other`.
  */
  public func intersectsWith(other: LayoutFlag) -> Bool {
    return intersect(other).hasFlagSet()
  }
}
