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
import UIKit
import UIKit.UIGestureRecognizerSubclass

/**
 The delegate protocol for BlocklyPanGestureRecognizer.
 */
public protocol BlocklyPanGestureDelegate {
  /**
   The callback that's called when the BlocklyPanGestureRecognizer detects a valid block pan. Note:
   This function returns a `BlockView`, in case this function changes the view that's passed in,
   typically copying the view onto a new workspace.

   Parameter gesture: The gesture calling this function.
   Parameter touchPosition: The UI space position of the touch.
   Parameter block: The `BlockView` being touched.
   Parameter state: The `UIGestureRecognizerState` for this individual touch.
   Return: The `BlockView` currently being touched. Typically, this will be block, but blockTouched
     might copy it into a new view.
   */
  func blockTouched(gesture: BlocklyPanGestureRecognizer, touchPosition: CGPoint, block:BlockView,
                    state: UIGestureRecognizerState) -> BlockView;
}

/**
 The blockly gesture recognizer, which detects pan gestures on blocks in the workspace.
 */
public class BlocklyPanGestureRecognizer: UIGestureRecognizer {
  // MARK: - Properties

  /// The delegate this gestureRecognizer operates on (`WorkbenchViewController` by default).
  private var _target: BlocklyPanGestureDelegate

  /// The minimum distance for the gesture recognizer to count as a pan.
  private let _minPanDistance: Float = 2.0

  /// An ordered list of touches being handled by the recognizer.
  private var _touches: [UITouch]

  /// An ordered list of blocks being dragged by the recognizer.
  private var _blocks: [BlockView]

  /**
   The container view blocks to be dragged are currently - either the "main" workspace, or a
   toolbox/trash container.
   */
  private let _originView: UIView

  /**
   The container view blocks will end up in - either the same as the origin view, or the
   workspace blocks are being copied into.
   */
  private let _destinationView: UIView

  // MARK: - Initializer

  /**
   Initializer for the BlocklyPanGestureRecognizer

   - Parameter target: The object that listens to the gesture recognizer callbacks
   - Parameter action: The action to be performed on recognizer callbacks
   - Parameter workbench: The workbench being operated on
   */
  public init(target: BlocklyPanGestureDelegate, action: Selector, originView: UIView,
    destView: UIView, workbench: WorkbenchViewController)
  {
    _target = workbench
    _blocks = [BlockView]()
    _touches = [UITouch]()
    _originView = originView
    _destinationView = destView
    super.init(target: target as? AnyObject, action: action)
    delaysTouchesBegan = false
  }

  // MARK: - Super

  /**
   Called when touches begin on the workspace.
   */
  public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent) {
    for touch in touches {
      let location = touch.locationInView(_originView)

      // If the hit tested view is not an ancestor of a block, cancel the touch(es).
      if let hitView = _originView.hitTest(location, withEvent: event),
        var block = owningBlockView(hitView)
      {
        super.touchesBegan(touches, withEvent:event)
        // Begin a new touch immediately if there is another touch being handled. Otherwise, the
        // touch will begin once a touch has been moved enough to trigger a pan.
        if state == .Began || state == .Changed {
          // Check that we're not already dragging the block with a different touch
          if !_blocks.contains(block) {
            // Start the drag.
            let touchPosition = touch.locationInView(_destinationView)
            block = _target.blockTouched(self,
                                         touchPosition: touchPosition,
                                         block: block,
                                         state: .Began)
          }
        }

        _touches.append(touch)
        _blocks.append(block)
      }
    }

    // If none of the touches have hit a block, cancel the gesture.
    if _touches.count == 0 {
      state = .Cancelled
    }
  }

  /**
   Called when touches are moved on the workspace.
   */
  public override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent) {
    super.touchesMoved(touches, withEvent:event)
    for touch in touches {
      let touchPosition = touch.locationInView(_destinationView)

      if state == .Possible {
        // Check the distance between the original touch and this one.
        let previousPosition = touch.previousLocationInView(_destinationView)
        let distance = hypotf(Float(previousPosition.x - touchPosition.x),
                              Float(previousPosition.y - touchPosition.y))
        // If the distance is sufficient, begin the touch.
        if distance > _minPanDistance {
          state = .Began
        } else {
          continue
        }
      } else if state == .Began || state == .Changed {
        // Set the state to changed, so anything listening to the standard gesture recognizer can
        // listen to standard gesture events.
        state = .Changed
      }

      if let index = _touches.indexOf(touch) {
        let block = _blocks[index]
        // Ignore any touch beyond the first, if multiple are touching the same block.
        if _blocks.indexOf(block) < index {
          continue
        }

        if state == .Began {
          // If the gesture just began, begin a touch on the delegate.
          _blocks[index] = _target.blockTouched(self,
                                                touchPosition: touchPosition,
                                                block: block,
                                                state: .Began)
          continue
        }

        _blocks[index] = _target.blockTouched(self,
                                              touchPosition: touchPosition,
                                              block: block,
                                              state: .Changed)
      }
    }
  }

  /**
   Called when touches end on a workspace.
   */
  public override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent) {
    super.touchesEnded(touches, withEvent:event)
    for touch in touches {
      if let index = _touches.indexOf(touch) {
        let block = _blocks[index]

        _touches.removeAtIndex(index)
        _blocks.removeAtIndex(index)

        // Only end the drag if no other touches are dragging the block.
        if _blocks.contains(block) {
          continue
        }

        let touchPosition = touch.locationInView(_destinationView)
        _target.blockTouched(self, touchPosition: touchPosition, block: block, state: .Ended)
      }
    }

    if _touches.count == 0 {
      if state == .Changed {
        // If the gesture succeeded, end the gesture.
        state = .Ended
      } else {
        // If the gesture never began, cancel the gesture.
        state = .Cancelled
      }
    }
  }

  // MARK: - Private

  /**
   Utility function for finding the first ancestor that is a `BlockView`.

   - Parameter view: The view to find an ancestor of
   - Return: The first ancestor of the `UIView` that is a `BlockView`
   */
  private func owningBlockView(view: UIView?) -> BlockView? {
    var currentView = view
    while !(currentView is BlockView) {
      currentView = currentView?.superview
      if currentView == nil {
        return nil
      }

      if currentView == _originView {
        return nil
      }
    }

    return currentView as? BlockView
  }
}
