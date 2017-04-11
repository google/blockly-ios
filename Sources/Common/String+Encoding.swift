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
 Contains helper methods for encoding Strings.
 */
extension String {
  /**
   Escapes the current string so it can be used as a JavaScript parameter when calling a JS method
   using UIWebView/WKWebView's `evaluateJavaScript(...)`.

   - returns: The escaped JavaScript string.
   */
  public func bky_escapedJavaScriptParameter() -> String {
    // Note: `\b` and `\f` aren't included here because they aren't special String characters in
    // Swift (even though they are special in JS)
    return self.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\'", with: "\\'")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\t", with: "\\t")
  }
}
