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
 Associated layout class for `MutatorProcedureIfReturn`.
 */
@objc(BKYMutatorProcedureIfReturnLayout)
public class MutatorProcedureIfReturnLayout : MutatorLayout {

  // MARK: - Properties

  /// The model mutator
  private let mutatorProcedureIfReturn: MutatorProcedureIfReturn

  /// Flag determining if this procedure returns a value
  public var hasReturnValue: Bool {
    get { return mutatorProcedureIfReturn.hasReturnValue }
    set { mutatorProcedureIfReturn.hasReturnValue = newValue }
  }

  /// Mutator helper used for transitioning between mutations
  private let mutatorHelper = MutatorHelper()

  // MARK: - Initializers

  public init(mutator: MutatorProcedureIfReturn, engine: LayoutEngine) {
    self.mutatorProcedureIfReturn = mutator
    super.init(mutator: mutator, engine: engine)

    NotificationCenter.default.addObserver(
      self, selector: #selector(workspaceLayoutCoordinatorDidConnect(_:)),
      name: WorkspaceLayoutCoordinator.NotificationDidConnect, object: nil)

    updateHasReturnValue()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Super

  public override func performLayout(includeChildren: Bool) {
    // An if/return block is not user-configurable, so its size is set to zero
    self.contentSize = WorkspaceSize.zero
  }

  public override func performMutation() throws {
    guard let block = mutatorProcedureIfReturn.block,
      let layoutCoordinator = self.layoutCoordinator else
    {
      return
    }

    var blockLayout: BlockLayout?

    try Layout.doNotAnimate {
      // Disconnect connections of existing mutation inputs prior to mutating the block
      let inputs = mutatorProcedureIfReturn.sortedMutatorInputs()
      try mutatorHelper.disconnectConnectionsInReverseOrder(
        fromInputs: inputs, layoutCoordinator: layoutCoordinator)

      // Remove any connected shadow blocks from these inputs
      try mutatorHelper.removeShadowBlocksInReverseOrder(
        fromInputs: inputs, layoutCoordinator: layoutCoordinator)

      // Update the definition of the block
      try mutatorProcedureIfReturn.mutateBlock()

      // Update UI
      blockLayout = try layoutCoordinator.rebuildLayoutTree(forBlock: block)

      // Reconnect saved connections
      try mutatorHelper.reconnectSavedTargetConnections(
        toInputs: mutatorProcedureIfReturn.sortedMutatorInputs(),
        layoutCoordinator: layoutCoordinator)
    }

    if let blockLayout = blockLayout {
      Layout.animate {
        layoutCoordinator.blockBumper
          .bumpNeighbors(ofBlockLayout: blockLayout, alwaysBumpOthers: true)
      }
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
      fromInputs: mutatorProcedureIfReturn.sortedMutatorInputs())
  }

  // MARK: - Validation

  /**
   If this layout is a descendant of a procedure definition block, this method automatically
   updates `self.hasReturnValue` to match if the definition block has a return value
   or not.
   */
  fileprivate func updateHasReturnValue() {
    guard let rootBlock = mutator.block?.layout?.rootBlockGroupLayout?.blockLayouts[0].block else {
      return
    }

    if (rootBlock.name == ProcedureCoordinator.BLOCK_DEFINITION_NO_RETURN && hasReturnValue) ||
       (rootBlock.name == ProcedureCoordinator.BLOCK_DEFINITION_RETURN && !hasReturnValue)
    {
      do {
        // This if/return block needs to flip its hasReturnValue to match the definition block
        // that it's contained under.
        hasReturnValue = !hasReturnValue
        try performMutation()
      } catch let error {
        bky_assertionFailure("Could not update if/return block: \(error)")
      }
    }
  }
}

extension MutatorProcedureIfReturnLayout {
  // MARK: - WorkspaceLayoutCoordinator.NotificationDidConnect Listener

  fileprivate dynamic func workspaceLayoutCoordinatorDidConnect(_ notification: NSNotification) {
    if let layoutCoordinator = notification.object as? WorkspaceLayoutCoordinator,
      isDescendant(of: layoutCoordinator.workspaceLayout)
    {
      // Some connection has changed in the workspace that this mutator is part of.
      // This block may need to update its if/return mutation if it's changed grandparents.
      updateHasReturnValue()
    }
  }
}
