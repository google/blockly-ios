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

@objc(BKYConnectionHelper)
public class ConnectionHelper: NSObject {
  /// Dictionary that indexes weak target `Connection` references to the input name they were
  /// previously connected to.
  public private(set) var _savedTargetConnections: NSMapTable<NSString, Connection> =
    NSMapTable.strongToWeakObjects()

  public func clearSavedTargetConnections() {
    _savedTargetConnections.removeAllObjects()
  }

  public func saveTargetConnections(fromInputs inputs: [Input]) {
    for input in inputs {
      if let targetConnection = input.connection?.targetConnection {
        _savedTargetConnections.setObject(targetConnection, forKey: input.name as NSString)
      }
    }
  }

  public func disconnectConnections(
    fromInputs inputs: [Input], layoutCoordinator: WorkspaceLayoutCoordinator)
  {
    for input in inputs {
      if let connection = input.connection {
        layoutCoordinator.disconnect(connection)
      }
    }
  }

  open func reconnectSavedTargetConnections(
    toInputs inputs: [Input], layoutCoordinator: WorkspaceLayoutCoordinator) throws
  {
    for input in inputs {
      if let inputConnection = input.connection,
        let targetConnection = _savedTargetConnections.object(forKey: input.name as NSString)
      {
        try layoutCoordinator.connect(inputConnection, targetConnection)
      }
    }
  }
}
