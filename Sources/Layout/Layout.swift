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

  - parameter layout: The `Layout` that changed.
  - parameter flags: Set of flags indicating which parts of the layout that need to be updated from
  the UI side.
  */
  func layoutDidChange(_ layout: Layout, withFlags flags: LayoutFlag, animated: Bool)
}

/**
 Listener for events that modify the parent/child relationships for this `Layout`.
 */
@objc(BKYLayoutHierarchyListener)
public protocol LayoutHierarchyListener {
  /**
   Event that is called when a layout has adopted a child layout.

   - parameter layout: The parent `Layout`.
   - parameter childLayout: The child `Layout`.
   - parameter oldParentLayout: The previous value of `childLayout.parentLayout` prior to being
   adopted by `layout`
   */
  func layout(_ layout: Layout,
    didAdoptChildLayout childLayout: Layout, fromOldParentLayout oldParentLayout: Layout?)

  /**
   Event that is called when a layout has removed a child layout.

   - parameter layout: The parent `Layout`.
   - parameter childLayout: The child `Layout`.
   */
  func layout(_ layout: Layout, didRemoveChildLayout childLayout: Layout)
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
@objcMembers open class Layout: NSObject {
  // MARK: - Static Properties

  /// Flag that should be used when the layout's entire display needs to be updated from the UI side
  open static let Flag_NeedsDisplay = LayoutFlag(highestOrderBitIndex: 0)

  /// Flag that should be used when `self.viewFrame` has been updated
  open static let Flag_UpdateViewFrame = LayoutFlag(highestOrderBitIndex: 1)

  // MARK: - Properties

  /// A unique identifier used to identify this layout for its lifetime
  public final let uuid: String

  /// The `LayoutEngine` used for layout related functions such as unit scaling and
  /// UI configuration.
  public final let engine: LayoutEngine

  /// Convenience property for accessing `self.engine.config`
  open var config: LayoutConfig {
    return engine.config
  }

  /// The parent node of this layout. If this value is nil, this layout is the root node.
  public fileprivate(set) final weak var parentLayout: Layout?

  /// Layouts whose `parentLayout` is set to this layout
  public fileprivate(set) final var childLayouts = Set<Layout>()

  /// Position relative to `self.parentLayout`
  internal final var relativePosition: WorkspacePoint = WorkspacePoint.zero
  /// Content size of this layout
  internal final var contentSize: WorkspaceSize = WorkspaceSize.zero {
    didSet {
      updateTotalSize()
    }
  }
  /// Inline edge insets for the layout.
  internal final var edgeInsets: WorkspaceEdgeInsets = WorkspaceEdgeInsets.zero {
    didSet {
      updateTotalSize()
    }
  }

  // TODO(#34): If ConnectionLayout is created, change absolutePosition to be final

  /// Absolute position of this layout, relative to the root node, in the Workspace coordinate
  /// system.
  internal var absolutePosition: WorkspacePoint = WorkspacePoint.zero
  /// Total size used by this layout. This value is calculated by combining `edgeInsets` and
  /// `contentSize`.
  internal fileprivate(set) final var totalSize: WorkspaceSize = WorkspaceSize.zero

  /// An offset that should be applied to the positions of `childLayouts`, specified in the
  /// Workspace coordinate system.
  internal final var childContentOffset: WorkspacePoint = WorkspacePoint.zero

  /**
  UIView frame for this layout relative to its parent *view* node's layout. For example, the parent
  view node layout for a Field is a Block, while the parent view node for a Block is a Workspace.
  */
  public internal(set) final var viewFrame: CGRect = CGRect.zero {
    didSet {
      if viewFrame != oldValue {
        sendChangeEvent(withFlags: Layout.Flag_UpdateViewFrame)
      }
    }
  }

  /// The delegate for events that occur on this instance
  public final weak var delegate: LayoutDelegate?

  /// A set of Layout hierarchy listeners on this instance
  public final var hierarchyListeners = WeakSet<LayoutHierarchyListener>()

  // MARK: - Initializers

  /**
   Initializes an empty Layout.

   - parameter engine: The `LayoutEngine` to associate with this layout.
   */
  public init(engine: LayoutEngine) {
    self.uuid = UUID().uuidString
    self.engine = engine
    super.init()
  }

  // MARK: - Abstract

  /**
  This method repositions its children and recalculates its `contentSize` based on the positions
  of its children.

  - parameter includeChildren: A flag indicating whether `performLayout(:)` should be called on any
  child layouts, prior to repositioning them. It is the responsibility of subclass implementations
  to honor this flag.
  - note: This method needs to be implemented by a subclass of `Layout`.
  */
  open func performLayout(includeChildren: Bool) {
    bky_assertionFailure("\(#function) needs to be implemented by a subclass")
  }

  // MARK: - Public

  /**
  For every `Layout` in its tree hierarchy (including itself), this method recalculates its
  `contentSize`, `relativePosition`, `absolutePosition`, and `viewFrame`, based on the current state
  of `self.parentLayout`.
  */
  open func updateLayoutDownTree() {
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
  Sends a layout change event to `self.delegate` with a given set of flags.

  - parameter flags: `LayoutFlag` options to send with the change event
  */
  public final func sendChangeEvent(withFlags flags: LayoutFlag) {
    // Send change event
    delegate?.layoutDidChange(self, withFlags: flags, animated: animateChangeEvent)
  }

  /**
   Returns an array of `Layout` instances for the tree headed by this `Layout` instance, in no
   particular order.

   - parameter type: [Optional] Filters `Layout` instances by a specific type.
   - returns: An array of all `Layout` instances.
   */
  public final func flattenedLayoutTree<T>(ofType type: T.Type? = nil) -> [T] where T: Layout {
    var allLayouts = [T]()
    var layoutsToProcess = [Layout]()

    layoutsToProcess.append(self)

    while !layoutsToProcess.isEmpty {
      let layout = layoutsToProcess.removeLast()

      if let typedLayout = layout as? T {
        allLayouts.append(typedLayout)
      }

      layoutsToProcess.append(contentsOf: layout.childLayouts)
    }

    return allLayouts
  }

  /**
   Returns whether this layout is a descendant of a given layout.

   - parameter layout: The layout to check.
   - returns: `true` if the given `layout` is a grandparent of this layout. `false` otherwise.
   */
  public final func isDescendant(of layout: Layout) -> Bool {
    var currentLayout = self
    while let parent = currentLayout.parentLayout {
      if parent == layout {
        return true
      }
      currentLayout = parent
    }
    return false
  }

  // MARK: - Internal

  /**
   Traverses up the layout tree and returns the first ancestor that is of a given type.

   - parameter type: The type of `Layout` to find.
   - returns: The first ancestor of the given `type`, or `nil` if none could be found.
   */
  internal final func firstAncestor<T>(ofType type: T.Type? = nil) -> T? where T: Layout {
    var parent = parentLayout

    while parent != nil {
      if let typedParent = parent as? T {
        return typedParent
      }
      parent = parent?.parentLayout
    }

    return nil
  }

  /**
   For a given `Layout`, adds it to `self.childLayouts` and sets its `parentLayout` property to
   this instance.

   If the given `Layout` had an existing parent, this method automatically removes it from that
   parent's `childLayouts`. This ensures that child `Layout` objects do not belong to two different
   `Layout` parents. The `relativePosition` of `layout` is also recalculated relative to its new
   parent (based on where it was before) and `layout.refreshViewPositionsForTree()` is executed.

   - parameter layout: The child `Layout` to adopt
   */
  internal func adoptChildLayout(_ layout: Layout) {
    if layout.parentLayout == self {
      return
    }

    // Keep track of old parent
    let oldParentLayout = layout.parentLayout

    // Add this child layout and set its parent
    childLayouts.insert(layout)
    layout.parentLayout = self

    // Remove the child layout from its old parent (if necessary)
    if let previousParentLayout = oldParentLayout {
      previousParentLayout.childLayouts.remove(layout)
      // Update the layout's relative position to where it is in its new layout tree
      layout.relativePosition = layout.absolutePosition - absolutePosition
      // With its new relative position, refresh the view positions for this part of the tree
      layout.refreshViewPositionsForTree()
    }

    // Fire hierachy listeners
    hierarchyListeners.forEach {
      $0.layout(self, didAdoptChildLayout: layout, fromOldParentLayout: oldParentLayout)
    }
  }

  /**
   For a given `Layout`, removes it from `self.childLayouts` and sets its `parentLayout` property to
   `nil`.

   - parameter layout: The child `Layout` to remove
   */
  internal func removeChildLayout(_ layout: Layout) {
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
  For every `Layout` in its tree hierarchy (including itself), updates `self.absolutePosition`
  and `self.viewFrame` based on the current state of this object.

  - parameter includeFields: If true, recursively update view frames for field layouts. If false,
  skip them.
  */
  internal final func refreshViewPositionsForTree(includeFields: Bool = true) {
    refreshViewPositionsForTree(
      parentAbsolutePosition: (parentLayout?.absolutePosition ?? WorkspacePoint.zero),
      parentContentSize: (parentLayout?.contentSize ?? self.contentSize),
      contentOffset: (parentLayout?.childContentOffset ?? WorkspacePoint.zero),
      rtl: self.engine.rtl,
      includeFields: includeFields)
  }

  // MARK: - Private

  /**
  For every `Layout` in its tree hierarchy (including itself), updates `self.absolutePosition`
  and `self.viewFrame` based on the current state of this object.

  - parameter parentAbsolutePosition: The absolute position of its parent layout (specified as a
  Workspace coordinate system point)
  - parameter parentContentSize: The content size of its parent layout (specified as a Workspace
  coordinate system size)
  - parameter contentOffset: An offset that should be applied to this view frame (specified as a
  Workspace coordinate system point)
  - parameter rtl: Flag for if the layout should be positioned in RTL mode.
  - parameter includeFields: If true, recursively update view positions for field layouts. If false,
  skip them.
  - note: All parent parameters are defined in the method signature so we can eliminate direct
  references to `self.parentLayout` inside this method. This results in better performance.
  */
  @inline(__always)
  fileprivate final func refreshViewPositionsForTree(
    parentAbsolutePosition: WorkspacePoint,
    parentContentSize: WorkspaceSize,
    contentOffset: WorkspacePoint,
    rtl: Bool, includeFields: Bool)
  {
    // TODO(#29): Optimize this method so it only recalculates view positions for layouts that
    // are "dirty"

    // Update the layout's absolute position in the workspace
    self.absolutePosition = WorkspacePoint(
      x: parentAbsolutePosition.x + relativePosition.x + edgeInsets.leading,
      y: parentAbsolutePosition.y + relativePosition.y + edgeInsets.top)

    // Update the view frame, if needed
    if (includeFields || !(self is FieldLayout))
    {
      // Calculate the view frame's position
      var viewFrameOrigin = CGPoint.zero
      if rtl {
        // In RTL, the x position is calculated relative to the top-right corner of its parent
        viewFrameOrigin.x = self.engine.viewUnitFromWorkspaceUnit(
          parentContentSize.width -
          (relativePosition.x + edgeInsets.leading + contentSize.width + contentOffset.x))
      } else {
        viewFrameOrigin.x = self.engine.viewUnitFromWorkspaceUnit(
          relativePosition.x + edgeInsets.leading + contentOffset.x)
      }
      viewFrameOrigin.y = self.engine.viewUnitFromWorkspaceUnit(
        relativePosition.y + edgeInsets.top + contentOffset.y)

      let viewSize = self.engine.viewSizeFromWorkspaceSize(self.contentSize)
      self.viewFrame =
        CGRect(x: viewFrameOrigin.x, y: viewFrameOrigin.y,
               width: viewSize.width, height: viewSize.height)
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
  fileprivate func updateTotalSize() {
    totalSize.width = contentSize.width + edgeInsets.leading + edgeInsets.trailing
    totalSize.height = contentSize.height + edgeInsets.top + edgeInsets.bottom
  }
}

// MARK: - Layout Animation

extension Layout {
  // TODO(#173): Once the model/layout has been refactored so layout hierarchy changes aren't made
  // automatically on connection changes, revisit whether an animation stack is needed.

  /// Stack that keeps track of whether future layout code changes should be animated.
  fileprivate static var _animationStack = [Bool]()

  /**
   Executes a given code block, where layout changes made inside this code block are animated.

   - note: If there is an inner call to `Layout.doNotAnimate(:)` inside the given code block,
   that call will not animate its layout changes.
   - parameter code: The code block to execute, with layout animations enabled.
   */
  public static func animate(code: () throws -> Void) rethrows {
    _animationStack.append(true)
    try code()
    _animationStack.removeLast()
  }

  /**
   Executes a given code block, where layout changes made inside this code block are not animated.

   - note: If there is an inner call to `Layout.animate(:)` inside the given code block, that
   call will animate its layout changes.
   - parameter code: The code block to execute, with layout animations disabled.
   */
  public static func doNotAnimate(code: () throws -> Void) rethrows {
    _animationStack.append(false)
    try code()
    _animationStack.removeLast()
  }

  /**
   Property indicating whether the next change event that is sent out via `sendChangeEvent(:)`
   should be animated or not.
   */
  public var animateChangeEvent: Bool {
    // Take the most recent value of what's on the animation stack to determine if the next change
    // should be animated. If nothing is on the stack, do not animate by default.
    // TODO(#169): Animations don't work in RTL yet, so they've been disabled.
    return !engine.rtl && Layout._animationStack.last ?? false
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
public struct LayoutFlag: OptionSet {
  // MARK: - Static Properties
  public static let None = LayoutFlag(rawValue: 0)
  public static let All = LayoutFlag(rawValue: UInt64.max)
  fileprivate static let MaximumNumberOfCustomFlags: UInt64 = 50

  // MARK: - Properties
  public let rawValue: UInt64

  // MARK: - Initializers

  /**
  Initializer for the `Layout` class looking to define a common layout flag.

  - parameter highestOrderBitIndex: The bit index to use when defining this layout flag, starting
  from the highest order bit.
  - note: An assertion is made in this method that `highestOrderBitIndex < 14`.
  */
  fileprivate init(highestOrderBitIndex: UInt64) {
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

   - parameter lowestOrderBitIndex: The bit index to use when defining this layout flag, starting
   from the lowest order bit.
   - note: An assertion is made in this method that `lowestOrderBitIndex < 50`.
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

  - returns: The equivalent of `self != LayoutFlag.None`.
  */
  public func hasFlagSet() -> Bool {
    return self != LayoutFlag.None
  }

  /**
  - returns: True if `self` shares at least one common flag with `other`.
  */
  public func intersectsWith(_ other: LayoutFlag) -> Bool {
    return intersection(other).hasFlagSet()
  }
}
