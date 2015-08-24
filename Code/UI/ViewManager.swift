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
Handles the management of recyclable views.
*/
@objc(BKYViewManager)
public class ViewManager: NSObject {

  public static let sharedInstance = ViewManager()

  public func blockViewForLayout(layout: BlockLayout) -> BlockView {
    // TODO:(vicng) Implement a lookup and caching mechanism
    let blockView = BlockView()
    blockView.layout = layout
    return blockView
  }

  public func fieldViewForLayout(layout: FieldLayout) -> UIView? {
    // TODO:(vicng) Implement a lookup and caching mechanism
    if let fieldLabelLayout = layout as? FieldLabelLayout {
      let fieldLabelView = FieldLabelView()
      fieldLabelView.layout = fieldLabelLayout
      return fieldLabelView
    }
    return nil
  }

  public func bezierPathView() -> BezierPathView {
    // TODO:(vicng) Implement a caching mechanism
    return BezierPathView()
  }
}
