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
   Reset the object to a fresh state, releasing and recycling any resources associated with this
   object.

   - note: This should not be called directly by clients. To recycle the object, it should be done
   via `objectPool.recycleObject(object)`.
   */
  func prepareForReuse()
}

// MARK: -

/**
Handles the management of recyclable objects.
*/
@objc(BKYObjectPool)
@objcMembers public final class ObjectPool: NSObject {
  // MARK: - Properties

  /// Keeps track of all recycled objects. Objects of the same type are keyed by their class name
  /// and stored in a cache.
  private let _recycledObjects = NSCache<NSString, NSMutableArray>()

  // MARK: - Public

  /**
  If a recycled object is available for re-use, that object is returned.

  If not, a new object of the given type is instantiated.


  - parameter type: The `Type` of object to retrieve.
  - note: Objects obtained through this method should be recycled through `recycleObject(:)`.
  - returns: An object of the given `type`.
  */
  public func object<T>(forType type: T.Type) -> T where T: NSObject {
    let className = String(describing: type) as NSString

    if let list = _recycledObjects.object(forKey: className), list.count > 0,
      let recycledObject = list.lastObject as? T
    {
      list.removeLastObject()
      return recycledObject
    }

    // Couldn't find a recycled object, create a new instance
    return type.init()
  }

  /**
   Calls `prepareForReuse()` on the object and stores it for re-use later.

   - parameter object: The object to recycle.
   - note: Objects recycled through this method should be obtained through `objectForType(:)` or
   `recyclableObjectForType(:)`.
   */
  public func recycleObject(_ object: Recyclable) {
    // Prepare the object for re-use
    object.prepareForReuse()

    let className = String(describing: type(of: object)) as NSString

    if let list = _recycledObjects.object(forKey: className) {
      // Append to the array
      list.add(object)
    } else {
      // Create a new array. Because the array will be constantly changing, it is faster to use an
      // NSMutableArray instead of an Array<Recyclable> here, as any changes to the array will be
      // made by reference instead of by value.
      _recycledObjects.setObject(NSMutableArray(array: [object]), forKey: className)
    }
  }

  /**
   Removes all recycled objects from memory.
   */
  public func removeAllRecycledObjects() {
    _recycledObjects.removeAllObjects()
  }
}
