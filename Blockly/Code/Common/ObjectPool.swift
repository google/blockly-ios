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
Defines a protocol for objects that can be recycled for re-use.
*/
@objc(BKYRecyclable)
public protocol Recyclable: class {
  /**
  Instantiates a new instance of the recyclable class.
  */
  init()

  /**
  Reset the object to a fresh state, releasing and recycling any resources associated with this
  object.

  - Note: This should not be called directly by clients. To recycle the object, it should be done
  via `objectPool.recycleObject(object)`.
  */
  func prepareForReuse()
}

// MARK: -

/**
Handles the management of recyclable objects.
*/
@objc(BKYObjectPool)
public class ObjectPool: NSObject {
  // MARK: - Properties

  /// Keeps track of all recycled objects. Objects of the same type are keyed by their class name
  /// and stored in an array.
  private var _recycledObjects = [String: Array<Recyclable>]()

  // MARK: - Public

  /**
  If a recycled object is available for re-use, that object is returned.

  If not, a new object of the given `Recyclable.Type` is instantiated.

  - Parameter type: The type of `Recyclable` object to retrieve.
  - Note: Objects obtained through this method should be recycled through `recycleObject(:)`.
  - Returns: An object of the given type.
  */
  public func objectForType<T: Recyclable>(type: T.Type) -> T {
    // Force cast Recyclable back into the concrete "T" type
    return recyclableObjectForType(type) as! T
  }

  /**
  If a recycled object is available for re-use, that object is returned.

  If not, a new object of the given `Recyclable.Type` is instantiated.

  - Parameter type: The type of `Recyclable` object to retrieve.
  - Note: Objects obtained through this method should be recycled through `recycleObject(:)`.
  - Warning: This method should only be called by Objective-C code. Swift code should use
  `objectForType(type:)` instead.
  - Returns: An object of the given type.
  */
  public func recyclableObjectForType(type: Recyclable.Type) -> Recyclable {
    let className = String(type)

    // Note: _recycledObjects[className] is purposely not assigned to a variable here since that
    // means we will end up modifying a copy of the array, and not the original array
    if (_recycledObjects[className]?.count ?? 0) > 0 {
      return _recycledObjects[className]!.removeLast()
    }

    // Couldn't find a recycled object, create a new instance
    return type.init()
  }

  /**
  Calls `prepareForReuse()` on the object and stores it for re-use later.

  - Parameter object: The object to recycle.
  - Note: Objects recycled through this method should be obtained through `objectForType(:)` or
  `recyclableObjectForType(:)`.
  */
  public func recycleObject(object: Recyclable) {
    // Prepare the object for re-use
    object.prepareForReuse()

    let className = String(object.dynamicType)

    // Note: _recycledObjects[className] is purposely not assigned to a variable here since that
    // means we will end up modifying a copy of the array, and not the original array
    if _recycledObjects[className] != nil {
      // Append to the array
      _recycledObjects[className]!.append(object)
    } else {
      // Create a new array
      _recycledObjects[className] = [object]
    }
  }

  // TODO:(#42) Add a method to prune the pool if it gets too big.
}
