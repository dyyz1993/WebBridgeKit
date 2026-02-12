// Lazy Mode Test Page Script

console.log('[LazyLoader] Script loaded');

// Test JS Bridge availability
function checkBridgeAvailability() {
    const statusElement = document.getElementById('bridgeStatus');
    const indicator = statusElement.querySelector('.status-indicator');
    const text = statusElement.querySelector('.status-text');

    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.barkBridge) {
        indicator.classList.add('available');
        indicator.classList.remove('unavailable');
        text.textContent = 'Available';
        console.log('[LazyLoader] JS Bridge is available');
    } else {
        indicator.classList.add('unavailable');
        indicator.classList.remove('available');
        text.textContent = 'Not Available';
        console.warn('[LazyLoader] JS Bridge is not available');
    }
}

// Run on load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', checkBridgeAvailability);
} else {
    checkBridgeAvailability();
}

// Test resource loading
window.addEventListener('load', () => {
    const testResult = document.getElementById('resourceTest');
    const resources = {
        css: document.querySelector('link[href="style.css"]'),
        js: document.querySelector('script[src="script.js"]'),
        logo: document.querySelector('.logo')  // Now SVG logo
    };

    const allLoaded = Object.values(resources).every(r => r !== null);

    if (allLoaded) {
        testResult.innerHTML = `
            <p style="color: #4CAF50; font-weight: 600;">✓ All resources loaded successfully</p>
            <ul style="margin-top: 10px; padding-left: 20px;">
                <li>Style.css: ✓</li>
                <li>Script.js: ✓</li>
                <li>Logo.png: ✓</li>
            </ul>
        `;
    } else {
        testResult.innerHTML = `
            <p style="color: #f44336;">✗ Some resources failed to load</p>
        `;
    }

    console.log('[LazyLoader] Resource loading complete:', resources);
});

// Test native bridge calls
function callNative(action, params) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.barkBridge) {
        window.webkit.messageHandlers.barkBridge.postMessage({
            action: action,
            params: params || {}
        });
    } else {
        console.warn('[LazyLoader] Native bridge not available');
    }
}

// Export for manual testing
window.LazyLoaderTest = {
    callNative,
    checkBridgeAvailability,
    getVersion: () => '1.0.0',
    getMode: () => 'lazy'
};

console.log('[LazyLoader] LazyLoaderTest API ready:', Object.keys(window.LazyLoaderTest));
