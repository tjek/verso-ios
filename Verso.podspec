Pod::Spec.new do |s|
  s.name             = 'Verso'
  s.version          = '1.0.0'
  s.summary          = 'A multi-paged image viewer for iOS'

  s.description      = <<-DESC
Verso makes it easy to implement a flexible multi-page book-like layout.
                       DESC

  s.homepage         = 'https://github.com/shopgun/verso-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Laurie Hufford' => 'lh@shopgun.com' }
  s.source           = { :git => 'https://github.com/shopgun/verso-ios.git', :tag => "v" + s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'Sources/**/*'

  s.frameworks = 'UIKit'

end
