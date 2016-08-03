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
 Class for a `FieldImage`-based `Layout`.
 */
@objc(BKYFieldImageLayout)
public class FieldImageLayout: FieldLayout {

  // MARK: - Properties

  /// The `FieldImage` that backs this layout
  public let fieldImage: FieldImage

  /// The size of the image, expressed as a Workspace coordinate system size
  public var size: WorkspaceSize {
    return fieldImage.size
  }

  // MARK: - Initializers

  public init(fieldImage: FieldImage, engine: LayoutEngine, measurer: FieldLayoutMeasurer.Type) {
    self.fieldImage = fieldImage
    super.init(field: fieldImage, engine: engine, measurer: measurer)

    fieldImage.delegate = self
  }

  // MARK: - Super

  // TODO:(#114) Remove `override` once `FieldLayout` is deleted.
  public override func didUpdateField(field: Field) {
    // Perform a layout up the tree
    updateLayoutUpTree()
  }

  // MARK: - Public

  /**
   Asynchronously loads this layout's image in the background and executes a callback on the main
   thread with the loaded image.

   - Parameter completion: The callback method that will be executed on completion of this method.
   The `image` parameter of the callback method contains the `UIImage` that was loaded. If it is
   `nil`, the image could not be loaded.
   */
  public func loadImage(completion completion: ((image: UIImage?) -> Void)) {
    // Load image in the background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
      // Try loading from a local file first
      let imageURL = self.fieldImage.imageURL
      var image = ImageLoader.loadImage(named: imageURL, forClass: FieldImageLayout.self)

      // Try loading image from the web (if we couldn't load from local)
      if image == nil,
        let url = NSURL(string: imageURL)
      {
        do {
          let data = try NSData(contentsOfURL: url, options: .DataReadingMappedAlways)
          image = UIImage(data: data)
        } catch {
          // Do nothing
        }
      }

      // Execute the callback on the main thread
      dispatch_async(dispatch_get_main_queue(), { () -> Void in
        completion(image: image)
      })
    }
  }
}
