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
import UIKit
import XCTest

extension XCTestCase {
  /**
   Assertion for testing that an expression throws an error of a given type.

   - Parameter message: [Optional] The message to display if the assertion fails.
   - Parameter file: [Optional] The file where the expression is being called.
   - Parameter line: [Optional] The line in the `file` where the expression is being called.
   - Parameter errorType: Asserts that the error thrown is of this type.
   - Parameter expression: The throwable expression
   */
  func BKYAssertThrow<T: NSError>(
    message: String? = nil, file: String = #file, line: UInt = #line, errorType: T.Type,
    expression: () throws -> Void)
  {
    do {
      try expression()
      self.recordFailureWithDescription(
        bky_failureDescription("Expression did not throw an error", message),
        inFile: file, atLine: line, expected: true)
    } catch let error {
      if error.dynamicType != errorType {
        let errorDescription =
          "Error type [\(errorType)] is not equal to [\(error.dynamicType)]"
        self.recordFailureWithDescription(
          bky_failureDescription(errorDescription, message),
          inFile: file, atLine: line, expected: true)
      }
    }
  }

  /**
   Assertion for testing that an expression does not throw an error.

   If the assertion passes, the result of the evaluated expression is returned.
   If not, `nil` is returned.

   - Parameter message: [Optional] The message to display if the assertion fails.
   - Parameter file: [Optional] The file where the expression is being called.
   - Parameter line: [Optional] The line in the `file` where the expression is being called.
   - Parameter expression: The throwable expression
   - Returns: The return value of the expression or `nil` if the expression could not be evaluated.
   */
  func BKYAssertDoesNotThrow<T>(
    message: String? = nil, file: String = #file, line: UInt = #line, expression: () throws -> T?)
    -> T?
  {
    do {
      return try expression()
    } catch {
      self.recordFailureWithDescription(
        bky_failureDescription("Expression threw an error", message), inFile: file, atLine: line,
        expected: true)
    }
    return nil
  }

  private func bky_failureDescription(
    description: String, _ message: String?, function: String = #function) -> String
  {
    let conciseFunctionName: String
    if let range = function.rangeOfString("(") {
      conciseFunctionName = function.substringToIndex(range.startIndex)
    } else {
      conciseFunctionName = function
    }
    let nonOptionalMessage = message ?? ""
    return "\(conciseFunctionName) failed: \(description) - \(nonOptionalMessage)"
  }
}
