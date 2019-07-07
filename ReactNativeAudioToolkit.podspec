require "json"

Pod::Spec.new do |s|
  # NPM package specification
  package = JSON.parse(File.read(File.join(File.dirname(__FILE__), "package.json")))

  s.name         = "ReactNativeAudioToolkit"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = "MIT"
  s.author       = { "Rasmus Eskola" => "fruitiex@gmail.com" }
  s.platforms    = { :ios => "9.0", :tvos => "9.0" }
  s.source       = { :git => package["repository"]["url"], :tag => "#{s.version}" }
  s.source_files = "ios/**/*.{h,m}"

  s.dependency "React"

end
