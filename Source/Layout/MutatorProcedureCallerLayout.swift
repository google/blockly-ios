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
 Associated layout class for `MutatorProcedureCaller`.
 */
public class MutatorProcedureCallerLayout : MutatorLayout {

  // MARK: - Properties

  /// The model mutator
  private let mutatorProcedureCaller: MutatorProcedureCaller

  /// The name of the procedure
  public var procedureName: String {
    get { return mutatorProcedureCaller.procedureName }
    set { mutatorProcedureCaller.procedureName = newValue }
  }

  /// The parameters of the procedure
  public var parameters: [String] {
    get { return mutatorProcedureCaller.parameters }
    set { mutatorProcedureCaller.parameters = newValue }
  }

  /// Mutator helper used for transitioning between mutations
  private let mutatorHelper = MutatorHelper()

  // MARK: - Initializers

  public init(mutator: MutatorProcedureCaller, engine: LayoutEngine) {
    self.mutatorProcedureCaller = mutator
    super.init(mutator: mutator, engine: engine)
  }

  // MARK: - Super

  public override func performLayout(includeChildren: Bool) {
    // A procedure caller is not user-configurable, so set its size to zero
    self.contentSize = .zero
  }

  public override func performMutation() throws {
    guard let block = mutatorProcedureCaller.block,
      let layoutCoordinator = self.layoutCoordinator else
    {
      return
    }

    // Disconnect connections of existing mutation inputs prior to mutating the block
    let inputs = mutatorProcedureCaller.sortedMutatorInputs()
    mutatorHelper.disconnectConnectionsInReverseOrder(
      fromInputs: inputs, layoutCoordinator: layoutCoordinator)

    // Remove any connected shadow blocks from these inputs
    try mutatorHelper.removeShadowBlocksInReverseOrder(
      fromInputs: inputs, layoutCoordinator: layoutCoordinator)

    // Update the definition of the block
    try mutatorProcedureCaller.mutateBlock()

    // Update UI
    let blockLayout = try layoutCoordinator.rebuildLayoutTree(forBlock: block)

    // Reconnect saved connections
    try mutatorHelper.reconnectSavedTargetConnections(
      toInputs: mutatorProcedureCaller.sortedMutatorInputs(),
      layoutCoordinator: layoutCoordinator)

    Layout.animate {
      layoutCoordinator.blockBumper
        .bumpNeighbors(ofBlockLayout: blockLayout, alwaysBumpOthers: true)
    }
  }

  // MARK: - Pre-Mutation

  /**
   For all inputs created by this mutator, save the currently connected target connection for
   each of them. Any subsequent call to `performMutation()` will ensure that these saved target
   connections remain connected to that original input, as long as the input still exists
   post-mutation.
   */
  public func preserveCurrentInputConnections() {
    mutatorHelper.clearSavedTargetConnections()
    mutatorHelper.saveTargetConnections(
      fromInputs: mutatorProcedureCaller.sortedMutatorInputs())
  }
}
