# Image Cache Verification Tests

## Overview
XCUITest suite for verifying WebBridgeKit Manifest Cache image loading functionality.

## Test File
**Location:** `/Users/xuyingzhou/Project/temporary/WebBridgeKit/DemoAppUITests/Tests/ImageCacheVerificationTests.swift`

## Test Configuration

### Environment
- **Simulator UDID:** `04034623-1A26-4FE9-AF80-FDA5B7994E88`
- **Bundle ID:** `com.webbridgekit.demo`
- **Test Server:** `http://192.168.0.4:8080`
- **Test Page:** `http://192.168.0.4:8080/test_resources/image_cache_test.html`

### Test Images
1. `images/logo.png` (200x200, blue background, LOGO text)
2. `images/photo1.jpg` (400x300, red-orange gradient)
3. `images/icon.png` (64x64, green background, ICON text)

### URL Scheme
- **Cache Scheme:** `wb-resource://` (used for cached resources)

## Test Suite

### Test #1: Launch and Navigate to Test Page
- Launches the app
- Navigates to the image cache test page
- Verifies successful page load
- **Screenshot:** `01_initial_state.png`, `02_after_url_entry`, `03_page_loaded`

### Test #2: Verify Images Exist in DOM
- Checks for presence of `<img>` elements
- Verifies image attributes (src, alt, complete)
- Reports natural dimensions
- **Screenshot:** `04_images_in_dom`

### Test #3: Verify Images Load from Cache
- Validates `wb-resource://` URL scheme usage
- Checks `src` and `currentSrc` properties
- Counts cached vs non-cached images
- **Report:** `cache_verification_report.txt`
- **Screenshot:** `05_cache_verification`

### Test #4: Verify Image Dimensions
- Validates `naturalWidth > 0`
- Validates `naturalHeight > 0`
- Ensures images fully loaded
- **Screenshot:** `06_dimensions_check`

### Test #5: Verify No SVG Placeholders
- Checks for `data:image/svg` placeholders
- Indicates cache misses if found
- **Screenshot:** `07_placeholder_check`

### Test #6: Comprehensive Cache Validation
- Complete validation suite:
  - Cache status (wb-resource://)
  - Valid dimensions
  - No placeholders
  - Image complete status
- **Reports:**
  - `comprehensive_validation_report.json`
  - `validation_summary.txt`
- **Screenshot:** `08_comprehensive_validation`

### Test #7: Verify URL Scheme Handler
- Analyzes URL scheme distribution
- Validates `wb-resource://` usage
- **Screenshot:** `09_url_scheme_check`

### Test #8: Generate Final Summary
- Creates comprehensive test report
- **Files:**
  - `FINAL_SUMMARY.txt`
  - `10_final_summary.png` (screenshot)

## Evidence Collection

### Directory
**Location:** `/tmp/webview_image_cache_evidence/`

### Contents
- **Screenshots:** PNG files for each test step
- **Reports:** TXT and JSON reports with detailed results
- **Logs:** Console output with os_log statements

## Running the Tests

### Method 1: Xcode (GUI)
```bash
# Open project
open /Users/xuyingzhou/Project/temporary/WebBridgeKit/WebBridgeKit.xcodeproj

# In Xcode:
# 1. Select DemoAppUITests scheme
# 2. Choose target simulator (UDID: 04034623-1A26-4FE9-AF80-FDA5B7994E88)
# 3. Run tests (⌘U)
# 4. Select ImageCacheVerificationTests
```

### Method 2: xcodebuild (CLI)
```bash
# Build and run specific test
xcodebuild test \
  -project WebBridgeKit.xcodeproj \
  -scheme DemoApp \
  -destination 'id=04034623-1A26-4FE9-AF80-FDA5B7994E88' \
  -only-testing:DemoAppUITests/ImageCacheVerificationTests \
  -resultBundlePath /tmp/test_results.xcresult
```

### Method 3: xcrun simctl
```bash
# Boot simulator
xcrun simctl boot 04034623-1A26-4FE9-AF80-FDA5B7994E88

# Install app
xcrun simctl install 04034623-1A26-4FE9-AF80-FDA5B7994E88 /path/to/DemoApp.app

# Run tests
xcrun simctl ui 04034623-1A26-4FE9-AF80-FDA5B7994E88 com.webbridgekit.demo
```

## Key Verification Points

### Success Criteria
- ✅ Image `src` starts with `wb-resource://`
- ✅ `currentSrc` starts with `wb-resource://`
- ✅ `naturalWidth > 0` and `naturalHeight > 0`
- ✅ No SVG placeholders (`data:image/svg`)
- ✅ `complete` property is `true`

### Failure Indicators
- ❌ Images using `http://` or `https://` schemes (cache miss)
- ❌ SVG placeholders present
- ❌ Zero dimensions
- ❌ Incomplete image loading

## Test Reports

### Console Output
Tests use `os_log` for detailed logging:
```
📁 Evidence directory: /tmp/webview_image_cache_evidence
✅ App launched successfully
🌐 Test URL: http://192.168.0.4:8080/test_resources/image_cache_test.html
⏳ Waiting for page to load...
✅ Page loaded successfully
📊 Total images found: 3
🖼️ Image: alt='Logo', src='wb-resource://...', complete=true, size=200x200
```

### Report Files
1. **cache_verification_report.txt** - Basic cache status
2. **comprehensive_validation_report.json** - Detailed JSON results
3. **validation_summary.txt** - Human-readable summary
4. **FINAL_SUMMARY.txt** - Complete test suite summary

## Prerequisites

### Test Server
Ensure test server is running:
```bash
cd /Users/xuyingzhou/Project/temporary/WebBridgeKit
python3 scripts/test_server.py
```

### Test Resources
Verify test images exist:
```bash
ls -la test_resources/images/
# Expected: logo.png, photo1.jpg, icon.png
```

### Simulator
Boot target simulator:
```bash
xcrun simctl boot 04034623-1A26-4FE9-AF80-FDA5B7994E88
```

## Troubleshooting

### Issue: "WebView does not exist"
- **Solution:** Ensure simulator is booted
- **Command:** `xcrun simctl boot 04034623-1A26-4FE9-AF80-FDA5B7994E88`

### Issue: "Page did not load"
- **Solution:** Check test server is running
- **Command:** `curl http://192.168.0.4:8080/test_resources/image_cache_test.html`

### Issue: "No images found"
- **Solution:** Verify test page HTML has `<img>` elements
- **Check:** Browser to test URL manually

### Issue: "Images not cached"
- **Solution:** Verify Manifest Cache is enabled
- **Check:** App logs for cache initialization

## Expected Results

### Successful Test Run
```
Test Suite 'ImageCacheVerificationTests' passed
✅ Test #1: Launch and Navigate - PASSED
✅ Test #2: Images in DOM - PASSED (3 images)
✅ Test #3: Cache Loading - PASSED (3/3 cached)
✅ Test #4: Dimensions - PASSED (all valid)
✅ Test #5: No Placeholders - PASSED (0 placeholders)
✅ Test #6: Comprehensive - PASSED (100% success)
✅ Test #7: URL Scheme - PASSED (wb-resource:// active)
✅ Test #8: Summary - PASSED
```

### Evidence Files Created
```
/tmp/webview_image_cache_evidence/
├── 01_initial_state_*.png
├── 02_after_url_entry_*.png
├── 03_page_loaded_*.png
├── 04_images_in_dom_*.png
├── 05_cache_verification_*.png
├── 06_dimensions_check_*.png
├── 07_placeholder_check_*.png
├── 08_comprehensive_validation_*.png
├── 09_url_scheme_check_*.png
├── 10_final_summary_*.png
├── cache_verification_report.txt
├── comprehensive_validation_report.json
├── validation_summary.txt
└── FINAL_SUMMARY.txt
```

## Integration with CI/CD

### Example GitHub Actions
```yaml
- name: Run Image Cache Tests
  run: |
    xcodebuild test \
      -project WebBridgeKit.xcodeproj \
      -scheme DemoApp \
      -destination 'id=04034623-1A26-4FE9-AF80-FDA5B7994E88' \
      -only-testing:DemoAppUITests/ImageCacheVerificationTests
```

### Example Jenkins
```groovy
stage('Image Cache Tests') {
    steps {
        sh '''
            xcodebuild test \
              -project WebBridgeKit.xcodeproj \
              -scheme DemoApp \
              -destination 'id=04034623-1A26-4FE9-AF80-FDA5B7994E88' \
              -only-testing:DemoAppUITests/ImageCacheVerificationTests
        '''
    }
}
```

## Additional Information

### Test Duration
- **Total:** ~2-3 minutes
- **Per test:** 15-30 seconds
- **Wait times:** Page load (3s), Image load (5-8s)

### Dependencies
- XCTest framework
- XCUITest framework
- os.log framework
- WebKit (for JavaScript evaluation)

### Maintenance
- Update test URL if server changes
- Update expected images list if new images added
- Update simulator UDID if using different simulator

---

**Created:** 2026-02-03
**Version:** 1.0
**Author:** WebBridgeKit Test Team
