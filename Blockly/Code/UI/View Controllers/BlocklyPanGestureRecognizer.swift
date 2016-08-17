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
import UIKit.UIGestureRecognizerSubclass

import UIKit

public class BlocklyPanGestureRecognizer: UIPanGestureRecognizer {
  // MARK: - Properties

  private var _workbench: WorkbenchViewController
  private var _blocks: [BlockView]
  private var _touches: [UITouch]

  public var inToolbox: Bool = false
  public var inTrash: Bool = false

  // MARK: - Initializer

  init(target: AnyObject?, action: Selector, workbench: WorkbenchViewController)
  {
    _workbench = workbench
    _blocks = [BlockView]()
    _touches = [UITouch]()
    super.init(target: target, action: action)
    delaysTouchesBegan = false
  }

  /**
   Utility function for finding the first ancestor that is a BlockView.

   - Parameter view: The view to find an ancestor of
   - Return: The first ancestor of the UIView that is a BlockView
   */
  private func owningBlockView(view:UIView?) -> BlockView? {
    var currentView = view
    while !(currentView is BlockView) {
      currentView = currentView?.superview
      if currentView == nil {
        return nil
      }

      if currentView == _workbench.workspaceViewController {
        return nil
      }
    }

    return currentView as? BlockView
  }

  // MARK: - Super

  public override func shouldBeRequiredToFailByGestureRecognizer(
    otherGestureRecognizer: UIGestureRecognizer) -> Bool
  {
    let scrollView = _workbench.workspaceViewController.workspaceView.scrollView

    // Force the scrollView pan and zoom gestures to fail unless this one fails
    if otherGestureRecognizer == scrollView.panGestureRecognizer ||
       otherGestureRecognizer == scrollView.pinchGestureRecognizer {
      return true
    }

    return false
  }

  public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent) {
    for touch in touches {
      // Check the right container - either the workspace, toolbox, or trash.
      let workspaceView: WorkspaceView
      if inToolbox {
        if inTrash {
          workspaceView = _workbench.trashCanViewController.workspaceView
        } else {
          workspaceView = _workbench.toolboxCategoryViewController.workspaceView
        }
      } else {
        workspaceView = _workbench.workspaceViewController.workspaceView
      }
      // Hit test the appropriate container.
      let containerView = workspaceView.scrollView.containerView
      let location = touch.locationInView(containerView)
      let hitView: UIView? = containerView.hitTest(location, withEvent: event)

      // If the hit tested view is not an ancestor of a block, cancel the touch(es).
      var block = owningBlockView(hitView)
      if hitView == nil || block == nil {
        super.touchesCancelled(touches, withEvent: event)
        return
      }

      // If the touch is in the toolbox, copy the block over to the workspace first.
      if inToolbox {
        if inTrash {
          let oldBlock = block
          block = _workbench.copyBlockToWorkspace(block!)
          _workbench.removeBlockFromTrash(oldBlock!)
        } else {
          block = _workbench.copyBlockToWorkspace(block!)
        }
      }

      // Start the drag.
      super.touchesBegan(touches, withEvent:event)
      let workspaceScrollView = _workbench.workspaceViewController.workspaceView.scrollView
      let touchPosition = touch.locationInView(workspaceScrollView.containerView)
      _workbench.didRecognizeWorkspacePanGesture(self,
                                                 touchPosition: touchPosition,
                                                 blockView: block!,
                                                 state: .Began)
      _touches.append(touch)
      _blocks.append(block!)
    }
  }

  public override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent) {
    super.touchesMoved(touches, withEvent:event)
    for touch in touches {
      if let index = _touches.indexOf(touch) {
        let block = _blocks[index]

        let workspaceScrollView = _workbench.workspaceViewController.workspaceView.scrollView
        let touchPosition = touch.locationInView(workspaceScrollView.containerView)
        _workbench.didRecognizeWorkspacePanGesture(self,
                                                   touchPosition: touchPosition,
                                                   blockView: block,
                                                   state: .Changed)
      }
    }
  }

  public override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent) {
    super.touchesEnded(touches, withEvent:event)
    for touch in touches {
      if let index = _touches.indexOf(touch) {
        let block = _blocks[index]

        let workspaceScrollView = _workbench.workspaceViewController.workspaceView.scrollView
        let touchPosition = touch.locationInView(workspaceScrollView.containerView)
        _workbench.didRecognizeWorkspacePanGesture(self,
                                                   touchPosition: touchPosition,
                                                   blockView: block,
                                                   state: .Ended)

        _touches.removeAtIndex(index)
        _blocks.removeAtIndex(index)
      }
    }
  }
}
