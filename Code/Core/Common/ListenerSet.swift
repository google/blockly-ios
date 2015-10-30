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
Holds a list of "listener" objects where each object is weakly-referenced.
*/
public class ListenerSet<Listener: AnyObject> {
  /// Set of listeners, where each object is weakly-referenced
  private var _listeners = NSHashTable.weakObjectsHashTable()

  /// Returns an array of all listeners
  public var all: [Listener] {
    return _listeners.allObjects as! [Listener]
  }

  /**
  Adds a listener to the set.
  */
  public func add(listener: Listener) {
    _listeners.addObject(listener)
  }

  /**
  Removes a listener from the set.
  */
  public func remove(listener: Listener) {
    _listeners.removeObject(listener)
  }

  /**
  Executes a block of code for each listener in the set.
  
  - Parameter body: The block of code to execute
  */
  public func forEach(@noescape body: (Listener) throws -> ()) rethrows {
    for listener in self.all {
      try body(listener)
    }
  }
}
