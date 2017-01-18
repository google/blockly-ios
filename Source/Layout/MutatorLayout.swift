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

import Foundation

/**
 Abstract class for storing information on how to perform mutations for a `Mutator`, while still
 maintaining the block layout hierarchy.
 */
@objc(BKYMutatorLayout)
open class MutatorLayout: Layout {
  /// The target `Mutator` to layout
  public final let mutator: Mutator

  /// A workspace layout coordinator used for executing workspace-level operations related
  /// to this mutator.
  open weak var layoutCoordinator: WorkspaceLayoutCoordinator?

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
}
