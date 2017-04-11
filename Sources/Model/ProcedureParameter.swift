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
 A procedure parameter that is used by the `MutatorProcedureDefinition` and
 `MutatorProcedureCaller` objects.
 */
public struct ProcedureParameter {

  /// Unique id of this parameter. This value is used when renaming/re-ordering this parameter
  /// inside a definition/caller blocks.
  public let uuid: String

  /// The name of the parameter
  public var name: String

  // MARK: - Initializers

  /**
   Creates a parameter.

   - parameter name: The name of the parameter.
   - parameter uuid: [Optional] A unique ID to assign to this parameter. If `nil` is specified, a
   unique ID is automatically created for this parameter.
   */
  public init(name: String, uuid: String? = nil) {
    self.name = name
    self.uuid = uuid ?? UUID().uuidString
  }
}
