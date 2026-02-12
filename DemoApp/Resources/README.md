# Static Resource Performance Test Page

This directory contains a comprehensive HTML test page with multiple static resources for performance testing in WebBridgeKit.

## Directory Structure

```
static/
├── static_test.html          # Main test page with performance monitoring
├── css/
│   ├── reset.css            # CSS reset styles (1.3KB)
│   ├── layout.css           # Layout utilities (2.9KB)
│   ├── theme.css            # Theme and colors (5.1KB)
│   └── animations.css       # Animation keyframes (7.8KB)
├── js/
│   ├── utils.js             # Utility functions (10KB)
│   ├── app.js               # Main app logic (10KB)
│   └── components.js        # UI components (13KB)
├── images/
│   ├── logo.svg             # Logo image (630B)
│   ├── hero-bg.svg          # Hero background (2.6KB)
│   └── icon-set.svg         # Icon collection (4.4KB)
└── fonts/
    └── main-font.woff2      # Custom font (placeholder, 858B)

Total: 12 resources, ~59KB total
```

## Features

### 1. Comprehensive Resource Loading
- **4 CSS files** with different sizes and purposes
- **3 JavaScript files** with utility functions, app logic, and components
- **3 SVG images** (logo, hero background, icon set)
- **1 Custom font** (WOFF2 format)

### 2. Performance Monitoring Dashboard
Real-time performance dashboard showing:
- Page load time
- Resource count
- Total transfer size
- Individual resource metrics
- Cache status (cached vs network-loaded)

### 3. Performance API Integration

#### Resource Timing API
Tracks each resource's loading:
- Duration
- Transfer size
- Cache status
- Loading type (CSS, JS, image, font)

#### Navigation Timing API
Monitors page loading phases:
- DNS lookup
- TCP connection
- Request/response time
- DOM processing
- DOMContentLoaded
- Total load time

#### PerformanceObserver
Real-time monitoring of:
- Resource loading events
- Paint events (First Paint, First Contentful Paint)
- Navigation events

### 4. Native Bridge Communication

The page sends performance data to native iOS/Android apps:

```javascript
// iOS
window.webkit.messageHandlers.performanceTest.postMessage(data)

// Android
window.performanceTestAndroid.postMessage(JSON.stringify(data))
```

Data includes:
- Resource metrics (name, type, duration, size, cached)
- Navigation timing
- Timestamp

### 5. Interactive Features

**Buttons:**
- Refresh Metrics - Reload performance data
- Clear Logs - Clear the log console
- Test Performance API - Run API tests
- Send to Native - Send data to native app

**Visual Components:**
- Image gallery with loaded resources
- Animation demos (fadeIn, slideUp, bounce, pulse, spin, shake)
- Resource timing table
- Navigation timing table
- Live log console

## Usage

### Load in WebView

```swift
// Swift
let url = Bundle.main.url(forResource: "static_test", withExtension: "html", subdirectory: "test_resources/static")
webView.load(URLRequest(url: url))
```

### Receive Performance Data

**iOS - Implement WKScriptMessageHandler:**

```swift
func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    if message.name == "performanceTest" {
        if let data = try? JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: message.body)) as? [String: Any] {
            print("Performance data:", data)
            // Process metrics
        }
    }
}
```

**Android - Add JavaScriptInterface:**

```java
class PerformanceTestInterface {
    @JavascriptInterface
    public void postMessage(String data) {
        Log.d("PerformanceTest", data);
        // Process metrics
    }
}

webView.addJavascriptInterface(new PerformanceTestInterface(), "performanceTestAndroid");
```

## Performance Metrics Collected

### Per-Resource Metrics
- **name**: Resource filename
- **type**: Resource type (css, javascript, image, font)
- **duration**: Loading time in milliseconds
- **size**: Transfer size in bytes
- **cached**: Whether resource was loaded from cache

### Navigation Metrics
- **dnsLookup**: DNS resolution time
- **tcpConnection**: TCP connection time
- **requestTime**: Request to response time
- **domProcessing**: DOM building time
- **domContentLoaded**: DOMContentLoaded event time
- **totalLoadTime**: Total page load time

## Testing Scenarios

### 1. Cold Load Test
Clear all caches and load page to measure full resource loading time.

### 2. Warm Load Test
Load page multiple times to measure cache effectiveness.

### 3. Resource Monitoring
Monitor individual resource loading patterns and identify bottlenecks.

### 4. Cache Verification
Verify which resources are cached and their cache hit rates.

### 5. Performance Comparison
Compare performance across different devices, network conditions, or WebView configurations.

## Example Output

```
[INFO] Performance monitoring initialized
[INFO] Waiting for resources to load...
[INFO] DOM Content Loaded
[SUCCESS] Page fully loaded
[INFO] Resource loaded: reset.css (css, 15.23ms, 1.3KB, network)
[INFO] Resource loaded: layout.css (css, 12.45ms, 2.9KB, network)
[INFO] Resource loaded: theme.css (css, 18.67ms, 5.1KB, network)
[INFO] Resource loaded: animations.css (css, 25.12ms, 7.8KB, network)
[INFO] Resource loaded: utils.js (javascript, 32.45ms, 10KB, network)
[INFO] Resource loaded: app.js (javascript, 28.91ms, 10KB, network)
[INFO] Resource loaded: components.js (javascript, 35.23ms, 13KB, network)
[INFO] Resource loaded: logo.svg (image, 8.45ms, 630B, network)
[INFO] Resource loaded: hero-bg.svg (image, 12.34ms, 2.6KB, network)
[INFO] Resource loaded: icon-set.svg (image, 15.67ms, 4.4KB, network)
[SUCCESS] Loaded 12 resources (59KB)
[SUCCESS] Initial metrics collected
```

## Customization

### Add More Resources
Place additional CSS, JS, images, or fonts in their respective directories and reference them in `static_test.html`.

### Modify Monitoring
Edit the JavaScript in `static_test.html` to:
- Add custom metrics
- Change monitoring frequency
- Modify data format sent to native

### Change Styling
All styles are in the CSS files. Modify them to match your testing needs.

## Browser Compatibility

- Chrome/Edge 90+
- Safari 14+
- Firefox 88+
- Mobile Safari iOS 14+
- Chrome Android

Requires:
- Performance API
- PerformanceObserver
- Resource Timing API Level 2
- Navigation Timing API Level 2

## Notes

- SVG images are used for portability (vector format, text-based)
- Font file is a placeholder (real WOFF2 fonts require binary conversion)
- All resources are self-contained (no external dependencies)
- Works offline once loaded
- Performance data is automatically sent to native app if bridge is available

## Files Created

Total files created: 12
- 1 HTML file (23KB)
- 4 CSS files (17.1KB total)
- 3 JavaScript files (33KB total)
- 3 SVG images (7.6KB total)
- 1 Font file (858B placeholder)

Total size: ~59KB (compressed resources will be smaller)
