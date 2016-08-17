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
 The states of the individual touches in the `BlocklyPanGestureRecognizer`
 */
@objc
public enum BlocklyPanGestureState: Int {
  case Began
  case Changed
  case Ended
}

/**
 The delegate protocol for `BlocklyPanGestureRecognizer`.
 */
public protocol BlocklyPanGestureDelegate: class {
  /**
   The callback that's called when the BlocklyPanGestureRecognizer detects a valid block pan. Note:
   This function returns a `BlockView`, in case this function changes the view that's passed in,
   typically copying the view onto a new workspace.

   Parameter gesture: The gesture calling this function.
   Parameter touchPosition: The touch position in the `UIView` coordinate system.
   Parameter block: The `BlockView` being touched.
   Parameter state: The `UIGestureRecognizerState` for this individual touch.
   Return: The `BlockView` currently being touched. Typically, this will be block, but blockTouched
     might copy it into a new view.
   */
  func blocklyPanGestureRecognizer(gesture: BlocklyPanGestureRecognizer, touchPosition: CGPoint,
                                   touchIndex: Int, block:BlockView, state: BlocklyPanGestureState)
}

/**
 The blockly gesture recognizer, which detects pan gestures on blocks in the workspace.
 */
public class BlocklyPanGestureRecognizer: UIGestureRecognizer {
  // MARK: - Properties

  /// An ordered list of touches being handled by the recognizer.
  private var _touches = [UITouch]()

  /// An ordered list of blocks being dragged by the recognizer.
  private var _blocks = [BlockView]()

  /// The container view blocks will end up in - either the same as the origin view, or the
  /// workspace blocks are being copied into.
  private let _destinationView: UIView

  /// The minimum distance for the gesture recognizer to count as a pan, in the UIView coordinate
  /// system.
  public var minPanDistance: Float = 2.0

  /// The delegate this gestureRecognizer operates on (`WorkbenchViewController` by default).
  public weak var targetDelegate: BlocklyPanGestureDelegate!

  // MARK: - Initializer

  /**
   Initializer for the BlocklyPanGestureRecognizer

   - Parameter target: The object that listens to the gesture recognizer callbacks
   - Parameter action: The action to be performed on recognizer callbacks
   - Parameter workbench: The workbench being operated on
   */
  public init(targetDelegate: BlocklyPanGestureDelegate, action: Selector, destinationView: UIView)
  {
    self.targetDelegate = targetDelegate
    _destinationView = destinationView
    super.init(target: targetDelegate as AnyObject, action: action)
    delaysTouchesBegan = false
  }

  // MARK: - Super

  /**
   Called when touches begin on the workspace.
   */
  public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent) {
    super.touchesBegan(touches, withEvent:event)
    for touch in touches {
      let location = touch.locationInView(self.view)

      // If the hit tested view is not an ancestor of a block, cancel the touch(es).
      if let hitView = self.view!.hitTest(location, withEvent: event),
        let block = owningBlockView(hitView)
      {
        let blockAlreadyTouched = _blocks.contains(block)
        _touches.append(touch)
        _blocks.append(block)

        guard let touchIndex = _touches.indexOf(touch) else {
          continue
        }

        // Begin a new touch immediately if there is another touch being handled. Otherwise, the
        // touch will begin once a touch has been moved enough to trigger a pan.
        if (state == .Began || state == .Changed) && !blockAlreadyTouched {
          // Start the drag.
          let touchPosition = touch.locationInView(_destinationView)
          targetDelegate.blocklyPanGestureRecognizer(self,
                                                     touchPosition: touchPosition,
                                                     touchIndex: touchIndex,
                                                     block: block,
                                                     state: .Began)
        }
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
        if distance > minPanDistance {
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
          targetDelegate.blocklyPanGestureRecognizer(self,
                                                     touchPosition: touchPosition,
                                                     touchIndex: index,
                                                     block: block,
                                                     state: .Began)
          continue
        }

        targetDelegate.blocklyPanGestureRecognizer(self,
                                                   touchPosition: touchPosition,
                                                   touchIndex: index,
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
        targetDelegate.blocklyPanGestureRecognizer(self,
                                                   touchPosition: touchPosition,
                                                   touchIndex: index,
                                                   block: block,
                                                   state: .Ended)
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

  /**
   Called when touches are cancelled on a workspace.
   */
  public override func touchesCancelled(touches: Set<UITouch>, withEvent event: UIEvent) {
    super.touchesCancelled(touches, withEvent: event)
    for touch in touches {
      if let index = _touches.indexOf(touch) {
        _touches.removeAtIndex(index)
        _blocks.removeAtIndex(index)
      }
    }

    if _touches.count == 0 {
      state = .Cancelled
    }
  }

  /**
   Manually cancels the touches of the gesture recognizer.
   */
  public func cancelAllTouches() {
    _touches.removeAll()
    _blocks.removeAll()

    state = .Cancelled
  }

  /**
   Calculates the delta of the first touch in a given view.

   - Parameter view: The view to calculate the location of the touch position.
   - Return: The difference between the current position and the previous position.
   */
  public func firstTouchDeltaInView(view: UIView?) -> CGPoint {
    if _touches.count > 0 {
      let currentPosition = _touches[0].locationInView(view)
      let previousPosition = _touches[0].previousLocationInView(view)

      return currentPosition - previousPosition
    }

    return CGPointZero
  }

  /**
   Updates the block at the given index, when the `BlockView` has changed (typically when it is
   copied to a new workspace.)

   - Parameter block: The new `BlockView` to be tracked
   - Parameter touchIndex: The index of the touch (and block) tracked by the recognizer
   */
  public func updateBlock(block: BlockView, forTouchIndex touchIndex: Int) {
    if (touchIndex > _blocks.count) {
      return;
    }

    _blocks[touchIndex] = block
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

      if currentView == self.view {
        return nil
      }
    }

    return currentView as? BlockView
  }
}
