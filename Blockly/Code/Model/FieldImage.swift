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
    didSet {
      if !self.editable {
        self.size = oldValue
      }
      if self.size != oldValue {
        delegate?.didUpdateField(self)
      }
    }
  }
  public var imageURL: String {
    didSet {
      if !self.editable {
        self.imageURL = oldValue
      }
      if self.imageURL != oldValue {
        delegate?.didUpdateField(self)
      }
    }
  }
  public var altText: String

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
}
