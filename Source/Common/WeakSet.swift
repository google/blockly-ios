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
public struct WeakSet<Element: AnyObject> {
  // MARK: - Properties

  /// An array representation of all objects in this set.
  public var all: [Element] {
    return _objects.allObjects
  }

  /// Wrapper of a set of weakly-referenced objects.
  private var _boxedObjects = WrapperBox<NSHashTable<Element>>(NSHashTable.weakObjects())
  /// Set of immutable objects
  private var _objects: NSHashTable<Element> {
    return _boxedObjects.unbox
  }
  /// Set of mutable objects
  private var _mutableObjects: NSHashTable<Element> {
    mutating get {
      if !isKnownUniquelyReferenced(&_boxedObjects) {
        // `_boxedObjects` is being referenced by another `WeakSet` struct (that must have been
        // created through a copied assignment). Create a copy of `_boxedObjects` so that both
        // structs now reference a different set of objects.
        _boxedObjects = WrapperBox(_objects.copy() as! NSHashTable)
      }
      return _boxedObjects.unbox
    }
  }

  // MARK: - Public

  /**
   Adds an object to the set.
   */
  public mutating func add(_ object: Element) {
    _mutableObjects.add(object)
  }

  /**
   Removes an object from the set.
   */
  public mutating func remove(_ object: Element) {
    _mutableObjects.remove(object)
  }

  /**
   Removes all objects from the set.
   */
  public mutating func removeAll() {
    _mutableObjects.removeAllObjects()
  }
}

extension WeakSet : Sequence {
  // MARK: - Sequence - Implementation

  public typealias Iterator = AnyIterator<Element>

  public func makeIterator() -> Iterator {
    var index = 0
    let allObjects = self.all

    // Create `AnyGenerator` with the closure used for retrieving the next element in the sequence
    return AnyIterator {
      if index < allObjects.count {
        let nextObject = allObjects[index]
        index += 1
        return nextObject
      }
      return nil
    }
  }
}
