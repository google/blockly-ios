/*
 * Copyright 2016 Google Inc. All Rights Reserved.
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

// MARK: - ViewBuilderDelegate Protocol

/**
 Delegate for events that occur inside a `ViewBuilder`.
 */
@objc(BKYViewBuilderDelegate)
public protocol ViewBuilderDelegate {
  /**
   Event that is called when the `ViewBuilder` has added child view to a parent view.

   - Parameter viewBuilder: The `ViewBuilder`
   - Parameter childView: The child `UIView`
   - Parameter parentView: The parent `UIView`
   */
  func viewBuilder(
    viewBuilder: ViewBuilder, didAddChild childView: UIView, toParent parentView: UIView)

  /**
   Event that is called when the `ViewBuilder` has removed a child view from a parent view.

   - Parameter viewBuilder: The `ViewBuilder`
   - Parameter childView: The child `UIView`
   - Parameter parentView: The parent `UIView`
   */
  func viewBuilder(
    viewBuilder: ViewBuilder, didRemoveChild childView: UIView, fromParent parentView: UIView)
}

// MARK: - ViewBuilder Class

/**
 Class for maintaining the `View` hierarchy from a `Layout` hierarchy.
 */
@objc(BKYViewBuilder)
public class ViewBuilder: NSObject {
  // MARK: - Properties

  /// Factory responsible for creating new `View` instances
  public let viewFactory: ViewFactory

  /// Delegate for events that occur on this `ViewBuilder`
  public weak var delegate: ViewBuilderDelegate?

  // MARK: - Initializer

  public init(viewFactory: ViewFactory) {
    self.viewFactory = viewFactory
  }

  // MARK: - Public

  /**
   Builds the entire view tree for `workspaceView` based on its current layout
   (ie. `workspaceView.workspaceLayout`).

   - Throws:
   `BlocklyError`: Thrown if the view tree could not be created for this workspace.
   */
  public func buildViewTree(forWorkspaceView workspaceView: WorkspaceView) throws {
    guard let workspaceLayout = workspaceView.workspaceLayout else {
      return
    }

    workspaceLayout.hierarchyListeners.add(self)

    for blockGroupView in workspaceView.blockGroupViews {
      removeChild(blockGroupView, fromParent: workspaceView)
    }

    // Create layouts for every top-level block in the workspace
    for blockGroupLayout in workspaceLayout.blockGroupLayouts {
      if let blockGroupView = buildViewTree(forLayout: blockGroupLayout) {
        addChild(blockGroupView, toParent: workspaceView)
      }
    }
  }

  // MARK: - Private

  /**
   Builds the view tree for a given layout tree. For any layout in the tree where a view is created,
   this `ViewBuilder` assigns itself to the layout's set of hierarchy listeners (so it can modify
   the view tree on any layout changes).

   - Parameter layout: The root of the `Layout` tree
   - Returns: An associated `LayoutView` for `layout`. If `layout` is not a type of `Layout` that
   is supposed to be represented by a `LayoutView`, `nil` is returned instead.
   */
  private func buildViewTree(forLayout layout: Layout) -> LayoutView? {
    let view: LayoutView

    do {
      // Look for an existing version of the layout or create a new one from the factory
      view = try viewFactory.viewForLayout(layout)
    } catch {
      // Couldn't retrieve a view for this layout, just return nil (not all layouts need to have a
      // view)
      return nil
    }

    view.layout = layout

    // Listen for any changes to this layout since it has an associated view with it (so we can
    // update the view hierarchy to reflect layout hierarchy changes).
    layout.hierarchyListeners.add(self)

    // Remove all existing subviews if they are `LayoutView` instances
    for subview in view.subviews {
      if subview is LayoutView {
        removeChild(subview, fromParent: view)
      }
    }

    // Build the child Layout view tree
    for childLayout in layout.childLayouts {
      if let childView = buildViewTree(forLayout: childLayout) {
        addChild(childView, toParent: view)
      }
    }

    return view
  }

  private func addChild(childView: UIView, toParent parentView: UIView) {
    if let workspaceView = parentView as? WorkspaceView,
      let blockGroupView = childView as? BlockGroupView
    {
      workspaceView.addBlockGroupView(blockGroupView)
    } else {
      parentView.addSubview(childView)
    }
    delegate?.viewBuilder(self, didAddChild: childView, toParent: parentView)
  }

  private func removeChild(childView: UIView, fromParent parentView: UIView) {
    if let workspaceView = parentView as? WorkspaceView,
      let blockGroupView = childView as? BlockGroupView
    {
      workspaceView.removeBlockGroupView(blockGroupView)
      viewFactory.recycleViewTree(blockGroupView)
      delegate?.viewBuilder(self, didRemoveChild: childView, fromParent: parentView)
    } else if childView.superview == parentView {
      childView.removeFromSuperview()
      viewFactory.recycleViewTree(childView)
      delegate?.viewBuilder(self, didRemoveChild: childView, fromParent: parentView)
    }
  }
}

extension ViewBuilder: LayoutHierarchyListener {
  public func layout(layout: Layout,
    didAdoptChildLayout childLayout: Layout, fromOldParentLayout oldParentLayout: Layout?)
  {
    guard let parentView = ViewManager.sharedInstance.findViewForLayout(layout) else {
      return
    }

    if let childView = ViewManager.sharedInstance.findViewForLayout(childLayout) {
      // The child view already exists. Simply transfer the child view over to the new parent view.
      parentView.addSubview(childView)
      return
    } else if let childView = buildViewTree(forLayout: childLayout) {
      // Build a fresh view tree for the new child layout and add it to the parent.
      addChild(childView, toParent: parentView)
    }
  }

  public func layout(layout: Layout, didRemoveChildLayout childLayout: Layout) {
    guard
      let parentView = ViewManager.sharedInstance.findViewForLayout(layout),
      let childView = ViewManager.sharedInstance.findViewForLayout(childLayout) else
    {
      return
    }

    removeChild(childView, fromParent: parentView)

    // Remove self from list of the child's layout hierarchy listeners
    childLayout.hierarchyListeners.remove(self)
  }
}
