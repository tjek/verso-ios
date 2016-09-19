#Verso

[![Version](https://img.shields.io/cocoapods/v/Verso.svg?style=flat)](http://cocoapods.org/pods/Verso)
[![License](https://img.shields.io/cocoapods/l/Verso.svg?style=flat)](http://cocoapods.org/pods/Verso)
[![Platform](https://img.shields.io/cocoapods/p/Verso.svg?style=flat)](http://cocoapods.org/pods/Verso)

A multi-paged image viewer for iOS.

### Requirements 
- iOS 8
 
## Installation


### CocoaPods
Verso is available through [CocoaPods](http://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod "Verso"
```

## Usage

Verso makes it easy to layout a horizontally scrolling book-like view, with multiple pages visible and zoomable at any one time.

### Spreads
An important concept within Verso is that of a **`Spread`**. 

You use spreads to collect and layout multiple pages together. You can think of a Spread as the pages you see when you open a book. It can contain 1 or more pages - for example if you opened a book to the middle a spread would contain a left and right page, while if you were looking at the first page there would only be one page in the spread.

In Verso, the datasource provides a `spread configuration`. This defines the properties (the page indexes, and other details) for all the spreads within the Verso. Basically, both page count and layout information is encoded in the class that is returned by the datasource.




## Author

Laurie Hufford, lh@shopgun.com /ShopGun

## License

Verso is available under the MIT license. See the LICENSE file for more info.
