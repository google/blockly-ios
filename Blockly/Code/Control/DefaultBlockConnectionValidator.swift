//
//  DefaultBlockConnectionValidator.swift
//  Blockly
//
//  Created by Cory Diers on 8/12/16.
//  Copyright © 2016 Google Inc. All rights reserved.
//

import Foundation

@objc(BKYDefaultBlockConnectionValidator)
public class DefaultBlockConnectionValidator : NSObject, BlockConnectionValidator {

  public final func canConnect(
    moving: Connection, toConnection candidate: Connection) -> Bool
  {
    // Type checking
    let canConnect = moving.canConnectWithReasonTo(candidate)
    guard canConnect.intersectsWith(.CanConnect) ||
      canConnect.intersectsWith(.ReasonMustDisconnect) else
    {
      return false
    }

    // Don't connect terminal blocks unless they're replaced by terminal blocks
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