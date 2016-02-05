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

@objc(BKYJSONHelper)
public final class JSONHelper: NSObject {
  // MARK: - Public

  /**
  Convenience method for retrieving a JSON object from a String.

  - Parameter jsonString: The JSON string
  - Returns: Either a Dictionary<String, AnyObject> or Array<AnyObject>
  */
  public static func JSONObjectFromString(jsonString: String) throws -> AnyObject {
    guard
      let jsonData =
        jsonString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) else
    {
      throw BlocklyError(.JSONParsing, "Could not convert json to NSData:\n\(jsonString)")
    }

    return try NSJSONSerialization.JSONObjectWithData(
      jsonData, options:NSJSONReadingOptions(rawValue: 0))
  }

  /**
  Convenience method for retrieving a JSON dictionary from a String.

  - Parameter jsonString: A valid JSON string dictionary
  - Returns: The JSON dictionary
  */
  public static func JSONDictionaryFromString(jsonString: String) throws
    -> Dictionary<String, AnyObject>
  {
    // Parse jsonString into json dictionary
    guard let json = try JSONObjectFromString(jsonString) as? Dictionary<String, AnyObject> else {
      throw BlocklyError(.JSONInvalidTypecast,
        "Could not convert AnyObject to Dictionary<String, AnyObject>")
    }
    return json
  }

  /**
  Convenience method for retrieving a JSON array from a String.

  - Parameter jsonString: A valid JSON string array
  - Returns: The JSON array
  */
  public static func JSONArrayFromString(jsonString: String) throws -> [AnyObject] {
    // Parse jsonString into json array
    guard let json = try JSONObjectFromString(jsonString) as? [AnyObject] else {
      throw BlocklyError(.JSONInvalidTypecast, "Could not convert AnyObject to [AnyObject]")
    }
    return json
  }
}
