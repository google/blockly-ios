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
 Holds a set of objects of a specific type, where each object is weakly-referenced.

 - NOTE: This object should not be used in code that requires high performance (e.g. in render
 operations), as it is slow.
 */
public struct WeakSet<SomeObject: AnyObject> {
  /// Set of objects, where each object is weakly-referenced
  private let _objects = NSHashTable.weakObjectsHashTable()

  /// Returns an array of all objects
  public var all: [SomeObject] {
    return _objects.allObjects as! [SomeObject]
  }

  /**
   Adds an object to the set.
   */
  public func add(object: SomeObject) {
    _objects.addObject(object)
  }

  /**
   Removes an object from the set.
   */
  public func remove(object: SomeObject) {
    _objects.removeObject(object)
  }
}

// MARK: - SequenceType Implementation

extension WeakSet : SequenceType {
  public typealias Generator = AnyGenerator<SomeObject>

  public func generate() -> Generator {
    var index = 0
    let allObjects = self.all

    // Create `AnyGenerator` with the closure used for retrieving the next element in the sequence
    return AnyGenerator {
      if index < allObjects.count {
        let nextObject = allObjects[index]
        index += 1
        return nextObject
      }
      return nil
    }
  }
}
