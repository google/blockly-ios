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

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


/**
 The delegate protocol for `BlocklyPanGestureRecognizer`.
 */
@objc(BKYBlocklyPanGestureRecognizerDelegate)
public protocol BlocklyPanGestureRecognizerDelegate: class {
  /**
   The callback that's called when the `BlocklyPanGestureRecognizer` detects a valid block pan.
   Note: This function returns a `BlockView`, in case this function changes the view that's passed
   in, typically copying the view onto a new workspace.

   - parameter gesture: The gesture calling this function.
   - parameter block: The `BlockView` being touched.
   - parameter touch: The `UITouch` hitting the block.
   - parameter touchState: The `BlocklyPanGestureRecognizer.TouchState` for this individual touch.
   */
  func blocklyPanGestureRecognizer(_ gesture: BlocklyPanGestureRecognizer,
                                   didTouchBlock block: BlockView,
                                   touch: UITouch,
                                   touchState: BlocklyPanGestureRecognizer.TouchState)
}

/**
 The blockly gesture recognizer, which detects pan gestures on blocks in the workspace.
 */
@objc(BKYBlocklyPanGestureRecognizer)
@objcMembers open class BlocklyPanGestureRecognizer: UIGestureRecognizer {
  // MARK: - Constants

  /**
   The states of the individual touches in the `BlocklyPanGestureRecognizer`
   */
  @objc(BKYBlocklyPanGestureRecognizerTouchState)
  public enum TouchState: Int {
    case
      /// Specifies an individual touch has just begun on a `BlockView`
      began = 0,
      /// Specifies an individual touch has just changed on a `BlockView`
      changed,
      /// Specifies an individual touch has just ended on a `BlockView`
      ended,
      /// Specifies an individual touch has been cancelled on a `BlockView`.
      cancelled
  }

  // MARK: - Properties

  /// An ordered list of touches being handled by the recognizer.
  private var _touches = [UITouch]()

  /// An ordered list of blocks being dragged by the recognizer.
  private var _blocks = [BlockView]()

  /// Returns the first touch that's been captured by this gesture recognizer, if it exists.
  open var firstTouch: UITouch? {
    return !_touches.isEmpty ? _touches[0] : nil
  }

  // TODO(#176): Replace maximumTouches

  /// Maximum number of touches handled by the recognizer
  open var maximumTouches = Int.max

  /// The minimum distance for the gesture recognizer to count as a pan, in the UIView coordinate
  /// system.
  open var minimumPanDistance: Float = 2.0

  /// The delegate this gestureRecognizer operates on (`WorkbenchViewController` by default).
  open weak var targetDelegate: BlocklyPanGestureRecognizerDelegate?

  // MARK: - Initializer

  /**
   Initializer for the BlocklyPanGestureRecognizer

   - parameter targetDelegate: The object that listens to the gesture recognizer callbacks
   */
  public init(targetDelegate: BlocklyPanGestureRecognizerDelegate?)
  {
    self.targetDelegate = targetDelegate
    super.init(target: nil, action: nil)
    delaysTouchesBegan = false
  }

  // MARK: - Super

  /**
   Called when touches begin on the workspace.
   */
  open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesBegan(touches, with:event)

    for touch in touches {
      let location = touch.location(in: view)

      // If the hit tested view is not an ancestor of a block, cancel the touch(es).
      if let attachedView = view,
        let hitView = attachedView.hitTest(location, with: event),
        let block = owningBlockView(hitView)
        , _touches.count < maximumTouches
      {
        let blockAlreadyTouched = _blocks.contains(block)
        _touches.append(touch)
        _blocks.append(block)

        // Begin a new touch immediately if there is another touch being handled. Otherwise, the
        // touch will begin once a touch has been moved enough to trigger a pan.
        if (state == .began || state == .changed) && !blockAlreadyTouched {
          // Start the drag.
          targetDelegate?.blocklyPanGestureRecognizer(self,
                                                      didTouchBlock: block,
                                                      touch: touch,
                                                      touchState: .began)
        }
      }
    }

    // If none of the touches have hit a block, cancel the gesture.
    if _touches.count == 0 {
      state = .cancelled
    }
  }

  /**
   Called when touches are moved on the workspace.
   */
  open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesMoved(touches, with:event)

    // If the gesture has yet to start, check if it should start.
    if state == .possible {
      for touch in touches {
        let touchPosition = touch.location(in: view)

        // Check the distance between the original touch and this one.
        let previousPosition = touch.previousLocation(in: view)
        let distance = hypotf(Float(previousPosition.x - touchPosition.x),
                              Float(previousPosition.y - touchPosition.y))

        if distance > minimumPanDistance {
          // The distance is sufficient, begin the gesture.
          state = .began
          break
        } else {
          // Check the next touch to see if it should begin the gesture.
          continue
        }
      }

      // If the gesture still hasn't started, end here.
      if state == .possible {
        return
      }
    } else if state == .began || state == .changed {
      // Set the state to changed, so anything listening to the standard gesture recognizer can
      // listen to standard gesture events. Note UIGestureRecognizer requires setting the state to
      // changed even if it's already there, to fire the correct delegates.
      state = .changed
    }

    // When we begin the gesture, start a touch on every currently-touched block.
    if state == .began {
      for touch in _touches {
        if let index = _touches.index(of: touch) {
          let block = _blocks[index]

          // Ignore any touch beyond the first, if multiple are touching the same block.
          if _blocks.index(of: block) < index {
            continue
          }

          targetDelegate?.blocklyPanGestureRecognizer(self,
                                                      didTouchBlock: block,
                                                      touch: touch,
                                                      touchState: .began)
        }
      }
    } else {
      for touch in touches {
        if let index = _touches.index(of: touch) {
          let block = _blocks[index]

          // Ignore any touch beyond the first, if multiple are touching the same block.
          if _blocks.index(of: block) < index {
            continue
          }

          targetDelegate?.blocklyPanGestureRecognizer(self,
                                                      didTouchBlock: block,
                                                      touch: touch,
                                                      touchState: .changed)
        }
      }
    }
  }

  /**
   Called when touches end on a workspace.
   */
  open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesEnded(touches, with:event)

    for touch in touches {
      if let index = _touches.index(of: touch) {
        let block = _blocks[index]

        _touches.remove(at: index)
        _blocks.remove(at: index)

        // Only end the drag if no other touches are dragging the block.
        if _blocks.contains(block) {
          continue
        }

        // TODO(#175): Fix blocks jumping from touch to touch when one block is hit by two touches.

        if state == .began || state == .changed {
          targetDelegate?.blocklyPanGestureRecognizer(self,
                                                      didTouchBlock: block,
                                                      touch: touch,
                                                      touchState: .ended)
        }
      }
    }

    if _touches.count == 0 {
      if state == .changed {
        // The gesture succeeded, end the gesture.
        state = .ended
      } else {
        // The gesture never began, cancel the gesture.
        state = .cancelled
      }
    }
  }

  /**
   Called when touches are cancelled on a workspace.
   */
  open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesCancelled(touches, with: event)

    for touch in touches {
      if let index = _touches.index(of: touch) {
        _touches.remove(at: index)

        // If the gesture recognizer has started recognizing touches, fire delegate to notify
        // of touches being cancelled.
        if state == .began || state == .changed {
          targetDelegate?.blocklyPanGestureRecognizer(self,
                                                      didTouchBlock: _blocks[index],
                                                      touch: touch,
                                                      touchState: .cancelled)
        }
        _blocks.remove(at: index)
      }
    }

    if _touches.count == 0 {
      state = .cancelled
    }
  }

  /**
   Called when the gesture recognizer terminates (ended, cancelled, or failed.) Cleans up internal
   references.
   */
  open override func reset() {
    super.reset()
    _touches.removeAll()
    _blocks.removeAll()
  }

  /**
   Manually cancels the touches of the gesture recognizer.
   */
  public func cancelAllTouches() {
    reset()
    state = .cancelled
  }

  /**
   Calculates the delta of the first touch in a given view.

   - parameter view: The view to calculate the location of the touch position.
   - returns: The difference between the current position and the previous position.
   */
  open func firstTouchDelta(inView view: UIView?) -> CGPoint {
    if _touches.count > 0 {
      if #available(iOS 9.1, *) {
        let currentPosition = _touches[0].preciseLocation(in: view)
        let previousPosition = _touches[0].precisePreviousLocation(in: view)

        return currentPosition - previousPosition
      } else {
        let currentPosition = _touches[0].location(in: view)
        let previousPosition = _touches[0].previousLocation(in: view)

        return currentPosition - previousPosition
      }
    }

    return CGPoint.zero
  }

  /**
   Updates the block at the given index, when the `BlockView` has changed (typically when it is
   copied to a new workspace.)

   - parameter block: The old `BlockView` to be tracked.
   - parameter newBlock: The new `BlockView` to be tracked.
   */
  open func replaceBlock(_ block: BlockView, with newBlock: BlockView) {
    guard let touchIndex = _blocks.index(of: block) else {
      return
    }

    _blocks[touchIndex] = newBlock
  }

  /**
   Checks if any touch handled by the gesture recognizer is inside a given view.

   - parameter view: The `UIView` to be checked against.
   */
  open func isTouchingView(_ view: UIView) -> Bool {
    for touch in _touches {
      let touchPosition = touch.location(in: view)
      if view.bounds.contains(touchPosition) {
        return true
      }
    }

    return false
  }

  // MARK: - Private

  /**
   Utility function for finding the first ancestor that is a draggable `BlockView`.

   - parameter view: The view to find an ancestor of
   - returns: The first ancestor of the `UIView` that is a draggable `BlockView`.
   */
  private func owningBlockView(_ view: UIView?) -> BlockView? {
    var currentView = view

    while currentView != nil && currentView != self.view {
      if let blockView = currentView as? BlockView,
        let blockLayout = blockView.blockLayout,
        blockLayout == blockLayout.draggableBlockLayout {
        return blockView
      }

      currentView = currentView?.superview
    }

    return nil
  }
}
