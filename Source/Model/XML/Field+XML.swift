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
import AEXML

// MARK: - XML Serialization

extension Field {
  // MARK: - Internal

  /**
   Creates an XML element for this field.

   - returns: An XML element representing this field. For those fields that cannot be represented by
   XML, nil is returned instead.
   - throws:
   `BlocklyError`: Thrown if there was an error serializing this field.
   */
  internal func toXMLElement() throws -> AEXMLElement? {
    if let serializedText = try self.serializedText() {
      return AEXMLElement(name: XMLConstants.TAG_FIELD,
                          value: serializedText, attributes: [XMLConstants.ATTRIBUTE_NAME: name])
    } else {
      return nil
    }
  }
}
