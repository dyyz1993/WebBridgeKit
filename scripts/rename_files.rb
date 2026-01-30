#!/usr/bin/env ruby
# 文件重命名脚本 - 去 Bark 化

require 'fileutils'

# 项目根目录
PROJECT_ROOT = File.expand_path('..', __dir__)
SOURCES_DIR = File.join(PROJECT_ROOT, 'Sources')

# 重命名规则
RENAMES = {
  'Sources/Controllers/BarkWebViewController.swift' => 'Sources/Controllers/WebViewController.swift',
  'Sources/Cache/BarkCacheURLSchemeHandler.swift' => 'Sources/Cache/CacheURLSchemeHandler.swift',
  # 可以添加更多重命名规则
}

def rename_file(old_path, new_path)
  old_full = File.join(PROJECT_ROOT, old_path)
  new_full = File.join(PROJECT_ROOT, new_path)

  if File.exist?(old_full)
    if File.exist?(new_full)
      puts "⚠️  Skipping: #{new_path} already exists"
      return false
    end

    # 读取文件内容
    content = File.read(old_full)

    # 更新文件中的类名
    if old_path.include?('BarkWebViewController')
      content = content.gsub('class BarkWebViewController', 'class WebViewController')
    elsif old_path.include?('BarkCacheURLSchemeHandler')
      content = content.gsub('class BarkCacheURLSchemeHandler', 'class CacheURLSchemeHandler')
    end

    # 写入新文件
    File.write(new_full, content)

    # 删除旧文件
    File.delete(old_full)

    puts "✓ Renamed: #{old_path} → #{new_path}"
    return true
  else
    puts "⚠️  File not found: #{old_path}"
    return false
  end
end

# 主程序
if __FILE__ == $0
  puts "🔄 WebBridgeKit File Renamer"
  puts "=" * 50

  renamed_count = 0

  RENAMES.each do |old_path, new_path|
    if rename_file(old_path, new_path)
      renamed_count += 1
    end
  end

  puts "=" * 50
  puts "✅ Done! Renamed #{renamed_count} file(s)"
  puts "\n⚠️  Remember to update Xcode project references:"
  puts "   1. Remove old file references"
  puts "   2. Add new file references"
end
