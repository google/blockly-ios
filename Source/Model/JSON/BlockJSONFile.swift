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

extension BlockJSONFile {
  /// List of all file locations that this value specifies
  public var fileLocations: [String] {
    var fileLocations = [String]()

    if contains(.colorDefault) {
      fileLocations.append("Default/colour_blocks.json")
    }
    if contains(.listDefault) {
      fileLocations.append("Default/list_blocks.json")
    }
    if contains(.logicDefault) {
      fileLocations.append("Default/logic_blocks.json")
    }
    if contains(.loopDefault) {
      fileLocations.append("Default/loop_blocks.json")
    }
    if contains(.mathDefault) {
      fileLocations.append("Default/math_blocks.json")
    }
    if contains(.textDefault) {
      fileLocations.append("Default/text_blocks.json")
    }
    if contains(.variableDefault) {
      fileLocations.append("Default/variable_blocks.json")
    }

    return fileLocations
  }

  /// Dictionary mapping block names to mutators, for all blocks specified under
  /// `self.fileLocations`
  public var blockMutators: [String: Mutator] {
    var mutators = [String: Mutator]()

    if contains(.logicDefault) {
      mutators["controls_if"] = MutatorIfElse()
    }

    return mutators
  }
}
