/*
* Copyright 2015 Google Inc. All Rights Reserved.
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
Protocol for events that occur on a `Workspace`.
*/
@objc(BKYWorkspaceDelegate)
public protocol WorkspaceDelegate {
  /**
  Event that is called when one of the workspace's properties has changed.

  - Parameter workspace: The workspace that changed.
  */
  func workspaceDidChange(workspace: Workspace)
}

/**
Data structure that contains `Block` instances.
*/
@objc(BKYWorkspace)
public class Workspace : NSObject {
  // MARK: - Properties

  public let isFlyout: Bool
  public let isRTL: Bool
  public let maxBlocks: Int?
  public var blocks = [Block]()
  public weak var delegate: WorkspaceDelegate?

  // MARK: - Initializers

  public init(isFlyout: Bool, isRTL: Bool = false, maxBlocks: Int? = nil) {
    self.isFlyout = isFlyout
    self.isRTL = isRTL
    self.maxBlocks = maxBlocks
  }
}
