/*
 * Copyright 2016 Google Inc. All Rights Reserved.
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

@objc(BKYBlockConnectionValidator)
public class BlockConnectionValidator: NSObject {
  public static var checker: BlockConnectionChecker = BlockConnectionChecker()

  /**
   Check if the two connections can be dragged to connect to each other.

   - Parameter moving: The connection being dragged.
   - Parameter candidate: A nearby connection to check. Must not be mid-drag.
   - Parameter allowShadows: Flag determining if shadows are allowed to be connected (`true`) or
   not (`false`).
   - Returns: True if the connection is allowed, false otherwise.
   */
  public static func canConnect(
    moving: Connection, toConnection candidate: Connection, allowShadows: Bool) -> Bool
  {
    return checker.canConnect(moving, toConnection: candidate, allowShadows: allowShadows)
  }
}

@objc(BKYBlockConnectionChecker)
public class BlockConnectionChecker : NSObject {

  public func canConnect(
    moving: Connection, toConnection candidate: Connection, allowShadows: Bool) -> Bool
  {
    // Type checking
    let canConnect = moving.canConnectWithReasonTo(candidate)
    guard canConnect.intersectsWith(.CanConnect) ||
      canConnect.intersectsWith(.ReasonMustDisconnect) ||
      (allowShadows && canConnect.intersectsWith(.ReasonCannotSetShadowForTarget)) else
    {
      return false
    }

    // Terminal blocks can only bump other terminal blocks.
    if candidate.targetConnection?.sourceBlock.nextConnection != nil {
      if moving.sourceBlock.nextConnection == nil {
        return false
      }
    }

    // Don't offer to connect an already connected left (male) value plug to
    // an available right (female) value plug.  Don't offer to connect the
    // bottom of a statement block to one that's already connected.
    if candidate.connected &&
      (candidate.type == .OutputValue || candidate.type == .PreviousStatement) {
        return false
    }

    return true
  }
}