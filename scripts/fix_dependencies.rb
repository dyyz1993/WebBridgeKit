#!/usr/bin/env ruby
# 依赖关系修复脚本 - 移除 Bark 特有的依赖

require 'fileutils'

# 项目根目录
PROJECT_ROOT = File.expand_path('..', __dir__)
SOURCES_DIR = File.join(PROJECT_ROOT, 'Sources')

# 替换规则
REPLACEMENTS = {
  'BarkLogger.shared' => 'WebBridgeLogger.shared',
  'BarkWebViewController' => 'WebViewController',
  'BarkCacheURLSchemeHandler' => 'CacheURLSchemeHandler',
  'BarkSnackbarController' => 'UIViewController',  # 临时替换
  'import Bark' => '',  # 移除 Bark import
  '//  Bark' => '//  WebBridgeKit',  # 更新注释
  'Copyright © 2025年 Fin' => 'Copyright © 2025年 WebBridgeKit',
  'NSNotification.Name("BarkOpenWebPage")' => 'NSNotification.Name("WebBridgeOpenWebPage")',
  '"bark://' => '"webbridgekit://',
  '"BarkOpenWebPage"' => '"WebBridgeOpenWebPage"',
  'WebPageHistoryManager.shared' => 'WebPageHistoryManager.shared',  # 保留
  'class BarkWebViewController' => 'class WebViewController',
  ': BarkWebViewController' => ': WebViewController',
  'BarkLogToken' => 'WebBridgeLogToken',
}

# 需要移除的代码行（包含这些内容的行将被注释掉或删除）
LINES_TO_REMOVE = [
  'import Bark',
]

# 需要添加的导入（在文件顶部添加）
IMPORTS_TO_ADD = [
  "import WebBridgeKit\n",
]

def process_file(file_path)
  content = File.read(file_path)
  modified = false

  # 应用替换规则
  REPLACEMENTS.each do |old, new|
    if content.include?(old)
      content = content.gsub(old, new)
      modified = true
      puts "  ✓ Replaced '#{old}' with '#{new}'"
    end
  end

  # 处理需要移除的行
  new_content = []
  content.each_line do |line|
    skip = false
    LINES_TO_REMOVE.each do |pattern|
      if line.include?(pattern)
        skip = true
        modified = true
        puts "  ✓ Removed line: #{line.strip}"
        break
      end
    end
    new_content << line unless skip
  end

  # 添加必要的导入
  if modified
    final_content = new_content.join

    # 在第一个 import 语句后添加导入
    if final_content.include?("import ") && !final_content.include?("import WebBridgeKit")
      import_index = final_content.index(/import .+\n/)
      if import_index
        # 找到最后一个 import 语句
        last_import_end = final_content.rindex(/import .+\n/)
        if last_import_end
          insert_pos = last_import_end + $&.length
          final_content.insert(insert_pos, "\n// Framework imports\n")
        end
      end
    end

    # 写回文件
    File.write(file_path, final_content)
    puts "✓ Updated: #{file_path}"
  end

  modified
end

def process_directory(dir)
  puts "Processing directory: #{dir}"

  Dir.glob(File.join(dir, '**/*.swift')).each do |file|
    process_file(file)
  end
end

# 主程序
if __FILE__ == $0
  puts "🔧 WebBridgeKit Dependency Fixer"
  puts "=" * 50
  puts "Project Root: #{PROJECT_ROOT}"
  puts "Sources Dir: #{SOURCES_DIR}"
  puts "=" * 50

  if Dir.exist?(SOURCES_DIR)
    process_directory(SOURCES_DIR)
    puts "\n✅ Done!"
    puts "\n⚠️  Please review the changes and manually fix any remaining issues."
    puts "⚠️  You may need to:"
    puts "   1. Fix any remaining Bark-specific references"
    puts "   2. Rename files (e.g., BarkWebViewController.swift → WebViewController.swift)"
    puts "   3. Update Xcode project references"
  else
    puts "❌ Error: Sources directory not found at #{SOURCES_DIR}"
    exit 1
  end
end
