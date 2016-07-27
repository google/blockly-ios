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
}

/**
 Listener for events that modify the parent/child relationships for this `Layout`.
 */
@objc(BKYLayoutHierarchyListener)
public protocol LayoutHierarchyListener {
  /**
   Event that is called when a layout has adopted a child layout.

   - Parameter layout: The parent `Layout`.
   - Parameter childLayout: The child `Layout`.
   - Parameter oldParentLayout: The previous value of `childLayout.parentLayout` prior to being
   adopted by `layout`
   */
  func layout(layout: Layout,
    didAdoptChildLayout childLayout: Layout, fromOldParentLayout oldParentLayout: Layout?)

  /**
   Event that is called when a layout has removed a child layout.

   - Parameter layout: The parent `Layout`.
   - Parameter childLayout: The child `Layout`.
   */
  func layout(layout: Layout, didRemoveChildLayout childLayout: Layout)
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

  /// The `LayoutEngine` used for layout related functions such as unit scaling and
  /// UI configuration.
  public final let engine: LayoutEngine

  /// Convenience property for accessing `self.engine.config`
  public var config: LayoutConfig {
    return engine.config
  }

  /// The parent node of this layout. If this value is nil, this layout is the root node.
  public private(set) final weak var parentLayout: Layout?

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

  // TODO:(#34) If ConnectionLayout is created, change absolutePosition to be final
  /// Absolute position of this layout, relative to the root node, in the Workspace coordinate
  /// system.
  internal var absolutePosition: WorkspacePoint = WorkspacePointZero
  /// Total size used by this layout. This value is calculated by combining `edgeInsets` and
  /// `contentSize`.
  internal private(set) final var totalSize: WorkspaceSize = WorkspaceSizeZero

  /// An offset that should be applied to the positions of `childLayouts`, specified in the
  /// Workspace coordinate system.
  internal final var childContentOffset: WorkspacePoint = WorkspacePointZero

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

  /// The delegate for events that occur on this instance
  public final weak var delegate: LayoutDelegate?

  /// A set of Layout hierarchy listeners on this instance
  public final var hierarchyListeners = WeakSet<LayoutHierarchyListener>()

  // MARK: - Initializers

  public init(engine: LayoutEngine) {
    self.uuid = NSUUID().UUIDString
    self.engine = engine
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
    bky_assertionFailure("\(#function) needs to be implemented by a subclass")
  }

  // MARK: - Public

  /**
   For a given `Layout`, adds it to `self.childLayouts` and sets its `parentLayout` property to
   this instance.

   If the given `Layout` had an existing parent, this method automatically removes it from that
   parent's `childLayouts`. This ensures that child `Layout` objects do not belong to two different
   `Layout` parents.

   - Parameter layout: The child `Layout` to adopt
   */
  public func adoptChildLayout(layout: Layout) {
    if layout.parentLayout == self {
      return
    }

    let oldParentLayout = layout.parentLayout

    // Remove the child layout from its old parent (if necessary)
    if let oldParentLayout = oldParentLayout {
      oldParentLayout.childLayouts.remove(layout)
      // Update its new relative position to where it is in its new layout tree
      layout.relativePosition = layout.absolutePosition - absolutePosition
      // With the new relative position, refresh the view positions for this part of the tree
      layout.refreshViewPositionsForTree()
    }

    // Add this child layout and set its parent
    childLayouts.insert(layout)
    layout.parentLayout = self

    // Fire hierachy listeners
    hierarchyListeners.forEach {
      $0.layout(self, didAdoptChildLayout: layout, fromOldParentLayout: oldParentLayout)
    }
  }

  /**
   For a given `Layout`, removes it from `self.childLayouts` and sets its `parentLayout` property to
   `nil`.

   - Parameter layout: The child `Layout` to remove
   */
  public func removeChildLayout(layout: Layout) {
    if !childLayouts.contains(layout) {
      return
    }

    // Remove this child layout
    childLayouts.remove(layout)
    layout.parentLayout = nil

    // Fire hierachy listeners
    hierarchyListeners.forEach { $0.layout(self, didRemoveChildLayout: layout) }
  }

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
    // TODO:(#116) Rename this method to sendChangeEventWithFlags
    if delegate == nil {
      return
    }

    // Append the flags to the current set of flags
    self.layoutFlags.unionInPlace(flags)

    // Send the change event immediately
    sendChangeEvent()
  }

  /**
   Returns an array of `Layout` instances for the tree headed by this `Layout` instance, in no
   particular order.

   - Parameter type: [Optional] Filters `Layout` instances by a specific type.
   - Returns: An array of all `Layout` instances.
   */
  public final func flattenedLayoutTree<T where T: Layout>(ofType type: T.Type? = nil) -> [T] {
    var allLayouts = [T]()

    if let layout = self as? T {
      allLayouts.append(layout)
    }

    for layout in childLayouts {
      allLayouts.appendContentsOf(layout.flattenedLayoutTree(ofType: type))
    }
    return allLayouts
  }

  // MARK: - Internal

  /**
  For every `Layout` in its tree hierarchy (including itself), updates `self.absolutePosition`
  and `self.viewFrame` based on the current state of this object.

  - Parameter includeFields: If true, recursively update view frames for field layouts. If false,
  skip them.
  */
  internal final func refreshViewPositionsForTree(includeFields includeFields: Bool = true) {
    refreshViewPositionsForTree(
      parentAbsolutePosition: (parentLayout?.absolutePosition ?? WorkspacePointZero),
      parentContentSize: (parentLayout?.contentSize ?? self.contentSize),
      contentOffset: (parentLayout?.childContentOffset ?? WorkspacePointZero),
      rtl: self.engine.rtl,
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
  For every `Layout` in its tree hierarchy (including itself), updates `self.absolutePosition`
  and `self.viewFrame` based on the current state of this object.

  - Parameter parentAbsolutePosition: The absolute position of its parent layout (specified as a
  Workspace coordinate system point)
  - Parameter parentContentSize: The content size of its parent layout (specified as a Workspace
  coordinate system size)
  - Parameter contentOffset: An offset that should be applied to this view frame (specified as a
  Workspace coordinate system point)
  - Parameter rtl: Flag for if the layout should be positioned in RTL mode.
  - Parameter includeFields: If true, recursively update view positions for field layouts. If false,
  skip them.
  - Note: All parent parameters are defined in the method signature so we can eliminate direct
  references to `self.parentLayout` inside this method. This results in better performance.
  */
  private final func refreshViewPositionsForTree(
    parentAbsolutePosition parentAbsolutePosition: WorkspacePoint,
    parentContentSize: WorkspaceSize,
    contentOffset: WorkspacePoint,
    rtl: Bool, includeFields: Bool)
  {
    // TODO:(#29) Optimize this method so it only recalculates view positions for layouts that
    // are "dirty"

    // Update the layout's absolute position in the workspace
    self.absolutePosition = WorkspacePointMake(
      parentAbsolutePosition.x + relativePosition.x + edgeInsets.left,
      parentAbsolutePosition.y + relativePosition.y + edgeInsets.top)

    // Update the view frame, if needed
    if (includeFields || !(self is FieldLayout))
    {
      // Calculate the view frame's position
      var viewFrameOrigin = CGPointZero
      if rtl {
        // In RTL, the x position is calculated relative to the top-right corner of its parent
        viewFrameOrigin.x = self.engine.viewUnitFromWorkspaceUnit(
          parentContentSize.width -
          (relativePosition.x + edgeInsets.left + contentSize.width + contentOffset.x))
      } else {
        viewFrameOrigin.x = self.engine.viewUnitFromWorkspaceUnit(
          relativePosition.x + edgeInsets.left + contentOffset.x)
      }
      viewFrameOrigin.y = self.engine.viewUnitFromWorkspaceUnit(
        relativePosition.y + edgeInsets.top + contentOffset.y)

      let viewSize = self.engine.viewSizeFromWorkspaceSize(self.contentSize)
      self.viewFrame =
        CGRectMake(viewFrameOrigin.x, viewFrameOrigin.y, viewSize.width, viewSize.height)
    }

    for layout in self.childLayouts {
      // Automatically skip if this is a field and we're not allowing them
      if includeFields || !(layout is FieldLayout) {
        layout.refreshViewPositionsForTree(
          parentAbsolutePosition: self.absolutePosition,
          parentContentSize: self.contentSize,
          contentOffset: self.childContentOffset,
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
