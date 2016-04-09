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

// MARK: - DefaultLayoutEngine Class

/**
 A subclass implementation of `LayoutEngine` to distinguish properties specific to the default
 layout implementation.
 */
@objc(BKYDefaultLayoutEngine)
public class DefaultLayoutEngine: LayoutEngine {
  // MARK: - Properties

  /// Set of config properties specific to elements using a `DefaultLayoutEngine`.
  public let defaultConfig: DefaultLayoutEngineConfig//DefaultLayoutEngine.DefaultConfig

  // MARK: - Initializers

  public init(defaultConfig: DefaultLayoutEngineConfig = DefaultLayoutEngineConfig(), rtl: Bool? = nil)
  {
    self.defaultConfig = defaultConfig
    super.init(config: defaultConfig, rtl: rtl)

    self.defaultConfig.engine = self
  }
}

// MARK: - DefaultLayoutEngineConsumer Protocol

/**
 Convenience protocol for `Layout` instances that set their `engine` property to a
 `DefaultLayoutEngine` instance. This protocol makes it easier for these `Layout` instances to
 access the default engine and config.
 */
public protocol DefaultLayoutEngineConsumer: class {
  var engine: LayoutEngine { get }
}

extension DefaultLayoutEngineConsumer {
  /// Convenience property for accessing `self.engine` as a `DefaultLayoutEngine`
  var defaultEngine: DefaultLayoutEngine {
    return self.engine as! DefaultLayoutEngine
  }

  /// Convenience property for accessing `self.defaultEngine.defaultConfig`
  var defaultConfig: DefaultLayoutEngineConfig {
    return self.defaultEngine.defaultConfig
  }
}