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
 The delegate protocol for `BlocklyPanGestureRecognizer`.
 */
public protocol BlocklyPanGestureDelegate: class {
  /**
   The callback that's called when the `BlocklyPanGestureRecognizer` detects a valid block pan.
   Note: This function returns a `BlockView`, in case this function changes the view that's passed
   in, typically copying the view onto a new workspace.

   Parameter gesture: The gesture calling this function.
   Parameter block: The `BlockView` being touched.
   Parameter touch: The `UITouch` hitting the block.
   Parameter touchState: The `TouchState` for this individual touch.
   */
  func blocklyPanGestureRecognizer(gesture: BlocklyPanGestureRecognizer,
                                   didTouchBlock block: BlockView,
                                   touch: UITouch,
                                   touchState: BlocklyPanGestureRecognizer.TouchState)
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

  /**
   The states of the individual touches in the `BlocklyPanGestureRecognizer`
   */
  @objc
  public enum BKYBlocklyPanGestureRecognizerTouchState: Int {
    /// Specifies an individual touch has just begun on a `BlockView`
    case Began = 0,
      /// Specifies an individual touch has just changed on a `BlockView`
      Changed,
      /// Specifies an individual touch has just ended on a `BlockView`
      Ended
  }
  public typealias TouchState = BKYBlocklyPanGestureRecognizerTouchState

  // TODO:(#176) - Replace maximumTouches

  /// Maximum number of touches handled by the recognizer
  public var maximumTouches = Int.max

  /// The minimum distance for the gesture recognizer to count as a pan, in the UIView coordinate
  /// system.
  public var minimumPanDistance: Float = 2.0

  /// The delegate this gestureRecognizer operates on (`WorkbenchViewController` by default).
  public weak var targetDelegate: BlocklyPanGestureDelegate?

  // MARK: - Initializer

  /**
   Initializer for the BlocklyPanGestureRecognizer

   - Parameter targetDelegate: The object that listens to the gesture recognizer callbacks
   */
  public init(targetDelegate: BlocklyPanGestureDelegate)
  {
    self.targetDelegate = targetDelegate
    super.init(target: nil, action: nil)
    delaysTouchesBegan = false
  }

  // MARK: - Super

  /**
   Called when touches begin on the workspace.
   */
  public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent) {
    super.touchesBegan(touches, withEvent:event)
    for touch in touches {
      let location = touch.locationInView(view)

      // If the hit tested view is not an ancestor of a block, cancel the touch(es).
      if let attachedView = view,
        let hitView = attachedView.hitTest(location, withEvent: event),
        let block = owningBlockView(hitView)
        where _touches.count < maximumTouches
      {
        let blockAlreadyTouched = _blocks.contains(block)
        _touches.append(touch)
        _blocks.append(block)

        // Begin a new touch immediately if there is another touch being handled. Otherwise, the
        // touch will begin once a touch has been moved enough to trigger a pan.
        if (state == .Began || state == .Changed) && !blockAlreadyTouched {
          // Start the drag.
          targetDelegate?.blocklyPanGestureRecognizer(self,
                                                      didTouchBlock: block,
                                                      touch: touch,
                                                      touchState: .Began)
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
    // If the gesture has yet to start, check if it should start.
    if state == .Possible {
      for touch in touches {
        let touchPosition = touch.locationInView(view)

        // Check the distance between the original touch and this one.
        let previousPosition = touch.previousLocationInView(view)
        let distance = hypotf(Float(previousPosition.x - touchPosition.x),
                              Float(previousPosition.y - touchPosition.y))
        // If the distance is sufficient, begin the gesture.
        if distance > minimumPanDistance {
          state = .Began
          break
        // If not, check the next touch to see if it should begin the gesture.
        } else {
          continue
        }
      }

      // If the gesture still hasn't started, end here.
      if state == .Possible {
        return
      }
    // Set the state to changed, so anything listening to the standard gesture recognizer can
    // listen to standard gesture events. Note UIGestureRecognizer requires setting the state to
    // changed even if it's already there, to fire the correct delegates.
    } else if state == .Began || state == .Changed {
      state = .Changed
    }

    // When we begin the gesture, start a touch on every currently-touched block.
    if state == .Began {
      for touch in _touches {
        if let index = _touches.indexOf(touch) {
          let block = _blocks[index]

          // Ignore any touch beyond the first, if multiple are touching the same block.
          if _blocks.indexOf(block) < index {
            continue
          }

          targetDelegate?.blocklyPanGestureRecognizer(self,
                                                      didTouchBlock: block,
                                                      touch: touch,
                                                      touchState: .Began)
        }
      }
    } else {
      for touch in touches {
        if let index = _touches.indexOf(touch) {
          let block = _blocks[index]

          // Ignore any touch beyond the first, if multiple are touching the same block.
          if _blocks.indexOf(block) < index {
            continue
          }

          targetDelegate?.blocklyPanGestureRecognizer(self,
                                                      didTouchBlock: block,
                                                      touch: touch,
                                                      touchState: .Changed)
        }
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

        // TODO:(#175) Fix blocks jumping from touch to touch when one block is hit by two touches.

        targetDelegate?.blocklyPanGestureRecognizer(self,
                                                    didTouchBlock: block,
                                                    touch: touch,
                                                    touchState: .Ended)
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
   Called when the gesture recognizer terminates (ended, cancelled, or failed.) Cleans up internal
   references.
   */
  public override func reset() {
    super.reset()
    _touches.removeAll()
    _blocks.removeAll()
  }

  /**
   Manually cancels the touches of the gesture recognizer.
   */
  public func cancelAllTouches() {
    reset()
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

   - Parameter block: The old `BlockView` to be tracked.
   - Parameter newBlock: The new `BlockView` to be tracked.
   */
  public func replaceBlock(block: BlockView, withNewBlock newBlock: BlockView) {
    guard let touchIndex = _blocks.indexOf(block) else {
      return
    }

    _blocks[touchIndex] = newBlock
  }

  /**
   Checks if any touch handled by the gesture recognizer is inside a given view.

   - Parameter view: The `UIView` to be checked against.
   */
  public func isTouchingView(otherView: UIView) -> Bool {
    for touch in _touches {
      let touchPosition = touch.locationInView(otherView)
      if CGRectContainsPoint(otherView.bounds, touchPosition) {
        return true
      }
    }

    return false
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
