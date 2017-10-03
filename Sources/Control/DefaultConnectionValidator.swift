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

/**
 Default implementation of the connection validator. Unless otherwise specified, this will be
 the validator that is used by the `ConnectionManager`.
 */
@objc(BKYDefaultConnectionValidator)
@objcMembers open class DefaultConnectionValidator : NSObject, ConnectionValidator {

  public final func canConnect(
    _ moving: Connection, toConnection candidate: Connection) -> Bool
  {
    // Type checking
    let canConnect = moving.canConnectWithReasonTo(candidate)
    guard canConnect.intersectsWith(.CanConnect) ||
      canConnect.intersectsWith(.ReasonMustDisconnect) else
    {
      return false
    }

    // Don't connect terminal blocks unless they're replaced by terminal blocks
    if candidate.targetConnection?.sourceBlock?.nextConnection != nil &&
      moving.sourceBlock?.nextConnection == nil
    {
      return false
    }

    // Don't offer to connect an already connected left (male) value plug to
    // an available right (female) value plug.  Don't offer to connect the
    // bottom of a statement block to one that's already connected.
    if candidate.connected &&
      (candidate.type == .outputValue || candidate.type == .previousStatement) {
      return false
    }

    return true
  }
}
