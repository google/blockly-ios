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
    _ message: String? = nil, file: String = #file, line: UInt = #line, errorType: T.Type,
    expression: () throws -> Void)
  {
    do {
      try expression()
      recordFailure(
        withDescription: bky_failureDescription("Expression did not throw an error", message, nil),
        inFile: file, atLine: line, expected: true)
    } catch let error {
      if type(of: error) != errorType {
        let errorDescription =
          "Error type [\(errorType)] is not equal to [\(type(of: error))]"
        recordFailure(
          withDescription: bky_failureDescription(errorDescription, message, error),
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
    _ message: String? = nil, _ file: String = #file, _ line: UInt = #line,
    _ expression: () throws -> T?) -> T?
  {
    do {
      return try expression()
    } catch let error {
      recordFailure(
        withDescription: bky_failureDescription("Expression threw an error", message, error),
        inFile: file, atLine: line, expected: true)
    }
    return nil
  }

  /**
   Assertion for testing that an expression does not throw an error.

   If the assertion passes, the result of the evaluated expression is returned.
   If not, `nil` is returned.

   Usage:
   ```
   if let variable = BKYAssertDoesNotThrow({ try SomeObject() }) {
   }
   ```

   - Parameter expression: The throwable expression
   - Parameter message: [Optional] The message to display if the assertion fails.
   - Parameter file: [Optional] The file where the expression is being called.
   - Parameter line: [Optional] The line in the `file` where the expression is being called.
   - Returns: The return value of the expression or `nil` if the expression could not be evaluated.
   - Note: This version of `BKYAssertDoesNotThrow` was created primarily for use in
   `if let` or `guard let` assignments. It is functionally equivalent to the other version of
   `BKYAssertDoesNotThrow`.
   */
  func BKYAssertDoesNotThrow<T>(
    _ expression: () throws -> T?, _ message: String? = nil, _ file: String = #file,
    _ line: UInt = #line) -> T?
  {
    do {
      return try expression()
    } catch let error {
      recordFailure(
        withDescription: bky_failureDescription("Expression threw an error", message, error),
        inFile: file, atLine: line, expected: true)
    }
    return nil
  }

  fileprivate func bky_failureDescription(
    _ description: String, _ message: String?, _ error: Error?, function: String = #function)
    -> String
  {
    let conciseFunctionName: String
    if let range = function.range(of: "(") {
      conciseFunctionName = function.substring(to: range.lowerBound)
    } else {
      conciseFunctionName = function
    }
    var bonusDescription = ""
    bonusDescription += (message != nil ? " - \(message)" : "")
    bonusDescription += (error != nil ? " - \(error)" : "")
    return "\(conciseFunctionName) failed: \(description) \(bonusDescription)"
  }
}
