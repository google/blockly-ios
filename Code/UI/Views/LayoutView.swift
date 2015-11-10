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
Abstract class for rendering a `UIView` backed by a `Layout`.
*/
public class LayoutView: UIView {

  // MARK: - Properties

  /// Layout object to render
  public var layout: Layout? {
    didSet {
      if layout != oldValue {
        oldValue?.delegate = nil
        layout?.delegate = self

        if layout != nil {
          refreshView()
        } else {
          prepareForReuse()
        }
      }
    }
  }

  // MARK: - Abstract

  /**
  Refreshes the view based on the state of the current layout.
  */
  public func internalRefreshView() {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
  }

  /**
  Prepares this view to be re-used in the future.
  */
  public func internalPrepareForReuse() {
    bky_assertionFailure("\(__FUNCTION__) needs to be implemented by a subclass")
  }

  // MARK: - Public

  /**
  Refreshes the view based on the current layout.
  */
  public func refreshView() {
    refreshPosition()
    internalRefreshView()
  }

  /**
  Refreshes `frame` based on the state of the current `layout`.
  */
  public func refreshPosition() {
    guard let layout = self.layout else {
      return
    }

    self.frame = layout.viewFrame
  }
}

// MARK: - Recyclable implementation

extension LayoutView: Recyclable {
  public func prepareForReuse() {
    removeFromSuperview()
    self.layout = nil

    internalPrepareForReuse()
  }
}

// MARK: - LayoutDelegate implementation

extension LayoutView: LayoutDelegate {
  public func layoutDisplayChanged(layout: Layout) {
    refreshView()
  }

  public func layoutPositionChanged(layout: Layout) {
    refreshPosition()
  }
}
