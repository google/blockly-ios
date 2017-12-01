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

import UIKit

// TODO(#120): This delegate only exists right now so `WorkbenchViewController` can attach
// gesture recognizers on the BlockView. Refactor this so the gesture recognizers are managed
// in this view controller and then this delegate can be deleted.

/**
 Protocol for events that occur on a `WorkspaceViewController` instance.
 */
@objc(BKYWorkspaceViewControllerDelegate)
public protocol WorkspaceViewControllerDelegate {
  /**
   Called when a new `BlockView` is added to a `WorkspaceViewController`.

   - parameter workspaceViewController: The `WorkspaceViewController` where the block was added.
   - parameter blockView: The `BlockView` that was added to the workspace.
   */
  func workspaceViewController(
    _ workspaceViewController: WorkspaceViewController, didAddBlockView blockView: BlockView)

  /**
   Called when a new `BlockView` is removed from a `WorkspaceViewController`.

   - parameter workspaceViewController: The `WorkspaceViewController` where the block was removed.
   - parameter blockView: The `BlockView` that was removed from the workspace.
   */
  func workspaceViewController(
    _ workspaceViewController: WorkspaceViewController, didRemoveBlockView blockView: BlockView)

  // TODO(#135): The following two methods only exist right now so that the state can be updated in
  // `WorkbenchViewController`. This seems like a temporary solution -- a better solution would be
  // that `WorkspaceViewController` manages state and there are ways that `WorkbenchViewController`
  // can change state behaviour. Once state handling has been refactored, these two methods can be
  // deleted.

  /**
   Called when the `WorkspaceViewController` is about to present a view controller.

   - parameter workspaceViewController: The `WorkspaceViewController` presenting a view controller.
   - parameter viewController: The `UIViewController` about to be presented.
   */
  func workspaceViewController(
    _ workspaceViewController: WorkspaceViewController,
    willPresentViewController viewController: UIViewController)

  /**
   Called when the `WorkspaceViewController` has dismissed a presented view controller.

   - parameter workspaceViewController: The `WorkspaceViewController` that dismissed a view
   controller.
   */
  func workspaceViewControllerDismissedViewController(
    _ workspaceViewController: WorkspaceViewController)
}

/**
 View controller for managing a workspace.
 */
@objc(BKYWorkspaceViewController)
@objcMembers open class WorkspaceViewController: UIViewController {

  /// The workspace layout coordinator this view controller operates on
  open fileprivate(set) var workspaceLayoutCoordinator: WorkspaceLayoutCoordinator?

  /// A convenience property for accessing `self.workspaceLayoutCoordinator?.workspaceLayout`
  open var workspaceLayout: WorkspaceLayout? {
    return workspaceLayoutCoordinator?.workspaceLayout
  }

  /// A convenience property for `self.workspaceLayout.workspace`
  open var workspace: Workspace? {
    return workspaceLayout?.workspace
  }

  /// The target workspace view
  open lazy var workspaceView: WorkspaceView = {
    let workspaceView = WorkspaceView()
    workspaceView.backgroundColor = UIColor.clear
    return workspaceView
  }()

  /// Delegate for events that occur on this view controller
  open weak var delegate: WorkspaceViewControllerDelegate?

  /// Additional presentation delegate that should be notified when a view controller is being
  /// presented by this instance. This allows both this instance and the source that requested
  /// the view controller presentation to be notified on presentation events.
  fileprivate weak var presentationDelegate: UIPopoverPresentationControllerDelegate?

  /// The view builder used for managing the view hierarchy
  fileprivate let _viewBuilder: ViewBuilder

  // MARK: - Initializers

  /**
   Initializer.

   - parameter viewFactory: The `ViewFactory` that should be used when creating the
   view hierarchy for a workspace.
   */
  public init(viewFactory: ViewFactory) {
    _viewBuilder = ViewBuilder(viewFactory: viewFactory)
    super.init(nibName: nil, bundle: nil)

    _viewBuilder.delegate = self
  }

  /**
   :nodoc:
   - Warning: This is currently unsupported.
   */
  public required init?(coder aDecoder: NSCoder) {
    fatalError("Called unsupported initializer")
  }

  // MARK: - Super

  open override func loadView() {
    view = workspaceView
  }

  open override func present(
    _ viewControllerToPresent: UIViewController,
    animated flag: Bool,
    completion: (() -> Void)? = nil) {

    delegate?.workspaceViewController(self, willPresentViewController: viewControllerToPresent)

    super.present(viewControllerToPresent, animated: flag, completion: completion)
  }

  // MARK: - Public

  /**
   Loads the workspace associated with a workspace layout coordinator, automatically creating all
   views required to render the workspace.

   - parameter workspaceLayoutCoordinator: A `WorkspaceLayoutCoordinator`.
   */
  open func loadWorkspaceLayoutCoordinator(
    _ workspaceLayoutCoordinator: WorkspaceLayoutCoordinator?) throws
  {
    self.workspaceLayoutCoordinator = workspaceLayoutCoordinator

    let workspaceLayout = workspaceLayoutCoordinator?.workspaceLayout
    workspaceView.layout = workspaceLayout
    workspaceLayout?.updateLayoutDownTree()
    try _viewBuilder.buildViewTree(forWorkspaceView: workspaceView)
    workspaceView.refreshView()
  }
}

// MARK: - ViewBuilderDelegate implementation

extension WorkspaceViewController: ViewBuilderDelegate {
  public func viewBuilder(
    _ viewBuilder: ViewBuilder, didAddChild childView: UIView, toParent parentView: UIView)
  {
    // TODO(#120): This delegate only exists right now so `WorkbenchViewController` can attach
    // gesture recognizers on the BlockView. Refactor this so the gesture recognizers are managed
    // in this view controller.
    if let blockView = childView as? BlockView {
      delegate?.workspaceViewController(self, didAddBlockView: blockView)
    }

    if let layoutView = childView as? LayoutView {
      // Assign this view controller as the layout view's delegate (to handle pop up controller
      // events)
      layoutView.popoverDelegate = self
    }
  }

  public func viewBuilder(
    _ viewBuilder: ViewBuilder, didRemoveChild childView: UIView, fromParent parentView: UIView)
  {
    // TODO(#120): This delegate only exists right now so `WorkbenchViewController` can attach
    // gesture recognizers on the BlockView. Refactor this so the gesture recognizers are managed
    // in this view controller.
    var removedViews = [childView]
    while let removedView = removedViews.popLast() {
      removedViews.append(contentsOf: removedView.subviews)

      if let blockView = removedView as? BlockView {
        delegate?.workspaceViewController(self, didRemoveBlockView: blockView)
      }

      if let layoutView = removedView as? LayoutView, layoutView.popoverDelegate === self {
        // Unassign this view controller as the layout view's delegate
        layoutView.popoverDelegate = nil
      }
    }
  }
}

// MARK: - LayoutPopoverDelegate implementation

extension WorkspaceViewController: LayoutPopoverDelegate {
  public func layoutView(
    _ layoutView: LayoutView,
    requestedToPresentPopoverViewController viewController: UIViewController,
    fromView: UIView,
    presentationDelegate: UIPopoverPresentationControllerDelegate?)
    -> Bool
  {
    guard !workspaceView.scrollView.isInMotion &&
      !(self.presentedViewController?.isBeingPresented ?? false) else
    {
      // Don't present anything if the scroll view is in motion or if another view controller is
      // being presented
      return false
    }

    if let presentedViewController = self.presentedViewController,
      !presentedViewController.isBeingDismissed {
      // Dismiss any other view controller that's being presented
      presentedViewController.dismiss(animated: true, completion: nil)
    }

    viewController.modalPresentationStyle = .popover
    viewController.popoverPresentationController?.sourceView = self.view
    viewController.popoverPresentationController?.sourceRect =
      self.view.convert(fromView.frame, from: fromView.superview)
    viewController.popoverPresentationController?.delegate = self

    self.presentationDelegate = presentationDelegate

    present(viewController, animated: true, completion: nil)

    return true
  }

  public func layoutView(
    _ layoutView: LayoutView, requestedToPresentViewController viewController: UIViewController)
  {
    self.presentationDelegate = nil

    present(viewController, animated: true, completion: nil)
  }

  public func layoutView(
    _ layoutView: LayoutView,
    requestedToDismissPopoverViewController viewController: UIViewController,
    animated: Bool) {
    if !viewController.isBeingDismissed {
      viewController.dismiss(animated: animated, completion: nil)
    }

    presentationDelegate = nil

    // Manually fire our custom delegate since it doesn't automatically get triggered from
    // `self.popoverPresentationControllerDidDismissPopover(:)`.
    delegate?.workspaceViewControllerDismissedViewController(self)
  }
}

// MARK: - UIPopoverPresentationControllerDelegate Implementation

extension WorkspaceViewController: UIPopoverPresentationControllerDelegate {
  @available(iOS 8.3, *)
  public func adaptivePresentationStyle(for controller: UIPresentationController,
    traitCollection: UITraitCollection) -> UIModalPresentationStyle
  {
    // Force this view controller to always show up in a popover
    return
      presentationDelegate?.adaptivePresentationStyle?(
        for:controller, traitCollection:traitCollection)
      ?? UIModalPresentationStyle.none
  }

  public func adaptivePresentationStyle(for controller: UIPresentationController)
    -> UIModalPresentationStyle {
    return presentationDelegate?.adaptivePresentationStyle?(for: controller)
      ?? UIModalPresentationStyle.none
  }

  public func presentationController(
    _ controller: UIPresentationController,
    viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle)
    -> UIViewController? {
      return presentationDelegate?
        .presentationController?(controller, viewControllerForAdaptivePresentationStyle: style)
  }

  @available(iOS 8.3, *)
  public func presentationController(
    _ presentationController: UIPresentationController,
    willPresentWithAdaptiveStyle style: UIModalPresentationStyle,
    transitionCoordinator: UIViewControllerTransitionCoordinator?) {
    presentationDelegate?.presentationController?(presentationController,
                                                  willPresentWithAdaptiveStyle: style,
                                                  transitionCoordinator: transitionCoordinator)
  }

  public func prepareForPopoverPresentation(_ popoverPresentationController:
    UIPopoverPresentationController) {
    presentationDelegate?.prepareForPopoverPresentation?(popoverPresentationController)
  }

  public func popoverPresentationControllerShouldDismissPopover(
    _ popoverPresentationController: UIPopoverPresentationController) -> Bool {
    return
      presentationDelegate?
        .popoverPresentationControllerShouldDismissPopover?(popoverPresentationController)
      ?? true
  }

  public func popoverPresentationControllerDidDismissPopover(
    _ popoverPresentationController: UIPopoverPresentationController)
  {
    presentationDelegate?
      .popoverPresentationControllerDidDismissPopover?(popoverPresentationController)

    presentationDelegate = nil
    delegate?.workspaceViewControllerDismissedViewController(self)
  }

  public func popoverPresentationController(
    _ popoverPresentationController: UIPopoverPresentationController,
    willRepositionPopoverTo rect: UnsafeMutablePointer<CGRect>,
    in view: AutoreleasingUnsafeMutablePointer<UIView>) {
    presentationDelegate?.popoverPresentationController?(
      popoverPresentationController, willRepositionPopoverTo: rect, in: view)
  }

  open override func dismiss(animated flag: Bool, completion: (() -> Void)?) {
    super.dismiss(animated: flag, completion: completion)

    presentationDelegate = nil
    delegate?.workspaceViewControllerDismissedViewController(self)
  }
}
