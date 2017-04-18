/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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

import Blockly
import JavaScriptCore
import UIKit

/**
 Runs JavaScript code.
 */
class CodeRunner {
  /// The JS context used for running the JS code.
  var context: JSContext!

  /// A background thread used for executing the JS code.
  let jsThread = DispatchQueue(label: "jsContext")

  init() {
    // Instantiate the JS context on a background thread.
    jsThread.async {
      self.context = JSContext()
      self.context?.exceptionHandler = { context, exception in
        let error = exception?.description ?? "unknown error"
        print("JS Error: \(error)")
      }

      // Expose `MusicMaker` as a bridged Javascript object
      self.context.setObject(MusicMaker.self, forKeyedSubscript: "MusicMaker" as NSString)
    }
  }

  public func runJavascriptCode(_ code: String, onFinish: @escaping () -> ()) {
    // Execute JS Code on the background thread
    jsThread.async {
      self.context.evaluateScript("var musicMaker = MusicMaker.create();" + code)

      DispatchQueue.main.async {
        onFinish()
      }
    }
  }
}

@objc protocol MusicMakerJSExports: JSExport {
  static func create() -> MusicMaker

  func playSound(_ assetName: String, _ blockID: String)
}

@objc class MusicMaker: NSObject, MusicMakerJSExports {
  let playSoundCondition = NSCondition()
  var playedSound = false
  var audioPlayer: AudioPlayer?

  static func create() -> MusicMaker {
    return MusicMaker()
  }

  func playSound(_ file: String, _ blockID: String) {
    guard let player = AudioPlayer(file: file) else {
      return
    }

    player.onFinish = { successfully in
      self.audioPlayer = nil
      self.notifyCondition(self.playSoundCondition, predicate: &self.playedSound)
    }

    if player.play() {
      audioPlayer = player
      wait(forCondition: self.playSoundCondition, predicate: &self.playedSound)
    }
  }

  func wait(forCondition condition: NSCondition, predicate: inout Bool) {
    condition.lock()
    while (!predicate) {
      condition.wait()
    }
    predicate = false
    condition.unlock()
  }

  func notifyCondition(_ condition: NSCondition, predicate: inout Bool) {
    condition.lock()
    predicate = true
    condition.signal()
    condition.unlock()
  }
}
