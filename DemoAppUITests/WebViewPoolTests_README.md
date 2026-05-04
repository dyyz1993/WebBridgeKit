# WebView Pool UI Tests

## Overview

This document describes the comprehensive UI test suite for WebView Pool and Browser Manager functionality in WebBridgeKit.

## Created Files

### 1. Test File
**Path**: `/Users/xuyingzhou/Project/temporary/WebBridgeKit/DemoAppUITests/Tests/WebViewPoolTests.swift`

This file contains 11 comprehensive test cases covering all aspects of WebView pool and browser management.

### 2. Page Object
**Path**: `/Users/xuyingzhou/Project/temporary/WebBridgeKit/DemoAppUITests/Pages/WebViewPoolPage.swift`

Page Object for interacting with and verifying WebView pool states and browser behavior.

## Test Cases

### Required Tests (All Implemented)

1. **testWebViewPoolInitialization()**
   - Verifies pool initialization with default configuration
   - Validates pool size and warmup status
   - Tests that pool starts empty (size 0) and can be warmed up

2. **testWebViewReuse()**
   - Verifies WebView instance reuse
   - Opens the same URL multiple times
   - Validates hit rate increases (showing reuse occurred)
   - Confirms pool maintains instances after browser sessions

3. **testWebViewPreheating()**
   - Tests the warmup functionality
   - Validates pool is marked as warmed up
   - Confirms pre-warmed instances exist
   - Verifies accessibility identifiers are set

4. **testLRUEviction()**
   - Validates LRU (Least Recently Used) eviction strategy
   - Creates more instances than pool size (max: 2)
   - Confirms pool never exceeds maximum size
   - Tests oldest instances are evicted when pool is full

5. **testMemoryManagement()**
   - Tests memory warning handling
   - Simulates memory warning notification
   - Validates pool is cleared after warning
   - Confirms warmup flag is reset

6. **testBrowserManagerNavigation()**
   - Verifies browser manager navigation functionality
   - Tests opening multiple browsers in sequence
   - Validates navigation history tracking
   - Tests back navigation

7. **testDisplayModes()**
   - Tests all three display modes:
     - **Normal Mode**: Full browser with navigation elements
     - **Modal Mode**: Popup window with mask and close button
     - **Immersive Mode**: Full-screen without navigation elements

### Additional Tests

8. **testPoolStatusReporting()**
   - Validates pool status reporting
   - Checks hit rate, size, and warmup status

9. **testWebViewInstanceLifecycle()**
   - Tests acquire and recycle operations
   - Validates WebView and Bridge instances

10. **testConcurrentAccess()**
    - Tests thread-safe concurrent pool access
    - Validates pool maintains integrity during parallel operations

11. **testPoolResetAfterBackground()**
    - Tests behavior when app enters background
    - Validates pool size reduction (keeps 1 instance)
    - Tests foreground re-warming

## Accessibility Identifiers Added

### WebViewPool.swift
- `webViewPool.instance.0` - Pre-warmed WebView instance
- Dynamic identifiers for pool instances: `webViewPool.instance.{index}`

### WebBrowserViewController.swift
- `browserManager.titleLabel` - Browser title label
- `browserManager.closeButton` - Close button
- `browserManager.backButton` - Back button
- `browserManager.menuButton` - Menu button

### ModalWebViewController.swift
- `modalBrowser.view` - Modal view
- `modalBrowser.maskView` - Modal mask (background overlay)
- `modalBrowser.containerView` - Modal content container
- `modalBrowser.webView` - WebView in modal
- `modalBrowser.closeButton` - Modal close button

## Page Object Methods

### Verification Methods
- `verifyPoolInitialized()` - Check if pool is initialized
- `verifyPoolSize(expectedSize:)` - Verify pool has expected size
- `verifyPrewarmedWebViewExists()` - Check for pre-warmed instance
- `verifyModalBrowserDisplayed()` - Verify modal is visible
- `verifyNormalBrowserDisplayed()` - Verify normal browser is visible
- `verifyImmersiveMode()` - Check for immersive mode

### Action Methods
- `warmupPool()` - Trigger WebView pool warmup
- `simulateMemoryWarning()` - Simulate memory warning
- `openBrowser(url:displayMode:)` - Open browser with specific mode
- `closeBrowser()` - Close current browser
- `navigateBack()` - Navigate back in history
- `openBrowserMenu()` - Open browser menu
- `getPoolStatus()` - Get current pool status
- `acquireWebView()` - Acquire instance from pool
- `recycleWebView(_:)` - Recycle instance back to pool
- `getNavigationHistory()` - Get browser navigation history
- `verifyWebViewReuse(url:iterations:)` - Test WebView reuse
- `verifyLRUEviction()` - Test LRU eviction
- `waitForModalBrowser(timeout:)` - Wait for modal to appear
- `waitForModalBrowserToDisappear(timeout:)` - Wait for modal to close

## Running the Tests

### Run All WebView Pool Tests
```bash
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme DemoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:DemoAppUITests/WebViewPoolTests
```

### Run Specific Test
```bash
xcodebuild test \
  -workspace WebBridgeKit.xcworkspace \
  -scheme DemoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:DemoAppUITests/WebViewPoolTests/testWebViewPoolInitialization
```

## Implementation Details

### WebView Pool Configuration
- **Max Pool Size**: 2 instances
- **Cache Strategy**: LRU (Least Recently Used)
- **Thread Safety**: NSLock protected
- **Memory Management**: Auto-clear on memory warning

### Browser Display Modes
1. **Normal**: Standard full-screen browser with navigation bar
2. **Immersive**: Full-screen hiding status bar and navigation
3. **Modal**: Popup window with configurable size and mask

### Key Features Tested
- ✅ Pool initialization and warmup
- ✅ WebView instance reuse and recycling
- ✅ LRU eviction when pool exceeds capacity
- ✅ Memory warning handling
- ✅ Background/foreground state management
- ✅ Browser navigation (forward/back)
- ✅ Navigation history tracking
- ✅ Multiple display modes
- ✅ Thread-safe concurrent access
- ✅ Accessibility identifiers for UI testing

## Test Data

The tests use the following test URLs:
- `https://www.example.com` - General testing
- `https://www.example.com/page1` - Navigation testing
- `https://www.example.com/page2` - Navigation testing

## Notes

- Tests are independent and can run in any order
- Each test has proper setup and teardown
- Tests use XCTest expectations for async operations
- Page Object pattern provides clean, maintainable test code
- All accessibility identifiers follow naming convention: `{component}.{element}`

## Dependencies

- XCTest framework
- WebBridgeKit framework
- DemoApp target
- iOS Simulator for testing

## Future Enhancements

Potential additions to the test suite:
- Performance benchmarks for pool operations
- Stress testing with high instance counts
- Memory usage profiling
- WebView state persistence testing
- Cross-tab browser session testing
- WebView content validation
