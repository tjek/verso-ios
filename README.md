#Verso

[![Version](https://img.shields.io/cocoapods/v/Verso.svg?style=flat)](http://cocoapods.org/pods/Verso)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/cocoapods/l/Verso.svg?style=flat)](http://cocoapods.org/pods/Verso)
[![Platform](https://img.shields.io/cocoapods/p/Verso.svg?style=flat)](http://cocoapods.org/pods/Verso)

A multi-paged image viewer for iOS. 

Verso makes it easy to layout a horizontally scrolling book-like view, with multiple pages visible and zoomable at any one time.

## Requirements

- iOS 9.3+
- Swift 5.0+

## Installation

### CocoaPods
Verso is available through [CocoaPods](http://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
use_frameworks!
pod "Verso"
```

Then, run the following command:

```bash
$ pod install
```


### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate Verso into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "Tjek/Verso"
```

Run `carthage update` to build the framework and drag the built `Verso.framework` into your Xcode project.

---

## Usage


### Spreads
An important concept within Verso is that of a **Spread**. 

You use spreads to collect and layout multiple pages together. You can think of a Spread as the pages you see when you open a book. It can contain 1 or more pages - for example if you opened a book to the middle a spread would contain a left and right page, while if you were looking at the first page there would only be one page in the spread.

In Verso, the datasource provides a `spread configuration`. This defines the properties (the page indexes, and other details) for all the spreads within the Verso. Basically, both page count and layout information is encoded in the class that is returned by the datasource.




## Author

Laurie Hufford (lh@tjek.com)

## License

Verso is available under the MIT license. See the LICENSE file for more info.
