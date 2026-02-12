/**
 * Main Application Module
 * Core application logic and initialization
 */

class App {
    constructor() {
        this.name = 'Static Resource Test App';
        this.version = '1.0.0';
        this.isInitialized = false;
        this.performanceMetrics = {};
        this.startTime = null;
        this.endTime = null;
    }

    /**
     * Initialize the application
     */
    async init() {
        if (this.isInitialized) {
            console.warn('App already initialized');
            return;
        }

        this.startTime = performance.now();
        console.log(`${this.name} v${this.version} initializing...`);

        try {
            // Initialize components
            await this.initPerformanceMonitoring();
            await this.initEventListeners();
            await this.initComponents();

            this.isInitialized = true;
            this.endTime = performance.now();

            const initTime = (this.endTime - this.startTime).toFixed(2);
            console.log(`App initialized successfully in ${initTime}ms`);

            // Emit initialization complete event
            this.emit('app:ready', {
                initTime: parseFloat(initTime),
                timestamp: new Date().toISOString()
            });

        } catch (error) {
            console.error('Failed to initialize app:', error);
            this.emit('app:error', { error: error.message });
        }
    }

    /**
     * Initialize performance monitoring
     */
    async initPerformanceMonitoring() {
        console.log('Initializing performance monitoring...');

        // Monitor page load performance
        if (window.PerformanceObserver) {
            const observer = new PerformanceObserver((list) => {
                for (const entry of list.getEntries()) {
                    this.recordMetric(entry.entryType, entry);
                }
            });

            observer.observe({ entryTypes: ['navigation', 'resource', 'measure', 'paint'] });
            console.log('PerformanceObserver initialized');
        }

        // Record initial navigation timing
        window.addEventListener('load', () => {
            this.recordNavigationTiming();
        });

        // Record paint timing
        if (window.PerformanceObserver) {
            const paintObserver = new PerformanceObserver((list) => {
                for (const entry of list.getEntries()) {
                    console.log(`${entry.name}: ${entry.startTime}ms`);
                }
            });
            paintObserver.observe({ entryTypes: ['paint'] });
        }
    }

    /**
     * Record navigation timing
     */
    recordNavigationTiming() {
        const timing = performance.getEntriesByType('navigation')[0];
        if (!timing) return;

        const navigationMetrics = {
            domContentLoaded: timing.domContentLoadedEventEnd - timing.domContentLoadedEventStart,
            loadComplete: timing.loadEventEnd - timing.loadEventStart,
            domReady: timing.domContentLoadedEventEnd - timing.fetchStart,
            totalLoadTime: timing.loadEventEnd - timing.fetchStart,
            dnsLookup: timing.domainLookupEnd - timing.domainLookupStart,
            tcpConnection: timing.connectEnd - timing.connectStart,
            requestTime: timing.responseEnd - timing.requestStart,
            responseTime: timing.responseEnd - timing.responseStart
        };

        console.log('Navigation Timing:', navigationMetrics);
        this.performanceMetrics.navigation = navigationMetrics;

        this.emit('navigation:timing', navigationMetrics);
    }

    /**
     * Record a performance metric
     */
    recordMetric(type, data) {
        if (!this.performanceMetrics[type]) {
            this.performanceMetrics[type] = [];
        }
        this.performanceMetrics[type].push(data);
    }

    /**
     * Initialize event listeners
     */
    async initEventListeners() {
        console.log('Initializing event listeners...');

        // DOM events
        document.addEventListener('DOMContentLoaded', () => {
            console.log('DOM Content Loaded');
        });

        // Window events
        window.addEventListener('resize', Utils.debounce(() => {
            this.emit('window:resized', {
                width: window.innerWidth,
                height: window.innerHeight
            });
        }, 250));

        window.addEventListener('scroll', Utils.throttle(() => {
            this.emit('window:scrolled', {
                scrollY: window.scrollY,
                scrollX: window.scrollX
            });
        }, 100));

        // Visibility change
        document.addEventListener('visibilitychange', () => {
            this.emit('visibility:changed', {
                hidden: document.hidden,
                visibilityState: document.visibilityState
            });
        });

        // Before unload
        window.addEventListener('beforeunload', () => {
            this.emit('app:beforeunload');
        });

        // Error handling
        window.addEventListener('error', (event) => {
            console.error('Global error:', event.error);
            this.emit('app:error', {
                message: event.error?.message || 'Unknown error',
                stack: event.error?.stack
            });
        });

        // Unhandled promise rejection
        window.addEventListener('unhandledrejection', (event) => {
            console.error('Unhandled promise rejection:', event.reason);
            this.emit('app:promiseRejection', {
                reason: event.reason
            });
        });

        console.log('Event listeners initialized');
    }

    /**
     * Initialize components
     */
    async initComponents() {
        console.log('Initializing components...');

        // Initialize all data attributes
        this.initDataComponents();

        // Initialize interactive elements
        this.initInteractiveElements();

        console.log('Components initialized');
    }

    /**
     * Initialize data-based components
     */
    initDataComponents() {
        // Find all elements with data-component attribute
        const components = document.querySelectorAll('[data-component]');
        components.forEach(el => {
            const componentName = el.dataset.component;
            console.log(`Found component: ${componentName}`);
        });
    }

    /**
     * Initialize interactive elements
     */
    initInteractiveElements() {
        // Initialize buttons
        const buttons = document.querySelectorAll('[data-action]');
        buttons.forEach(btn => {
            btn.addEventListener('click', (e) => {
                const action = btn.dataset.action;
                const data = btn.dataset.params ? JSON.parse(btn.dataset.params) : {};
                this.emit('action:' + action, data);
            });
        });

        // Initialize forms
        const forms = document.querySelectorAll('form[data-form]');
        forms.forEach(form => {
            form.addEventListener('submit', (e) => {
                e.preventDefault();
                const formData = new FormData(form);
                const data = Object.fromEntries(formData.entries());
                this.emit('form:submit', {
                    formId: form.dataset.form,
                    data: data
                });
            });
        });
    }

    /**
     * Simple event emitter
     */
    emit(eventName, data) {
        const event = new CustomEvent(eventName, { detail: data });
        window.dispatchEvent(event);

        // Also try to send to native app if available
        this.sendToNative(eventName, data);
    }

    /**
     * Send data to native app
     */
    sendToNative(eventName, data) {
        // Try iOS
        if (window.webkit?.messageHandlers?.webBridgeKit) {
            try {
                window.webkit.messageHandlers.webBridgeKit.postMessage({
                    event: eventName,
                    data: data
                });
            } catch (error) {
                console.error('Failed to send to iOS:', error);
            }
        }

        // Try Android
        if (window.WebBridgeKitAndroid) {
            try {
                window.WebBridgeKitAndroid.postMessage(JSON.stringify({
                    event: eventName,
                    data: data
                }));
            } catch (error) {
                console.error('Failed to send to Android:', error);
            }
        }
    }

    /**
     * Get all performance metrics
     */
    getPerformanceMetrics() {
        return {
            app: {
                initTime: this.endTime - this.startTime,
                version: this.version
            },
            navigation: this.performanceMetrics.navigation,
            resources: this.getResourceMetrics()
        };
    }

    /**
     * Get resource loading metrics
     */
    getResourceMetrics() {
        const resources = performance.getEntriesByType('resource');
        return resources.map(resource => ({
            name: resource.name.split('/').pop(),
            type: this.getResourceType(resource),
            duration: resource.duration.toFixed(2),
            size: resource.transferSize,
            encodedSize: resource.encodedBodySize,
            decodedSize: resource.decodedBodySize,
            cached: resource.transferSize === 0,
            startTime: resource.startTime.toFixed(2)
        }));
    }

    /**
     * Get resource type from initiatortype
     */
    getResourceType(resource) {
        const typeMap = {
            'link': 'css',
            'script': 'javascript',
            'img': 'image',
            'css': 'css',
            'fetch': 'fetch',
            'xmlhttprequest': 'xhr',
            'other': 'other'
        };
        return typeMap[resource.initiatorType] || resource.initiatorType;
    }

    /**
     * Log performance summary
     */
    logPerformanceSummary() {
        const metrics = this.getPerformanceMetrics();
        console.group('Performance Summary');
        console.log('App Init Time:', metrics.app.initTime.toFixed(2) + 'ms');
        console.log('Resources:', metrics.resources.length);
        console.log('Navigation:', metrics.navigation);
        console.log('All Metrics:', metrics);
        console.groupEnd();
    }
}

// Create global app instance
const app = new App();

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => app.init());
} else {
    app.init();
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = App;
}
