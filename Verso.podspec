Pod::Spec.new do |s|

  s.name         = 'Verso'
  s.version      = '1.0.7'
  s.summary      = 'A multi-paged image viewer for iOS'
  s.description  = <<-DESC
                    Verso makes it easy to implement a flexible multi-page book-like layout.
                   DESC

  s.homepage     = 'https://github.com/tjek/verso-ios'
  s.license      = "MIT"
  s.author       = "Tjek"
  
  s.platform         = :ios, "9.3"
  s.swift_version    = "5.0.1"
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }

  s.source = {
    :git => 'https://github.com/tjek/verso-ios.git',
    :tag => s.version
  }

  s.source_files     = 'Sources/**/*'

end
