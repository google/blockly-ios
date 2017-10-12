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
 An image field used for titles, labels, etc.
 */
@objc(BKYFieldImage)
@objcMembers public final class FieldImage: Field {
  // MARK: - Properties

  /// The `WorkspaceSize` of this field.
  public var size: WorkspaceSize {
    didSet { didSetProperty(size, oldValue) }
  }
  /**
   The location of the image in this field.

   Specifies the location of a local image resource, either as an image asset name or a location
   relative to the main resource bundle of the app. As a fallback, this can specify the location
   of a URL web image to fetch.
   */
  public var imageLocation: String {
    didSet { didSetProperty(imageLocation, oldValue) }
  }
  /// The alt text for this field.
  public var altText: String {
    didSet { didSetProperty(altText, oldValue) }
  }
  /// Flag determining if this image should be flipped horizontally in RTL rendering.
  public var flipRtl: Bool {
    didSet { didSetProperty(flipRtl, oldValue) }
  }

  // MARK: - Initializers

  /**
   Initializes the image field.

   - parameter name: The name of this field.
   - parameter imageLocation: The location of the image in this field. Specifies the location of a
     local image resource, either as an image asset name or a location relative to the main resource
     bundle of the app. As a fallback, this can specify the location of a URL web image to fetch.
   - parameter altText: The alt text for this field.
   - parameter flipRtl: Flag determining if this image should be flipped horizontally in RTL
   rendering.
   */
  public init(
    name: String, imageLocation: String, size: WorkspaceSize, altText: String, flipRtl: Bool) {
      self.imageLocation = imageLocation
      self.size = size
      self.altText = altText
      self.flipRtl = flipRtl

      super.init(name: name)
  }

  // MARK: - Super

  public override func copyField() -> Field {
    return FieldImage(
      name: name,
      imageLocation: imageLocation,
      size: size,
      altText: altText,
      flipRtl: flipRtl)
  }

  public override func setValueFromSerializedText(_ text: String) throws {
    throw BlocklyError(.illegalState, "Image field cannot be set from string.")
  }

  public override func serializedText() throws -> String? {
    // Return nil. Images shouldn't be serialized.
    return nil
  }
}
