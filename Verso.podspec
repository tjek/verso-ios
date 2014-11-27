Pod::Spec.new do |s|
    s.name         = "Verso"
    s.version      = "0.0.1"
    s.summary      = "A multi-paged image viewer for iOS"
    
    s.homepage     = "https://github.com/eTilbudsavis/ios-verso"
    s.license      = 'MIT'
    s.author       = { "Laurie Hufford" => "lh@etilbudsavis.dk" }
    
    s.platform     = :ios, '6.0'
    s.requires_arc = true
    
    s.source       = {
        :git => "https://github.com/eTilbudsavis/ios-verso.git",
        :tag => "v" + s.version.to_s
    }
    
    s.public_header_files = "Verso/ETA_VersoPagedView.h"
    s.source_files = "Verso/*.{h,m}"
    s.dependency "SDWebImage", "~> 3.7.1"
    
end
