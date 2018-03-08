Pod::Spec.new do |s|
  s.name             = 'Verso'
  s.version          = '1.0.0'
  s.summary          = 'A multi-paged image viewer for iOS'

  s.description      = <<-DESC
Verso makes it easy to implement a flexible multi-page book-like layout.
                       DESC

  s.homepage         = 'https://github.com/shopgun/verso-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = "ShopGun"
  s.social_media_url   = "http://twitter.com/ShopGun"
  s.source           = { :git => 'https://github.com/shopgun/verso-ios.git', :tag => "v" + s.version.to_s }

  s.platform         = :ios, "8.0"
  s.swift_version    = "4.0"

  s.source_files     = 'Sources/**/*'

  s.frameworks       = 'UIKit'

end
