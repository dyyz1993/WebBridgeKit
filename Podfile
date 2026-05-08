install! 'cocoapods', :warn_for_unused_master_specs_repo => false

platform :ios, '14.0'
use_frameworks!
inhibit_all_warnings!

workspace 'WebBridgeKit.xcworkspace'
project 'WebBridgeKit.xcodeproj'

def shared_pods
  pod 'SnapKit'
  pod 'RxSwift', '~> 6.0'
  pod 'RxCocoa', '~> 6.0'
  pod 'RxDataSources', '~> 5.0'
  pod 'Moya/RxSwift', '~> 15.0'
  pod 'Kingfisher', '~> 7.0'
  pod 'SwiftSoup', '~> 2.6'
  pod 'RealmSwift', '~> 10.42'
  pod 'ZIPFoundation', '~> 0.9'

end

target 'WebBridgeKit' do
  shared_pods

  target 'CacheTests' do
    inherit! :complete
  end

  target 'MessageTests' do
    inherit! :complete
  end

  target 'AITests' do
    inherit! :complete
  end

  target 'SkillsTests' do
    inherit! :complete
  end

  target 'HandlerTests' do
    inherit! :complete
  end

  target 'HandlerTests-Part1' do
    inherit! :complete
  end

  target 'HandlerTests-Part2' do
    inherit! :complete
  end

  target 'BridgeTests' do
    inherit! :complete
  end

  target 'CoreTests' do
    inherit! :complete
  end

  target 'ModelsTests' do
    inherit! :complete
  end

  target 'UtilsTests' do
    inherit! :complete
  end

  target 'ServicesTests' do
    inherit! :complete
  end

  target 'InfrastructureTests' do
    inherit! :complete
  end

  target 'CommandParserTests' do
    inherit! :complete
  end

  target 'ThemeTests' do
    inherit! :complete
  end

  target 'ViewModelTests' do
    inherit! :complete
  end

  target 'WebSocketTests' do
    inherit! :complete
  end

  target 'BaseTests' do
    inherit! :complete
  end

  target 'ExtensionsTests' do
    inherit! :complete
  end

  target 'ManagersTests' do
    inherit! :complete
  end
end

target 'SuperApp' do
  shared_pods
end

target 'SuperAppUITests' do
  inherit! :search_paths
  shared_pods
end

target 'AppTemplate' do
  shared_pods
end

target 'Cache' do
  pod 'RxSwift', '~> 6.0'
  pod 'RxCocoa', '~> 6.0'
  pod 'RealmSwift', '~> 10.42'
  pod 'ZIPFoundation', '~> 0.9'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'

      if target.name.include?('Realm')
        config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'gnu++20'
        config.build_settings['CLANG_CXX_LIBRARY'] = 'libc++'
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'REALM_HAVE_CONFIG=1'
        config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      end
    end
  end
end
