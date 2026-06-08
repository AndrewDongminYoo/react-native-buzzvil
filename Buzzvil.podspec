require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "Buzzvil"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/AndrewDongminYoo/react-native-buzzvil.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}"
  s.private_header_files = "ios/**/*.h"

  s.dependency   "BuzzvilSDK", "~> 6.7.5"
  # Buzzvil.mm imports <BuzzAdBenefitSDK/BuzzAdBenefitSDK-Swift.h> directly for
  # BuzzBenefitHub, so declare it explicitly rather than relying on transitive
  # header reachability.
  s.dependency   "BuzzAdBenefitSDK", "~> 6.7.5"

  install_modules_dependencies(s)
end
