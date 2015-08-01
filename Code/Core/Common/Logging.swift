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
In builds with a DEBUG symbol defined, prints a value's description to the console.
In non-DEBUG builds, this method does nothing.

- Parameter value: The value to print to the console.
- Parameter function: String to precede the value. By default, this is populated with the function
name that is executing this method.
*/
func bky_print<T>(value: T, function: String = __FUNCTION__) {
  #if DEBUG
    print("\(function): \(value)")
  #endif
}

/**
In builds with a DEBUG symbol defined, prints a value's debug description to the console.
In non-DEBUG builds, this method does nothing.

- Parameter value: The value to print to the console.
- Parameter function: String to precede the value. By default, this is populated with the function
name that is executing this method.
*/
func bky_debugPrint<T>(value: T, function: String = __FUNCTION__) {
  #if DEBUG
    debugPrint("\(function): \(value)")
  #endif
}
