platform :ios, '14.0'
use_frameworks!
inhibit_all_warnings!

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
  pod 'Material', '~> 3.1'
  pod 'SVProgressHUD', '~> 2.2'
end

target 'WebBridgeKit' do
  shared_pods
end

target 'DemoApp' do
  shared_pods
end

target 'DemoAppUITests' do
  inherit! :search_paths
  pod 'OHHTTPStubs/Swift'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # 基础配置
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'

      # 修复沙盒问题
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'

      # C++ 标准设置（仅用于 C++ targets）
      if target.name.include?('Realm')
        config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'gnu++20'
        config.build_settings['CLANG_CXX_LIBRARY'] = 'libc++'
        # 修复 Realm 头文件包含问题
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'REALM_HAVE_CONFIG=1'
        config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      end
    end
  end
end
