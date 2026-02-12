# 严重问题详细清单（续）

## 问题 4：内存泄漏风险 - 循环引用（续）

### 涉及文件（续）

#### 3. `Sources/Cache/ResourceCache.swift` (在 ManifestStore.swift 中)
**位置：** ManifestStore.swift 第 260-290 行
```swift
func set(_ resource: ResourceData, for pageKey: String) {
    queue.async { [weak self] in  // ✅ 使用了 weak self
        guard let self = self else { return }
        
        // ... I/O 操作
        
        // 🔴 嵌套闭包没有使用 weak self
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("ManifestCacheDidUpdate"),
                object: nil
            )
        }
    }
}
```

#### 4. `DemoApp/Sources/ViewModels/MainViewModel.swift`
**位置：** 第 200-220 行
```swift
private func updateHistoryItemSize(url: String, size: Int64) {
    var currentSections = historiesRelay.value
    var updated = false
    
    for (sIndex, section) in currentSections.enumerated() {
        var items = section.items
        for (iIndex, item) in items.enumerated() {
            if item.url == url {
                item.cachedSize = size
                item.isCached = size > 0
                items[iIndex] = item
                updated = true
            }
        }
        if updated {
            currentSections[sIndex] = WebPageHistorySection(header: section.header, items: items)
            break
        }
    }
    
    if updated {
        historiesRelay.accept(currentSections)  // ✅ 这里没问题，因为在方法内部
    }
}
```

**但在调用处：**
**位置：** 第 170 行
```swift
DispatchQueue.global(qos: .utility).async {
    let size = PersistentManifestLoader.shared.getCacheSize(for: cacheID)
    if size > 0 {
        // 🔴 没有使用 weak self
        DispatchQueue.main.async { [weak self] in
            self?.updateHistoryItemSize(url: itemURL, size: size)
        }
    }
}
```

**这里是正确的！但需要检查所有类似的地方**

### 潜在问题的模式

#### 模式 1：嵌套闭包忘记 weak self
```swift
// 🔴 错误
DispatchQueue.global().async { [weak self] in
    guard let self = self else { return }
    
    // 嵌套闭包忘记 weak self
    DispatchQueue.main.async {
        self.updateUI()  // 🔴 强引用 self
    }
}

// ✅ 正确
DispatchQueue.global().async { [weak self] in
    guard let self = self else { return }
    
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.updateUI()
    }
}
```

#### 模式 2：闭包属性没有 weak self
```swift
// 🔴 错误
class MyCell: UITableViewCell {
    var onTap: (() -> Void)?
}

// 使用时
cell.onTap = {
    self.handleTap()  // 🔴 强引用 self
}

// ✅ 正确
cell.onTap = { [weak self] in
    self?.handleTap()
}
```

