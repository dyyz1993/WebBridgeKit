#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const projectRoot = path.resolve(__dirname, '..');
const bridgeScripts = [
    'Resources/WebBridge.js',
    'SuperApp/Resources/WebBridge.js'
];

function createContext(nativeAvailable) {
    let postedMessage;
    const context = {
        console: { log() {}, error() {} },
        document: { addEventListener() {} },
        Promise,
        Date,
        setTimeout,
        clearTimeout
    };
    context.window = context;

    if (nativeAvailable) {
        context.webkit = {
            messageHandlers: {
                BarkBridge: {
                    postMessage(message) {
                        postedMessage = message;
                    }
                }
            }
        };
    }

    return {
        context,
        postedMessage: () => postedMessage
    };
}

function loadBridge(relativePath, context) {
    const absolutePath = path.join(projectRoot, relativePath);
    vm.runInNewContext(fs.readFileSync(absolutePath, 'utf8'), context, {
        filename: absolutePath
    });
}

async function verifyBrowserFallback(relativePath) {
    const { context } = createContext(false);
    loadBridge(relativePath, context);

    if (typeof context.WebBridgeKit?.callNative !== 'function') {
        throw new Error(`${relativePath}: public callNative is missing`);
    }

    const result = await context.WebBridgeKit.callNative('clipboard', { action: 'read' });
    if (
        result.success !== false ||
        result.available !== false ||
        result.code !== 'NATIVE_MODULE_UNAVAILABLE' ||
        result.module !== 'clipboard' ||
        !result.message
    ) {
        throw new Error(`${relativePath}: invalid browser fallback ${JSON.stringify(result)}`);
    }
}

async function verifyNativeDelegation(relativePath) {
    const runtime = createContext(true);
    loadBridge(relativePath, runtime.context);

    const pendingResult = runtime.context.WebBridgeKit.callNative('clipboard', { action: 'read' });
    const message = runtime.postedMessage();
    if (message?.action !== 'clipboard' || message.params?.action !== 'read') {
        throw new Error(`${relativePath}: did not delegate to the native message handler`);
    }

    runtime.context.BarkBridge.receiveResult({
        callbackId: message.callbackId,
        success: true,
        value: 'ok'
    });
    const result = await pendingResult;
    if (result.value !== 'ok') {
        throw new Error(`${relativePath}: native callback did not resolve`);
    }
}

(async () => {
    for (const relativePath of bridgeScripts) {
        await verifyBrowserFallback(relativePath);
        await verifyNativeDelegation(relativePath);
        console.log(`PASS ${relativePath}: browser fallback + native delegation`);
    }
})().catch(error => {
    console.error(error.message || error);
    process.exit(1);
});
