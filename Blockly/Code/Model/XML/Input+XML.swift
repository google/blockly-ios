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

extension Input {
  // MARK: - Public

  /**
   Creates XML elements for this input and all of its descendants.
  
   - Returns: A list of XML elements.
   - Throws:
   `BlocklyError`: Thrown if there was an error serializing this input or any of its descendants.
   */
  public func toXML() throws -> [AEXMLElement] {
    var xmlElements: [AEXMLElement]
    switch self.type {
    case InputType.Dummy:
      xmlElements = []
    case InputType.Value:
      xmlElements = try toXMLWithName("value")
    case InputType.Statement:
      xmlElements = try toXMLWithName("statement")
    }

    // Create xml elements for each field
    for field in self.fields {
      if let fieldXML = try field.toXML() {
        xmlElements.append(fieldXML)
      }
    }

    return xmlElements
  }

  // MARK: - Private

  private func toXMLWithName(elementName: String) throws -> [AEXMLElement] {
    guard let connectedBlock = self.connectedBlock else {
      // No block connected, don't include any xml for this input
      return []
    }

    var xmlElements = [AEXMLElement]()

    // Create xml element for the input
    let xml = AEXMLElement(elementName, value: nil, attributes: ["name": self.name])
    xml.addChild(try connectedBlock.toXML())
    xmlElements.append(xml)

    return xmlElements
  }
}
