platform :ios, '10'

target 'Beiwe' do
  use_frameworks!
  pod 'Crashlytics', '~> 3.4'
  pod 'KeychainSwift', '~> 8.0'
  pod "PromiseKit"
  pod 'Alamofire', '~> 4.5'
  pod 'ObjectMapper', :git => 'https://github.com/Hearst-DD/ObjectMapper.git', :branch => 'master'
  pod 'Eureka', '4.1.1'
  pod 'SwiftValidator', :git => 'https://github.com/jpotts18/SwiftValidator.git', :branch => 'master'
  pod "PKHUD", :git => 'https://github.com/pkluz/PKHUD.git'
  pod 'IDZSwiftCommonCrypto', '~> 0.9'
  pod 'couchbase-lite-ios'
  pod 'ResearchKit'
  pod 'ReachabilitySwift', '~>3'
  pod 'EmitterKit', '~> 5.1'
  pod 'Hakuba', :git => 'https://github.com/eskizyen/Hakuba.git', :branch => 'Swift3'
  pod 'XLActionController'
  pod 'XCGLogger', '~> 7.0.0'
  pod 'Permission/Notifications'
  pod 'Permission/Location'
  pod 'DLLocalNotifications'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    next unless (target.name == 'PromiseKit')
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    end
  end
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if (target.name == 'XCGLogger' || target.name == 'PermissionScope')
          config.build_settings['SWIFT_VERSION'] = '4.0'
      else
          config.build_settings['SWIFT_VERSION'] = '4.0'
      end
      config.build_settings['ENABLE_BITCODE'] = 'NO'

    end
  end
end


