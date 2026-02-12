# 中等问题详细清单

本文档详细列出了 WebBridgeKit 项目中的 12 个中等问题，包括具体的文件路径、代码位置和修复方案。

---

## 问题 1：主线程阻塞 - 同步 Realm 操作

### 严重程度
🟡 中等 - 影响用户体验和性能

### 影响范围
- UI 卡顿
- 用户体验差
- 可能导致 ANR（Application Not Responding）
- 影响应用流畅度

### 涉及文件

#### 1. `Sources/Cache/WebPageHistoryManager.swift`
**位置：** 第 120-125 行
```swift
public func getTotalCount() -> Int {
    let realm = getRealm()
    // 🔴 同步查询，可能在主线程调用
    return realm?.objects(WebPageHistory.self).count ?? 0
}
```

**问题：** 如果在主线程调用，会阻塞 UI

**位置：** 第 130-135 行
```swift
public func getTodayVisitCount() -> Int {
    let realm = getRealm()
    let today = Calendar.current.startOfDay(for: Date())
    // 🔴 同步查询 + 过滤，更慢
    return realm?.objects(WebPageHistory.self)
        .filter("lastVisitDate >= %@", today as NSDate)
        .count ?? 0
}
```

**位置：** 第 140-145 行
```swift
public func getMostVisited(limit: Int = 10) -> [WebPageHistory] {
    guard let realm = getRealm() else { return [] }
    // 🔴 同步查询 + 排序，可能很慢
    return Array(realm.objects(WebPageHistory.self)
        .sorted(byKeyPath: "visitCount", ascending: false)
        .prefix(limit))
}
```

#### 2. `DemoApp/Sources/ViewModels/MainViewModel.swift`
**位置：** 第 145-200 行
```swift
private func loadHistories() {
    print("🔍 [MainVM] loadHistories called")
    
    // ✅ 已经在后台线程，但可以优化
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let self = self else { return }
        
        // 🔴 执行自动清理（可能很慢）
        self.performFrequencyCleanup()
        
        // 🔴 获取所有收藏（可能很多）
        let allFavorites = Array(self.favoriteService.getAllFavorites())
        
        // 🔴 遍历处理（O(n) 复杂度）
        let favoriteURLs = Set(allFavorites.map { $0.url })
        
        // 🔴 获取历史记录（可能很多）
        let historyResults = self.historyService.getAllHistories()
            .sorted(byKeyPath: "lastVisitDate", ascending: false)
        
        // 🔴 过滤和转换（O(n) 复杂度）
        let histories = Array(historyResults.prefix(100))
            .filter { !favoriteURLs.contains($0.url) }
            .prefix(20)
        
        // ... 更多处理
    }
}
```

**问题：** 虽然在后台线程，但操作太多，可能很慢

