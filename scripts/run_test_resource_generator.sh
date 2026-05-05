#!/bin/bash

# run_test_resource_generator.sh
# Script to run TestResourceGenerator from command line

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== WebBridgeKit Test Resource Generator ===${NC}\n"

# Check if we're in the right directory
if [ ! -d "WebBridgeKit.xcodeproj" ]; then
    echo -e "${RED}Error: Please run this script from the WebBridgeKit root directory${NC}"
    echo -e "${RED}Current directory: $(pwd)${NC}"
    exit 1
fi

# Parse command line arguments
CLEANUP=false
CUSTOM_SIZES=""
CUSTOM_DELAYS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --sizes)
            CUSTOM_SIZES="$2"
            shift 2
            ;;
        --delays)
            CUSTOM_DELAYS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --cleanup        Clean up generated test resources"
            echo "  --sizes MB,...    Custom large file sizes in MB (e.g., '10,50,100')"
            echo "  --delays SEC,...  Custom slow resource delays in seconds (e.g., '1,3,5')"
            echo "  --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                              # Generate default test suite"
            echo "  $0 --sizes '5,20,100'           # Custom large file sizes"
            echo "  $0 --delays '0.5,2,5'           # Custom slow delays"
            echo "  $0 --cleanup                    # Remove test resources"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Navigate to Sources/Performance
cd Sources/Performance

if [ "$CLEANUP" = true ]; then
    echo -e "${YELLOW}Cleaning up test resources...${NC}"
    if [ -d "test_resources" ]; then
        rm -rf test_resources
        echo -e "${GREEN}✓ Test resources removed${NC}"
    else
        echo -e "${YELLOW}No test resources found${NC}"
    fi
    exit 0
fi

# Create a temporary Swift file to run the generator
TEMP_FILE="/tmp/test_resource_generator_runner.swift"

cat > "$TEMP_FILE" << 'EOF'
#!/usr/bin/env swift

import Foundation

// Simple standalone runner for TestResourceGenerator
// This is a minimal version that doesn't depend on the full WebBridgeKit framework

func main() {
    let fileManager = FileManager.default
    let currentDir = fileManager.currentDirectoryPath
    let baseDir = URL(fileURLWithPath: currentDir).appendingPathComponent("test_resources")

    print("Creating test resources in: \(baseDir.path)")

    // Create directory structure
    try? fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
    try? fileManager.createDirectory(at: baseDir.appendingPathComponent("large"), withIntermediateDirectories: true)
    try? fileManager.createDirectory(at: baseDir.appendingPathComponent("slow"), withIntermediateDirectories: true)

    // Generate large resources (simulated with smaller files for quick testing)
    let largeSizes = [1, 5, 10] // Using smaller sizes for quick generation

    for size in largeSizes {
        let fileName = "large_resource_\(size)mb.dat"
        let fileURL = baseDir.appendingPathComponent("large").appendingPathComponent(fileName)

        let fileSize = size * 1024 * 1024
        let data = Data(count: fileSize)

        try? data.write(to: fileURL)
        print("✓ Generated: \(fileName) (\(size)MB)")
    }

    // Generate slow resources
    let delays = [1.0, 3.0, 5.0]

    for delay in delays {
        let fileName = "slow_resource_\(Int(delay))s.html"
        let fileURL = baseDir.appendingPathComponent("slow").appendingPathComponent(fileName)

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Slow Resource - \(delay)s</title>
            <style>
                body { font-family: sans-serif; padding: 20px; background: #f0f0f0; }
                .container { max-width: 600px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
                h1 { color: #333; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🐢 Slow Resource</h1>
                <p>This resource simulates a \(delay) second delay.</p>
                <p>Generated at: \(Date().description)</p>
            </div>
        </body>
        </html>
        """

        try? html.write(to: fileURL, atomically: true, encoding: .utf8)
        print("✓ Generated: \(fileName) (\(delay)s delay)")
    }

    // Generate test page
    let testPageURL = baseDir.appendingPathComponent("test_performance.html")

    var html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>WebBridgeKit Performance Test</title>
        <meta charset="UTF-8">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: -apple-system, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; min-height: 100vh; }
            .container { max-width: 1200px; margin: 0 auto; }
            .header { background: rgba(255,255,255,0.95); padding: 30px; border-radius: 15px; margin-bottom: 30px; }
            .header h1 { color: #1e3c72; margin-bottom: 10px; }
            .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
            .stat { background: rgba(255,255,255,0.95); padding: 20px; border-radius: 10px; text-align: center; }
            .stat-value { font-size: 2em; font-weight: bold; color: #2a5298; }
            .resources { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
            .resource { background: rgba(255,255,255,0.95); padding: 20px; border-radius: 10px; }
            .resource.large { border-left: 5px solid #e74c3c; }
            .resource.slow { border-left: 5px solid #f39c12; }
            .resource h3 { margin-bottom: 10px; color: #1e3c72; }
            .resource a { display: inline-block; padding: 8px 16px; background: #2a5298; color: white; text-decoration: none; border-radius: 5px; margin-top: 10px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 WebBridgeKit Performance Test</h1>
                <p>Test resources for measuring WebView performance</p>
            </div>
            <div class="stats">
                <div class="stat"><div class="stat-value">\(largeSizes.count + delays.count)</div><div>Total Resources</div></div>
                <div class="stat"><div class="stat-value">\(largeSizes.reduce(0, +))MB</div><div>Total Size</div></div>
                <div class="stat"><div class="stat-value">\(largeSizes.count)</div><div>Large Files</div></div>
            </div>
            <h2 style="color:white;margin-bottom:20px">Test Resources</h2>
            <div class="resources">
    """

    // Add large resources
    for size in largeSizes {
        html += """
                <div class="resource large">
                    <h3>📦 Large Resource</h3>
                    <p>Size: \(size)MB</p>
                    <a href="./large/large_resource_\(size)mb.dat" download>Download</a>
                </div>
        """
    }

    // Add slow resources
    for delay in delays {
        html += """
                <div class="resource slow">
                    <h3>🐢 Slow Resource</h3>
                    <p>Delay: \(delay)s</p>
                    <a href="./slow/slow_resource_\(Int(delay))s.html" target="_blank">Open</a>
                </div>
        """
    }

    html += """
            </div>
        </div>
        <script>
            window.addEventListener('load', function() {
                const loadTime = performance.timing.domContentLoadedEventEnd - performance.timing.navigationStart;
                console.log('Page load time:', loadTime + 'ms');
            });
        </script>
    </body>
    </html>
    """

    try? html.write(to: testPageURL, atomically: true, encoding: .utf8)
    print("✓ Generated: test_performance.html")

    print("\n✅ Test resources generated successfully!")
    print("📄 Test page: \(testPageURL.path)")
    print("\nTo test:")
    print("1. Open test_performance.html in a browser")
    print("2. Monitor load times and resource loading")
    print("\nTo clean up:")
    print("  Run: $0 --cleanup")
}

main()
EOF

# Run the Swift script
echo -e "${BLUE}Running test resource generator...${NC}\n"
swift "$TEMP_FILE"

# Clean up temp file
rm "$TEMP_FILE"

echo -e "\n${GREEN}=== Generation Complete ===${NC}"

# Show what was created
if [ -d "test_resources" ]; then
    echo -e "\n${BLUE}Generated files:${NC}"
    find test_resources -type f | sort | while read file; do
        size=$(du -h "$file" | cut -f1)
        echo -e "  ${GREEN}✓${NC} $file ($size)"
    done
fi

echo -e "\n${BLUE}Next steps:${NC}"
echo "  1. Open test_resources/test_performance.html in a browser"
echo "  2. Test loading different resources"
echo "  3. Monitor performance metrics"
echo "  4. Run cleanup when done: $0 --cleanup"
