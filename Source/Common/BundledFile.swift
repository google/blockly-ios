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
 Class defining where to find a local file in an associated `Bundle`.
 */
@objc(BKYBundledFile)
public class BundledFile: NSObject {
  let path: String
  let bundle: Bundle

  /**
   Objective-C style factory method for bundled file. This method will always use the default
   bundle.

   - Parameter path: The path to a local file.
   - Returns: The new bundled file.
   */
  public static func file(path: String) -> BundledFile {
    return file(path: path, bundle: Bundle.main)
  }

  /**
   Objective-C style factory method for bundled file.

   - Parameter path: The path to a local file.
   - Parameter bundle: The bundle in which to find the local file.
   - Returns: The new bundled file.
   */
  public static func file(path: String, bundle: Bundle) -> BundledFile {
    return BundledFile(path: path, bundle: bundle)
  }

  /**
   Initializes a bundled file. This initializer will always use the default bundle.

   - Parameter path: The path to a local file.
   */
  public convenience init(path: String) {
    self.init(path: path, bundle: Bundle.main)
  }

  /**
   Initializes the code generator bundled file.

   - Parameter path: The path to a local file
   - Parameter bundle: The bundle in which to find the local file.
   */
  public init(path: String, bundle: Bundle) {
    self.path = path
    self.bundle = bundle
  }
}
