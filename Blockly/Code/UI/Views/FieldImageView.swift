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
 View for rendering a `FieldImageLayout`.
 */
@objc(BKYFieldImageView)
public class FieldImageView: FieldView {
  // MARK: - Properties

  /// Layout object to render
  public var fieldImageLayout: FieldImageLayout? {
    return layout as? FieldImageLayout
  }

  /// The image to render
  private var imageView: UIImageView!

  // MARK: - Initializers

  public required init() {
    self.imageView = UIImageView()
    super.init(frame: CGRectZero)

    imageView.frame = self.bounds
    imageView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    imageView.contentMode = .ScaleAspectFill
    addSubview(imageView)
  }

  public required init?(coder aDecoder: NSCoder) {
    bky_assertionFailure("Called unsupported initializer")
    super.init(coder: aDecoder)
  }

  // MARK: - Super

  public override func internalRefreshView(forFlags flags: LayoutFlag) {
    guard let layout = self.layout as? FieldImageLayout else {
      return
    }

    if flags.intersectsWith(Layout.Flag_NeedsDisplay) {
      loadImageURL(layout.fieldImage.imageURL)
    }
  }

  public override func internalPrepareForReuse() {
    self.frame = CGRectZero
    self.imageView.image = nil
  }

  // MARK: - Private

  private func loadImageURL(imageURL: String) {
    // Load image in the background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
      var image: UIImage?
      if let url = NSURL(string: imageURL) {
        // Try loading image from the web
        do {
          let data = try NSData(contentsOfURL: url, options: .DataReadingMappedAlways)
          image = UIImage(data: data)
        } catch {
          // Do nothing
        }
      }
      if image == nil {
        // Try loading from local file
        image = ImageLoader.loadImage(named: imageURL, forClass: FieldImageView.self)
      }

      if image != nil {
        // Update the image back on the main thread
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
          self.imageView.image = image
        })
      }
    }
  }
}

// MARK: - FieldLayoutMeasurer implementation

extension FieldImageView: FieldLayoutMeasurer {
  public static func measureLayout(layout: FieldLayout, scale: CGFloat) -> CGSize {
    guard let fieldLayout = layout as? FieldImageLayout else {
      bky_assertionFailure("Cannot measure layout of type [\(layout.dynamicType.description)]. " +
        "Expected type [FieldImageLayout].")
      return CGSizeZero
    }

    return fieldLayout.workspaceLayout.viewSizeFromWorkspaceSize(fieldLayout.fieldImage.size)
  }
}
