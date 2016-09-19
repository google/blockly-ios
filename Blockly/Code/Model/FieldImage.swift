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
public final class FieldImage: Field {
  // MARK: - Properties

  public var size: WorkspaceSize {
    didSet { didSetEditableProperty(&size, oldValue) }
  }
  public var imageURL: String {
    didSet { didSetEditableProperty(&imageURL, oldValue) }
  }
  public var altText: String {
    didSet { didSetEditableProperty(&altText, oldValue) }
  }

  // MARK: - Initializers

  public init(
    name: String, imageURL: String, size: WorkspaceSize, altText: String) {
      self.imageURL = imageURL
      self.size = size
      self.altText = altText

      super.init(name: name)
  }

  // MARK: - Super

  public override func copyField() -> Field {
    return FieldImage(name: name, imageURL: imageURL, size: size, altText: altText)
  }

  public override func setValueFromSerializedText(_ text: String) throws {
    throw BlocklyError(.illegalState, "Image field cannot be set from string.")
  }

  public override func serializedText() throws -> String? {
    // Return nil. Images shouldn't be serialized.
    return nil
  }
}
