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
 Associated layout class for `MutatorProcedureIfReturn`.
 */
@objc(BKYMutatorProcedureIfReturnLayout)
@objcMembers public class MutatorProcedureIfReturnLayout : MutatorLayout {

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

    updateHasReturnValue()

    EventManager.shared.addListener(self)
  }

  deinit {
    EventManager.shared.removeListener(self)
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

    // Disconnect connections of existing mutation inputs prior to mutating the block
    let inputs = mutatorProcedureIfReturn.sortedMutatorInputs()
    try mutatorHelper.disconnectConnectionsInReverseOrder(
      fromInputs: inputs, layoutCoordinator: layoutCoordinator)

    // Remove any connected shadow blocks from these inputs
    try mutatorHelper.removeShadowBlocksInReverseOrder(
      fromInputs: inputs, layoutCoordinator: layoutCoordinator)

    try captureChangeEvent {
      // Update the definition of the block
      try mutatorProcedureIfReturn.mutateBlock()

      // Update UI
      try layoutCoordinator.rebuildLayoutTree(forBlock: block)
    }

    // Reconnect saved connections
    try mutatorHelper.reconnectSavedTargetConnections(
      toInputs: mutatorProcedureIfReturn.sortedMutatorInputs(),
      layoutCoordinator: layoutCoordinator)
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

        try Layout.doNotAnimate {
          try performMutation()
        }

        if let blockLayout = mutator.block?.layout {
          Layout.animate {
            layoutCoordinator?.blockBumper
              .bumpNeighbors(ofBlockLayout: blockLayout, alwaysBumpOthers: true)
          }
        }
      } catch let error {
        bky_assertionFailure("Could not update if/return block: \(error)")
      }
    }
  }
}

extension MutatorProcedureIfReturnLayout: EventManagerListener {
  public func eventManager(_ eventManager: EventManager, didFireEvent event: BlocklyEvent) {
    if layoutCoordinator?.workspaceLayout.workspace.uuid == event.workspaceID &&
      event is BlocklyEvent.Move {

      EventManager.shared.groupAndFireEvents(groupID: event.groupID) {
        // Something has been moved in the workspace, which means a connection may have changed.
        // This block may need to update its if/return mutation if it's changed grandparents.
        updateHasReturnValue()
      }
    }
  }
}
