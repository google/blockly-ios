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
      let blockGroupView = try buildBlockGroupViewTree(forBlockGroupLayout: blockGroupLayout)
      addChild(blockGroupView, toParent: workspaceView)
    }
  }

  /**
   Given a `BlockGroupLayout` instance, assigns this `ViewBuilder` as a hierarchy listener on it and
   builds its `BlockGroupView` tree view hierarchy.

   - Parameter blockGroupLayout: The `BlockGroupLayout`
   - Returns: A `BlockGroupView` representing the entire `BlockGroupLayout` tree
   - Throws:
   `BlocklyError`: Thrown if the view hierarchy could not be built.
   */
  private func buildBlockGroupViewTree(forBlockGroupLayout blockGroupLayout: BlockGroupLayout)
    throws -> BlockGroupView
  {
    blockGroupLayout.hierarchyListeners.add(self)

    let blockGroupView = try
      (ViewManager.sharedInstance.findViewForLayout(blockGroupLayout) as? BlockGroupView) ??
      viewFactory.viewForBlockGroupLayout(blockGroupLayout)
    blockGroupView.layout = blockGroupLayout

    // TODO:(vicng) FIX THIS
    for subview in blockGroupView.subviews {
      removeChild(subview, fromParent: blockGroupView)
    }

    // Create block views
    for blockLayout in blockGroupLayout.blockLayouts {
      let blockView = try buildBlockViewTree(forBlockLayout: blockLayout)
      addChild(blockView, toParent: blockGroupView)
    }

    return blockGroupView
  }

  /**
   Given a `BlockLayout` instance, assigns this `ViewBuilder` as a hierarchy listener on it and
   builds its `BlockView` tree view hierarchy.

   - Parameter blockLayout: The `BlockLayout`
   - Returns: A `BlockView` representing the entire `BlockLayout` tree
   - Throws:
   `BlocklyError`: Thrown if the view hierarchy could not be built.
   */
  private func buildBlockViewTree(forBlockLayout blockLayout: BlockLayout) throws -> BlockView
  {
    blockLayout.hierarchyListeners.add(self)

    let blockView = try
      (ViewManager.sharedInstance.findViewForLayout(blockLayout) as? BlockView) ??
      viewFactory.blockViewForLayout(blockLayout)
    blockView.layout = blockLayout

    for subview in blockView.subviews {
      removeChild(subview, fromParent: blockView)
    }

    // Build the input views for this block
    for inputLayout in blockLayout.inputLayouts {
      let inputView = try buildInputViewTree(forInputLayout: inputLayout)
      addChild(inputView, toParent: blockView)
    }

    return blockView
  }

  /**
   Given an `InputLayout` instance, assigns this `ViewBuilder` as a hierarchy listener on it and
   builds its `InputView` tree view hierarchy.

   - Parameter inputLayout: The `InputLayout`
   - Returns: A `InputView` representing the entire `InputLayout` tree
   - Throws:
   `BlocklyError`: Thrown if the view hierarchy could not be built.
   */
  private func buildInputViewTree(forInputLayout inputLayout: InputLayout) throws -> InputView {
    inputLayout.hierarchyListeners.add(self)

    let inputView = try
      (ViewManager.sharedInstance.findViewForLayout(inputLayout) as? InputView) ??
      viewFactory.viewForInputLayout(inputLayout)
    inputView.layout = inputLayout

    for subview in inputView.subviews {
      removeChild(subview, fromParent: inputView)
    }

    // Build field layouts for this input
    for fieldLayout in inputLayout.fieldLayouts {
      let fieldView = try buildFieldViewTree(forFieldLayout: fieldLayout)
      addChild(fieldView, toParent: inputView)
    }

    let blockGroupView =
      try buildBlockGroupViewTree(forBlockGroupLayout: inputLayout.blockGroupLayout)
    addChild(blockGroupView, toParent: inputView)

    return inputView
  }

  /**
   Given a `FieldLayout` instance, assigns this `ViewBuilder` as a hierarchy listener on it and
   builds its `FieldView`.

   - Parameter fieldLayout: The `FieldLayout`
   - Returns: A `FieldView` representing the `FieldLayout`
   - Throws:
   `BlocklyError`: Thrown if the view could not be built.
   */
  private func buildFieldViewTree(forFieldLayout fieldLayout: FieldLayout) throws -> FieldView {
    fieldLayout.hierarchyListeners.add(self)

    let fieldView = try
      (ViewManager.sharedInstance.findViewForLayout(fieldLayout) as? FieldView) ??
      viewFactory.fieldViewForLayout(fieldLayout)
    fieldView.layout = fieldLayout
    return fieldView
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
      ViewFactory.sharedInstance.recycleView(childView)
      delegate?.viewBuilder(self, didRemoveChild: childView, fromParent: parentView)
    } else if childView.superview == parentView {
      childView.removeFromSuperview()
      ViewFactory.sharedInstance.recycleView(childView)
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

    if oldParentLayout != nil {
      // The child view should already exist, since it was previously attached to another parent
      // layout. If it exists, simply transfer the child view over to the new parent view.
      if let childView = ViewManager.sharedInstance.findViewForLayout(childLayout) {
        parentView.addSubview(childView)
        return
      }
    }

    do {
      var view: UIView?

      if let blockGroupLayout = childLayout as? BlockGroupLayout
        where layout is WorkspaceLayout
      {
        view = try buildBlockGroupViewTree(forBlockGroupLayout: blockGroupLayout)
      } else if let blockLayout = childLayout as? BlockLayout
        where layout is BlockGroupLayout
      {
        view = try buildBlockViewTree(forBlockLayout: blockLayout)
      } else if let inputLayout = childLayout as? InputLayout
        where layout is BlockLayout
      {
        view = try buildInputViewTree(forInputLayout: inputLayout)
      } else if let fieldLayout = childLayout as? FieldLayout
        where layout is InputLayout
      {
        view = try buildFieldViewTree(forFieldLayout: fieldLayout)
      }

      if let childView = view {
        addChild(childView, toParent: parentView)
      }
    } catch let error as NSError {
      bky_assertionFailure("Could not create view tree: \(error)")
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
  }
}