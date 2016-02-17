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
  // MARK: - Public

  /**
   Creates an XML element for this field.

   - Returns: An XML element representing this field. For those fields that cannot be represented by
   XML, nil is returned instead.
   - Throws:
   `BlocklyError`: Thrown if there was an error serializing this field.
   */
  public func toXML() throws -> AEXMLElement? {
    if (self is FieldLabel) || (self is FieldImage) {
      return nil
    }

    return AEXMLElement("field", value: try self.serializedText(), attributes: ["name": self.name])
  }
}
