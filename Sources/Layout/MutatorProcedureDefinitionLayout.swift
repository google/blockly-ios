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
 Associated layout class for `MutatorProcedureDefinition`.
 */
public class MutatorProcedureDefinitionLayout : MutatorLayout {

  // MARK: - Properties

  /// Notification that is fired after this layout has performed a mutation
  public static let NotificationDidPerformMutation =
    Notification.Name("MutatorProcedureDefinitionLayoutNotificationDidPerformMutation")

  /// The model mutator
  internal let mutatorProcedureDefinition: MutatorProcedureDefinition

  /// Flag determining if this procedure returns a value
  public var returnsValue: Bool {
    return mutatorProcedureDefinition.returnsValue
  }

  /// The parameters of the procedure
  public var parameters: [ProcedureParameter] {
    get { return mutatorProcedureDefinition.parameters }
    set { mutatorProcedureDefinition.parameters = newValue }
  }

  /// Flag determining if statements can be attached to this procedure.
  /// NOTE: This value is always `true` if `returnsValue` is `false`.
  public var allowStatements: Bool {
    get { return mutatorProcedureDefinition.allowStatements }
    set { mutatorProcedureDefinition.allowStatements = newValue }
  }

  /// Mutator helper used for transitioning between mutations
  private let mutatorHelper = MutatorHelper()

  // MARK: - Initializers

  public init(mutator: MutatorProcedureDefinition, engine: LayoutEngine) {
    self.mutatorProcedureDefinition = mutator
    super.init(mutator: mutator, engine: engine)
  }

  // MARK: - Super

  public override func performLayout(includeChildren: Bool) {
    // Inside a block, this mutator is the size of a settings button
    self.contentSize = config.workspaceSize(for: LayoutConfig.MutatorButtonSize)
  }

  public override func performMutation() throws {
    guard let block = mutatorProcedureDefinition.block,
      let layoutCoordinator = self.layoutCoordinator else
    {
      return
    }

    // Disconnect connections of existing mutation inputs prior to mutating the block
    let inputs = mutatorProcedureDefinition.sortedMutatorInputs()
    try mutatorHelper.disconnectConnectionsInReverseOrder(
      fromInputs: inputs, layoutCoordinator: layoutCoordinator)

    // Remove any connected shadow blocks from these inputs
    try mutatorHelper.removeShadowBlocksInReverseOrder(
      fromInputs: inputs, layoutCoordinator: layoutCoordinator)

    // Update the definition of the block
    try captureChangeEvent {
      try mutatorProcedureDefinition.mutateBlock()

      // Update UI
      try layoutCoordinator.rebuildLayoutTree(forBlock: block)
    }

    // Reconnect saved connections
    try mutatorHelper.reconnectSavedTargetConnections(
      toInputs: mutatorProcedureDefinition.sortedMutatorInputs(),
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
      fromInputs: mutatorProcedureDefinition.sortedMutatorInputs())
  }

  // MARK: - Queries

  /**
   Returns whether or not the mutator contains duplicate parameters.

   - returns: `true` if the mutator contains duplicate parameters. `false` otherwise.
   */
  public func containsDuplicateParameters() -> Bool {
    var set = Set<String>()

    for parameter in parameters.map({ $0.name.lowercased() }) {
      if set.contains(parameter) {
        return true
      } else {
        set.insert(parameter)
      }
    }

    return false
  }
}
