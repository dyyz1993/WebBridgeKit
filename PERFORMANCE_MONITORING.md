# Performance Monitoring Implementation

## Overview

This document describes the performance monitoring system added to WebBridgeKit for tracking operation durations and identifying bottlenecks.

## Files Created

### 1. PerformanceMonitor.swift
**Location:** `/Users/xuyingzhou/Project/temporary/WebBridgeKit/Sources/Utils/PerformanceMonitor.swift`

**Features:**
- `measure<T>()` for synchronous operations
- `measure<T>()` for asynchronous operations
- Records operation duration, timestamp, and metadata
- Calculates statistics (count, average, min, max, total)
- Logs slow operations (>1 second threshold)
- Auto-cleanup of old metrics (>1 hour)
- Thread-safe implementation using concurrent dispatch queue

**Usage:**
```swift
// Synchronous operation
let result = PerformanceMonitor.shared.measure("OperationName") {
    // Your code here
    return result
}

// Asynchronous operation
let result = try await PerformanceMonitor.shared.measure("AsyncOperation") {
    return try await someAsyncFunction()
}

// With metadata
let result = try await PerformanceMonitor.shared.measure(
    "NetworkRequest",
    metadata: ["url": urlString, "method": "GET"]
) {
    return try await performRequest()
}
```

**Convenience Extensions:**
- `measureURLRequest()` - For URL session requests
- `measureDatabaseOperation()` - For database operations
- `measureFileOperation()` - For file I/O operations

**Statistics API:**
```swift
// Get statistics for a specific operation
let stats = PerformanceMonitor.shared.getStatistics(for: "OperationName")

// Get all statistics
let allStats = PerformanceMonitor.shared.getAllStatistics()

// Export as JSON
let json = PerformanceMonitor.shared.exportMetricsAsJSON()
```

### 2. SignpostLogger.swift
**Location:** `/Users/xuyingzhou/Project/temporary/WebBridgeKit/Sources/Utils/SignpostLogger.swift`

**Features:**
- Uses `os.signpost` for Instruments integration
- Categories: networking, cache, database, javascript, rendering, performance
- Interval tracking (begin/end)
- Event logging
- Platform-aware with fallback for older systems

**Usage:**
```swift
// Modern API (iOS 12+, macOS 10.14+)
SignpostLogger.shared.beginInterval("OperationName", category: .networking)
// ... perform operation
SignpostLogger.shared.endInterval("OperationName", category: .networking)

// Unified API (works on all platforms)
UnifiedSignpostLogger.shared.beginInterval("OperationName", category: .networking)
// ... perform operation
UnifiedSignpostLogger.shared.endInterval("OperationName", category: .networking)

// Measure blocks
let result = try await UnifiedSignpostLogger.shared.measure("OperationName") {
    return try await someOperation()
}
```

## Files Modified

### 1. WebPageCacheHandler.swift
**Monitored Operations:**
- `preloadPage()` - Page preloading with pageName metadata
- `loadFromTestResources()` - Test resource loading with source metadata
- `loadFromBundle()` - Bundle loading with source metadata

### 2. ManifestCacheManager.swift
**Monitored Operations:**
- `downloadResource()` - Resource downloads with relativePath and URL metadata
- `performDownload()` - Actual download operation with relativePath and URL metadata

### 3. WebPageHistoryManager.swift
**Monitored Operations:**
- `addOrUpdateHistory()` - Database write operations with URL and operation metadata
- `getAllHistories()` - Database query operations with sort metadata
- `searchHistories()` - Database search operations with keyword metadata

### 4. WebBridgeLogger.swift
**Added Log Category:**
- `.performance` - For performance-related log messages

## Performance Statistics

### Statistic Structure
```swift
public struct Statistics {
    let operation: String      // Operation name
    let count: Int              // Number of executions
    let average: TimeInterval   // Average duration (seconds)
    let min: TimeInterval       // Minimum duration
    let max: TimeInterval       // Maximum duration
    let total: TimeInterval     // Total time spent
    let lastUpdate: Date        // Last execution timestamp

    var averageMs: Double       // Average in milliseconds
    var minMs: Double           // Min in milliseconds
    var maxMs: Double           // Max in milliseconds
    var totalMs: Double         // Total in milliseconds
}
```

### JSON Export Format
```json
{
  "OperationName": {
    "count": 100,
    "average_ms": 45.2,
    "min_ms": 10.5,
    "max_ms": 150.8,
    "total_ms": 4520.0,
    "last_update": "2025-01-15T10:30:00.000Z"
  }
}
```

## Configuration

### PerformanceMonitor
```swift
// Enable/disable monitoring
PerformanceMonitor.shared.isEnabled = true

// Set slow operation threshold (default: 1.0 second)
PerformanceMonitor.shared.slowThreshold = 2.0

// Clear metrics
PerformanceMonitor.shared.clearMetrics(for: "OperationName")
PerformanceMonitor.shared.clearAllMetrics()
```

### SignpostLogger
```swift
// Enable/disable signpost logging
UnifiedSignpostLogger.shared.isEnabled = true
```

## Instruments Integration

When you run your app with Instruments (Time Profiler), the signpost intervals will appear as distinct events:
1. Open Instruments
2. Select "Time Profiler"
3. Start recording
4. Perform operations in your app
5. Look for signpost intervals in the timeline

## Performance Monitoring Best Practices

### 1. Identify Critical Paths
Monitor operations that:
- Execute frequently
- Handle user interactions
- Perform I/O operations
- Process large datasets

### 2. Set Appropriate Thresholds
- Fast operations (<100ms): No monitoring needed
- Medium operations (100ms-1s): Monitor for anomalies
- Slow operations (>1s): Always monitor and optimize

### 3. Review Statistics Regularly
```swift
// Print all statistics
let stats = PerformanceMonitor.shared.getAllStatistics()
for (operation, stat) in stats {
    print("\(operation):")
    print("  Count: \(stat.count)")
    print("  Average: \(stat.averageMs)ms")
    print("  Max: \(stat.maxMs)ms")
}
```

### 4. Use Signposts for Profiling
Signposts are useful for:
- Understanding operation flow
- Identifying concurrent operations
- Visualizing performance in Instruments

## Performance Optimization Workflow

1. **Baseline Measurement**
   - Run operations through monitoring
   - Gather statistics
   - Identify slow operations

2. **Analysis**
   - Look at max durations (indicates worst-case)
   - Check average durations (indicates typical performance)
   - Review metadata to identify patterns

3. **Optimization**
   - Focus on high-impact operations
   - Re-measure after changes
   - Quantify improvements

4. **Regression Prevention**
   - Keep monitoring enabled
   - Set up alerts for slow operations
   - Compare statistics over time

## Example: Identifying a Bottleneck

```swift
// Before optimization
let stats = PerformanceMonitor.shared.getStatistics(for: "PageCache.preloadPage")
// Count: 50, Average: 850ms, Max: 1200ms

// After optimizing resource loading
let stats = PerformanceMonitor.shared.getStatistics(for: "PageCache.preloadPage")
// Count: 50, Average: 320ms, Max: 450ms
// Improvement: 62% faster on average
```

## Troubleshooting

### High Memory Usage
- Metrics are auto-cleared after 1 hour
- Manually clear with `clearAllMetrics()`
- Disable monitoring in production builds

### Missing Statistics
- Verify `isEnabled = true`
- Check that operations actually executed
- Ensure operation names match exactly

### Signposts Not Visible in Instruments
- Verify running on iOS 12+ or macOS 10.14+
- Check `isEnabled = true`
- Ensure you're using the correct Instruments template

## Future Enhancements

Potential improvements:
1. Add percentile statistics (p50, p95, p99)
2. Implement performance alerts
3. Add performance trend tracking
4. Create dashboard UI for statistics
5. Export to analytics services
