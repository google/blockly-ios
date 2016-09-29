//
//  BundledFile.swift
//  Blockly
//
//  Created by Cory Diers on 9/29/16.
//  Copyright © 2016 Google Inc. All rights reserved.
//

import Foundation

/**
 Tuple defining where to find a local file.
 */
@objc(BKYBundledFile)
public class BundledFile: NSObject {
  let path: String
  let bundle: Bundle?

  /**
   Objective-C style factory method for bundled file. This method will always use the default
   bundle.

   - Parameter path: The path to a local file.
   - Returns: The new bundled file.
   */
  public static func bundledFile(path: String) -> BundledFile {
    return bundledFile(path: path, bundle: nil)
  }

  /**
   Objective-C style factory method for bundled file.

   - Parameter path: The path to a local file.
   - Parameter bundle: The bundle in which to find the local file. If nil is specified, the main
     bundle should be used.
   - Returns: The new bundled file.
   */
  public static func bundledFile(path: String, bundle: Bundle?) -> BundledFile {
    return BundledFile(path: path, bundle: bundle)
  }

  /**
   Initializes a bundled file. This initializer will always use the default bundle.

   - Parameter file: The path to a local file.
   */
  public convenience init(path: String) {
    self.init(path: path, bundle: nil)
  }

  /**
   Initializes the code generator bundled file.

   - Parameter path: The path to a local file
   - Parameter bundle: The bundle in which to find the local file. If nil is specified, the main
     bundle should be used.
   */
  public init(path: String, bundle: Bundle?) {
    self.path = path
    self.bundle = bundle
  }
}
