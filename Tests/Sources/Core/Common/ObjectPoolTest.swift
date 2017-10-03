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

/** Tests for the `ObjectPool` class. */
class ObjectPoolTest: XCTestCase {
  func testRecycler() {
    let pool = ObjectPool()

    let cokeCans = [CokeCan](repeating: CokeCan(), count: 5)

    // Recycle a bunch of cans
    for cokeCan in cokeCans {
      pool.recycleObject(cokeCan)
    }

    // Check they were recycled
    for _ in 0 ..< cokeCans.count {
      let recycledCan = pool.object(forType: CokeCan.self)
      XCTAssertTrue(recycledCan.recycled)
    }

    // Get a new one, which should not have been recycled
    let freshOne = pool.object(forType: CokeCan.self)
    XCTAssertFalse(freshOne.recycled)
  }
}

class CokeCan: NSObject, Recyclable {
  var recycled = false

  required override init() {
    super.init()
  }

  func prepareForReuse() {
    recycled = true
  }
}
