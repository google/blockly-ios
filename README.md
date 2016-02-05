## Installation

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate Blockly into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "RoboErikG/blocklypp"
```

Run `carthage update` to build the framework and drag the built `Blockly.framework` into your Xcode project.

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 0.39.0+ is required to build Blockly.

To integrate Blockly into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

pod 'Blockly', :git => 'https://github.com/RoboErikG/blocklypp.git'
```

Then, run the following command:

```bash
$ pod install
```
