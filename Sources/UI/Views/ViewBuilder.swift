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

   - parameter viewBuilder: The `ViewBuilder`
   - parameter childView: The child `UIView`
   - parameter parentView: The parent `UIView`
   */
  func viewBuilder(
    _ viewBuilder: ViewBuilder, didAddChild childView: UIView, toParent parentView: UIView)

  /**
   Event that is called when the `ViewBuilder` has removed a child view from a parent view.

   - parameter viewBuilder: The `ViewBuilder`
   - parameter childView: The child `UIView`
   - parameter parentView: The parent `UIView`
   */
  func viewBuilder(
    _ viewBuilder: ViewBuilder, didRemoveChild childView: UIView, fromParent parentView: UIView)
}

// MARK: - ViewBuilder Class

/**
 Class for maintaining the `View` hierarchy from a `Layout` hierarchy.
 */
@objcMembers @objc(BKYViewBuilder)
open class ViewBuilder: NSObject {
  // MARK: - Properties

  /// Factory responsible for creating new `View` instances
  public let viewFactory: ViewFactory

  /// Delegate for events that occur on this `ViewBuilder`
  public weak var delegate: ViewBuilderDelegate?

  // MARK: - Initializer

  /**
   Initializer for the view builder.

   - parameter viewFactory: The `ViewFactory` to construct views built by the builder.
   */
  public init(viewFactory: ViewFactory) {
    self.viewFactory = viewFactory
  }

  // MARK: - Public

  /**
   Builds the entire view tree for `workspaceView` based on its current layout
   (ie. `workspaceView.workspaceLayout`).

   - throws:
   `BlocklyError`: Thrown if the view tree could not be created for this workspace.
   */
  open func buildViewTree(forWorkspaceView workspaceView: WorkspaceView) throws {
    guard let workspaceLayout = workspaceView.workspaceLayout else {
      return
    }

    workspaceLayout.hierarchyListeners.add(self)

    for blockGroupView in workspaceView.blockGroupViews {
      removeChild(blockGroupView, fromParent: workspaceView)
    }

    // Create layouts for every top-level block in the workspace
    for blockGroupLayout in workspaceLayout.blockGroupLayouts {
      addViewTree(forLayout: blockGroupLayout, toParent: workspaceView)
    }
  }

  // MARK: - Private

  /**
   Builds the view tree for a given layout tree and adds it as a child to a given parent view.

   For any layout in the tree where a view is created, this `ViewBuilder` assigns itself to the
   layout's set of hierarchy listeners (so it can modify the view tree on any layout changes).

   For any layout node where an associated view could not be created, its entire branch is skipped
   and no listener is attached to any part of that branch.

   - parameter layout: The root of the `Layout` tree
   - parameter parentView: The parent view on which to add the newly created view tree.
   */
  fileprivate func addViewTree(forLayout layout: Layout, toParent parentView: UIView) {
    let view: LayoutView

    do {
      // Create a new one from the factory
      view = try viewFactory.makeView(layout: layout)
    } catch {
      // Couldn't retrieve a view for this layout, just return nil (not all layouts need to have a
      // view)
      return
    }

    view.layout = layout

    // Add child to parent
    addChild(view, toParent: parentView)

    // Listen for any changes to this layout since it has an associated view with it (so we can
    // update the view hierarchy to reflect layout hierarchy changes).
    layout.hierarchyListeners.add(self)

    // Build the child Layout view tree
    for childLayout in layout.childLayouts {
      addViewTree(forLayout: childLayout, toParent: view)
    }
  }

  fileprivate func addChild(_ childView: UIView, toParent parentView: UIView) {
    if let workspaceView = parentView as? WorkspaceView,
      let blockGroupView = childView as? BlockGroupView
    {
      workspaceView.addBlockGroupView(blockGroupView)
    } else {
      parentView.addSubview(childView)
    }
    delegate?.viewBuilder(self, didAddChild: childView, toParent: parentView)
  }

  fileprivate func removeChild(_ childView: UIView, fromParent parentView: UIView) {
    if let workspaceView = parentView as? WorkspaceView,
      let blockGroupView = childView as? BlockGroupView
    {
      workspaceView.removeBlockGroupView(blockGroupView)
      delegate?.viewBuilder(self, didRemoveChild: childView, fromParent: parentView)

      // Recycle the view tree after calling the delegate method. This allows the delegate method
      // to perform any necessary clean-up prior to deconstructing the view tree.
      viewFactory.recycleViewTree(blockGroupView)
    } else if childView.superview == parentView {
      childView.removeFromSuperview()
      delegate?.viewBuilder(self, didRemoveChild: childView, fromParent: parentView)

      // Recycle the view tree after calling the delegate method. This allows the delegate method
      // to perform any necessary clean-up prior to deconstructing the view tree.
      viewFactory.recycleViewTree(childView)
    }
  }
}

extension ViewBuilder: LayoutHierarchyListener {
  public func layout(_ layout: Layout,
    didAdoptChildLayout childLayout: Layout, fromOldParentLayout oldParentLayout: Layout?)
  {
    guard let parentView = ViewManager.shared.findView(forLayout: layout) else {
      return
    }

    if let childView = ViewManager.shared.findView(forLayout: childLayout) {
      // The child view already exists. Simply transfer the child view over to the new parent view.
      parentView.addSubview(childView)
      return
    } else {
      // Build a fresh view tree for the new child layout and add it to the parent.
      addViewTree(forLayout: childLayout, toParent: parentView)
    }
  }

  public func layout(_ layout: Layout, didRemoveChildLayout childLayout: Layout) {
    guard
      let parentView = ViewManager.shared.findView(forLayout: layout),
      let childView = ViewManager.shared.findView(forLayout: childLayout) else
    {
      return
    }

    removeChild(childView, fromParent: parentView)

    // Remove self from list of the child's layout hierarchy listeners
    childLayout.hierarchyListeners.remove(self)
  }
}
