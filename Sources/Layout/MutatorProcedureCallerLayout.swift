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
  public var parameters: [ProcedureParameter] {
    get { return mutatorProcedureCaller.parameters }
    set { mutatorProcedureCaller.parameters = newValue }
  }

  /// Mutator helper used for transitioning between mutations
  private let mutatorHelper = MutatorHelper()

  /// Table that maps parameter UUIDs to a target connection. This is used for reconnecting inputs
  /// to previously connected connections.
  private var savedTargetConnections: NSMapTable<NSString, Connection> =
    NSMapTable.strongToWeakObjects()

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
    try mutatorHelper.disconnectConnectionsInReverseOrder(
      fromInputs: inputs, layoutCoordinator: layoutCoordinator)

    // Remove any connected shadow blocks from these inputs
    try mutatorHelper.removeShadowBlocksInReverseOrder(
      fromInputs: inputs, layoutCoordinator: layoutCoordinator)

    // Update the definition of the block
    try captureChangeEvent {
      try mutatorProcedureCaller.mutateBlock()

      // Update UI
      try layoutCoordinator.rebuildLayoutTree(forBlock: block)
    }

    // Reconnect saved connections
    try reconnectSavedTargetConnections()
  }

  public override func performMutation(fromXML xml: AEXMLElement) throws {
    // Since this call is most likely being triggered from an event, clear all saved target
    // connections, before updating via XML
    savedTargetConnections.removeAllObjects()
    try super.performMutation(fromXML: xml)
  }

  // MARK: - Pre-Mutation

  /**
   For all inputs created by this mutator, save the currently connected target connection
   for each of them. Any subsequent call to `performMutation()` will ensure that these saved target
   connections remain connected to that original input, as long as the input still exists
   post-mutation.
   */
  public func preserveCurrentInputConnections() {
    let inputs = mutatorProcedureCaller.sortedMutatorInputs()
    savedTargetConnections.removeAllObjects()

    for (i, input) in inputs.enumerated() {
      if let targetConnection = input.connection?.targetConnection,
        i < parameters.count
      {
        savedTargetConnections.setObject(targetConnection, forKey: parameters[i].uuid as NSString)
      }
    }
  }

  // MARK: - Post-Mutation

  private func reconnectSavedTargetConnections() throws {
    guard let layoutCoordinator = self.layoutCoordinator else {
      return
    }

    let inputs = mutatorProcedureCaller.sortedMutatorInputs()

    // Reconnect inputs
    for (i, parameter) in parameters.enumerated() {
      let key = parameter.uuid as NSString

      if i < inputs.count,
        let inputConnection = inputs[i].connection,
        let targetConnection = savedTargetConnections.object(forKey: key)
      {
        try layoutCoordinator.connect(inputConnection, targetConnection)
      }
    }
  }
}
