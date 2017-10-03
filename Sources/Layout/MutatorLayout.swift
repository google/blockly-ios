/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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

import AEXML
import Foundation

/**
 Abstract class for storing information on how to perform mutations for a `Mutator`, while still
 maintaining the block layout hierarchy.
 */
@objc(BKYMutatorLayout)
@objcMembers open class MutatorLayout: Layout {
  /// The target `Mutator` to layout
  public final let mutator: Mutator

  /// A workspace layout coordinator used for executing workspace-level operations related
  /// to this mutator.
  open weak var layoutCoordinator: WorkspaceLayoutCoordinator?

  /// Flag determining if user interaction should be enabled for the corresponding view.
  public var userInteractionEnabled: Bool {
    return mutator.block?.editable ?? false
  }

  // MARK: - Initializers

  /**
   Initializes an empty `MutatorLayout`.

   - parameter engine: The `LayoutEngine` to associate with this layout.
   - parameter mutator: The `Mutator` to associate with this layout.
   */
  public init(mutator: Mutator, engine: LayoutEngine) {
    self.mutator = mutator
    super.init(engine: engine)
  }

  // MARK: - Abstract

  /**
   Performs any work required to maintain the integrity of the layout hierarchy, in addition to
   calling `mutator.mutateBlock()`.

   This is where pre-/post- mutation work should be handled.

   - note: This method needs to be implemented by a subclass of `MutatorLayout`.
   */
  open func performMutation() throws {
    bky_assertionFailure("\(#function) needs to be implemented by a subclass")
  }

  /**
   Updates the mutator from XML and immediately performs a mutation by calling `performMutation()`.

   - parameter xml: The XML used to update the mutator.
   - throws:
   `BlocklyError`: Thrown if the mutation could not be performed.
   */
  open func performMutation(fromXML xml: AEXMLElement) throws {
    mutator.update(fromXML: xml)
    try performMutation()
  }


  // MARK: - Change Event

  /**
   Automatically captures a `BlocklyEvent.Change` for `self.mutator`, based on its state before
   and after running a given closure block. This event is then added to the pending events queue
   on `EventManager.shared`.

   - parameter closure: A closure to execute, that will change the state of `self.mutator`.
   */
  public func captureChangeEvent(closure: () throws -> Void) rethrows {
    if let workspace = layoutCoordinator?.workspaceLayout.workspace,
      let block = mutator.block
    {
      // Capture values before and after running mutation
      let oldValue = mutator.toXMLElement().xml
      try closure()
      let newValue = mutator.toXMLElement().xml

      if oldValue != newValue {
        let event = BlocklyEvent.Change.mutateEvent(
          workspace: workspace, block: block, oldValue: oldValue, newValue: newValue)
        EventManager.shared.addPendingEvent(event)
      }
    } else {
      // Just run closure
      try closure()
    }
  }
}
