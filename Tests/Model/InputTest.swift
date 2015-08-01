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

@testable import Blockly
import XCTest

class InputTest: XCTestCase {

  var block: Block!

  override func setUp() {
    let workspace = Workspace(isFlyout: false, isRTL: true)
    let builder = Block.Builder(identifier: "Test", name: "name", workspace: workspace)
    block = builder.build()

    super.setUp()
  }

  // TODO:(vicng) Implement tests

  // MARK: - inputFromJSON

  func testInputFromJSON_valid() {
  }
}
