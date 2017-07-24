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
 Associated layout class for `MutatorIfElse`.
 */
public class MutatorIfElseLayout : MutatorLayout {

  // MARK: - Properties

  /// The model mutator
  private let mutatorIfElse: MutatorIfElse

  /// The number of else-if statements
  public var elseIfCount: Int {
    get { return mutatorIfElse.elseIfCount }
    set { mutatorIfElse.elseIfCount = newValue }
  }

  /// Flag determining if there is an else statement
  public var elseStatement: Bool {
    get { return mutatorIfElse.elseStatement }
    set { mutatorIfElse.elseStatement = newValue }
  }

  /// Mutator helper used for transitioning between mutations
  private let mutatorHelper = MutatorHelper()

  // MARK: - Initializers

  public init(mutator: MutatorIfElse, engine: LayoutEngine) {
    self.mutatorIfElse = mutator
    super.init(mutator: mutator, engine: engine)
  }

  // MARK: - Super

  public override func performLayout(includeChildren: Bool) {
    // Inside a block, this mutator is the size of a settings button
    self.contentSize = config.workspaceSize(for: LayoutConfig.MutatorButtonSize)
  }

  public override func performMutation() throws {
    guard let block = mutatorIfElse.block,
      let layoutCoordinator = self.layoutCoordinator else
    {
      return
    }

    // Disconnect connections of existing mutation inputs prior to mutating the block
    let inputs = mutatorIfElse.sortedMutatorInputs()
    try mutatorHelper.disconnectConnectionsInReverseOrder(
      fromInputs: inputs, layoutCoordinator: layoutCoordinator)

    // Remove any connected shadow blocks from these inputs
    try mutatorHelper.removeShadowBlocksInReverseOrder(
      fromInputs: inputs, layoutCoordinator: layoutCoordinator)

    // Update the definition of the block
    try captureChangeEvent {
      try mutatorIfElse.mutateBlock()

      // Update UI
      try layoutCoordinator.rebuildLayoutTree(forBlock: block)
    }

    // Reconnect saved connections
    try mutatorHelper.reconnectSavedTargetConnections(
      toInputs: mutatorIfElse.sortedMutatorInputs(), layoutCoordinator: layoutCoordinator)
  }

  public override func performMutation(fromXML xml: AEXMLElement) throws {
    // Since this call is most likely being triggered from an event, clear all saved target
    // connections, before updating via XML
    mutatorHelper.clearSavedTargetConnections()
    try super.performMutation(fromXML: xml)
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
    mutatorHelper.saveTargetConnections(fromInputs: mutatorIfElse.sortedMutatorInputs())
  }
}
