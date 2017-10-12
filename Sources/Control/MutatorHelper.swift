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
 Helper class for transitioning between block mutation changes.
 */
@objc(BKYMutatorHelper)
@objcMembers public class MutatorHelper: NSObject {
  // MARK: - Properties

  /// Table that maps input names to a target connection. This is used for reconnecting inputs
  /// to previously connected connections.
  public private(set) var savedTargetConnections: NSMapTable<NSString, Connection> =
    NSMapTable.strongToWeakObjects()

  // MARK: - Mutator Initialization

  /**
   Clears the mapping of inputs and target connections.

   - note: This method is typically called once prior to beginning mutator changes inside a
   modal popover.
   */
  public func clearSavedTargetConnections() {
    savedTargetConnections.removeAllObjects()
  }

  /**
   For each specified input, saves the mapping of the input's name and its current target
   connection. This is to be used in conjunction with
   `reconnectSavedTargetConnections(toInputs:layoutCoordinator:)`.

   - parameter inputs: The list of inputs whose target connections should be saved.
   - note: This method is typically called once prior to beginning mutator changes inside a
   modal popover.
   */
  public func saveTargetConnections(fromInputs inputs: [Input]) {
    for input in inputs {
      if let targetConnection = input.connection?.targetConnection {
        savedTargetConnections.setObject(targetConnection, forKey: input.name as NSString)
      }
    }
  }

  // MARK: - Pre-Mutation Methods

  /**
   Disconnects any target blocks connected to a specified list of inputs, iterating through the
   list in reverse order.

   - parameter inputs: The inputs whose target connection should be disconnected.
   - parameter layoutCoordinator: The `WorkspaceLayoutCoordinator` used for disconnecting those
   inputs.
   - note: This method is typically called every time before applying a mutation.
   - throws:
   `BlocklyError`: Thrown if one of the inputs could not be disconnected.
   */
  public func disconnectConnectionsInReverseOrder(
    fromInputs inputs: [Input], layoutCoordinator: WorkspaceLayoutCoordinator) throws
  {
    for input in inputs.reversed() {
      if let connection = input.connection {
        try layoutCoordinator.disconnect(connection)
      }
    }
  }

  /**
   Removes from the workspace any shadow blocks connected to a specified list of inputs,
   iterating through the list in reverse order.

   - parameter inputs: The inputs whose shadow blocks should be removed from the workspace.
   - parameter layoutCoordinator: The `WorkspaceLayoutCoordinator` used for removing those
   shadow blocks.
   - note: This method is typically called every time before applying a mutation.
   - throws:
   `BlocklyError`: Thrown if one of the shadow blocks could not be disconnected.
   */
  public func removeShadowBlocksInReverseOrder(
    fromInputs inputs: [Input], layoutCoordinator: WorkspaceLayoutCoordinator) throws
  {
    for input in inputs.reversed() {
      if let shadowConnection = input.connection?.shadowConnection,
        let shadowBlock = shadowConnection.sourceBlock
      {
        try layoutCoordinator.disconnectShadow(shadowConnection)
        try layoutCoordinator.removeBlockTree(shadowBlock)
      }
    }
  }

  // MARK: - Post-Mutation

  /**
   For each specified input, reconnects the input to any target connection that was previously saved
   via `saveTargetConnections(fromInputs:)`.

   - parameter inputs: The list of inputs that should be reconnected to the saved target connection.
   - parameter layoutCoordinator: The `WorkspaceLayoutCoordinator` used for connecting the inputs
   with the saved target connections.
   - note: This method is typically called every time after a mutation has been applied.
   */
  public func reconnectSavedTargetConnections(
    toInputs inputs: [Input], layoutCoordinator: WorkspaceLayoutCoordinator) throws
  {
    for input in inputs {
      if let inputConnection = input.connection,
        let targetConnection = savedTargetConnections.object(forKey: input.name as NSString)
      {
        try layoutCoordinator.connect(inputConnection, targetConnection)
      }
    }
  }
}
