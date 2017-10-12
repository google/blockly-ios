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

   - parameter message: [Optional] The message to display if the assertion fails.
   - parameter file: [Optional] The file where the expression is being called.
   - parameter line: [Optional] The line in the `file` where the expression is being called.
   - parameter errorType: Asserts that the error thrown is of this type.
   - parameter expression: The throwable expression
   */
  func BKYAssertThrow<T: NSError>(
    _ message: String? = nil, file: String = #file, line: Int = #line, errorType: T.Type,
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

   - parameter message: [Optional] The message to display if the assertion fails.
   - parameter file: [Optional] The file where the expression is being called.
   - parameter line: [Optional] The line in the `file` where the expression is being called.
   - parameter expression: The throwable expression
   - returns: The return value of the expression or `nil` if the expression could not be evaluated.
   */
  func BKYAssertDoesNotThrow<T>(
    message: String? = nil, file: String = #file, line: Int = #line,
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

  fileprivate func bky_failureDescription(
    _ description: String, _ message: String?, _ error: Error?, function: String = #function)
    -> String
  {
    let conciseFunctionName: String
    if let range = function.range(of: "(") {
      conciseFunctionName = String(function[..<range.lowerBound])
    } else {
      conciseFunctionName = function
    }
    var bonusDescription = ""
    if let message = message {
      bonusDescription += " - \(message)"
    }
    if let error = error {
      bonusDescription += " - \(error)"
    }
    return "\(conciseFunctionName) failed: \(description) \(bonusDescription)"
  }
}
