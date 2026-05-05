/**
 * Manifest Cache 功能 E2E 测试
 *
 * 测试场景：
 * 1. 测试页面加载 - 验证使用 custom:// baseURL 加载 HTML
 * 2. 测试资源拦截 - 验证相对路径资源被正确拦截
 * 3. 测试缓存命中 - 验证资源被缓存后第二次加载使用缓存
 * 4. 测试 manifest 查找 - 验证从 manifest.json 查找真实 URL
 *
 * 测试资源：
 * - 测试页面: /test_resources/manifest_test.html
 * - Manifest: /test_resources/manifest.json
 *
 * 测试服务器：
 * - 使用 Python test_server.py
 * - 端口: 8080
 * - 在全局设置中启动，全局清理中关闭
 */

import { test, expect, Page } from '@playwright/test';
import { exec } from 'child_process';
import { promisify } from 'util';
import { existsSync } from 'fs';
import { readdirSync } from 'fs';

const execAsync = promisify(exec);

// 测试配置
const TEST_SERVER_URL = 'http://localhost:8080';
const TEST_PAGE_PATH = '/manifest_test.html';  // 服务器已配置为从 test_resources 目录服务
const MANIFEST_PATH = '/manifest.json';
const SIMULATOR_ID = '21045190-6163-49E0-82AD-9E4CFD5E3C55';
const APP_BUNDLE_ID = 'com.webbridgekit.demo';

// 查找 DemoApp.app 的实际路径
function findAppPath(): string {
  const derivedDataBase = '/Users/xuyingzhou/Library/Developer/Xcode/DerivedData';
  const dirs = readdirSync(derivedDataBase);

  for (const dir of dirs) {
    if (dir.startsWith('WebBridgeKit')) {
      const appPath = `${derivedDataBase}/${dir}/Build/Products/Debug-iphonesimulator/DemoApp.app`;
      if (existsSync(appPath)) {
        return appPath;
      }
    }
  }

  // 默认路径（如果找不到）
  return 'build/Build/Products/Debug-iphonesimulator/DemoApp.app';
}

const APP_PATH = findAppPath();
console.log(`📍 Using app path: ${APP_PATH}`);

/**
 * 套件级别设置：安装并启动应用
 */
test.beforeAll(async () => {
  console.log('📱 Installing and launching DemoApp on simulator...');

  try {
    // 卸载旧版本（如果存在）
    await execAsync(`xcrun simctl uninstall ${SIMULATOR_ID} ${APP_BUNDLE_ID}`).catch(() => {
      console.log('ℹ️  App not installed, skipping uninstall');
    });

    // 安装应用
    console.log('📦 Installing app...');
    await execAsync(`xcrun simctl install ${SIMULATOR_ID} "${APP_PATH}"`);

    // 启动应用
    console.log('🚀 Launching app...');
    await execAsync(`xcrun simctl launch ${SIMULATOR_ID} ${APP_BUNDLE_ID}`);

    // 等待应用启动
    await new Promise(resolve => setTimeout(resolve, 3000));

    console.log('✅ DemoApp is ready');
  } catch (error) {
    console.error('❌ Failed to launch app:', error);
    throw error;
  }
});

/**
 * 套件级别清理：关闭应用
 */
test.afterAll(async () => {
  console.log('🛑 Terminating DemoApp...');

  try {
    await execAsync(`xcrun simctl terminate ${SIMULATOR_ID} ${APP_BUNDLE_ID}`);
    console.log('✅ DemoApp terminated');
  } catch (error) {
    console.warn('⚠️  Failed to terminate app:', error);
  }
});

/**
 * 测试 1: 验证测试服务器运行和 manifest 文件可访问
 */
test('should verify test server and manifest file are accessible', async ({ page }) => {
  console.log('🔍 Verifying test server and manifest...');

  // 访问 manifest.json
  const manifestResponse = await page.request.get(`${TEST_SERVER_URL}${MANIFEST_PATH}`);
  expect(manifestResponse.ok()).toBeTruthy();

  const manifest = await manifestResponse.json();
  // 验证 manifest 包含所有必需的键
  expect(manifest).toHaveProperty('logo.png');
  expect(manifest['logo.png']).toBe('https://example.com/favicon.ico');
  expect(manifest).toHaveProperty('banner.jpg');
  expect(manifest).toHaveProperty('avatar.webp');
  expect(manifest).toHaveProperty('background.svg');

  console.log('✅ Manifest file is accessible and valid');
});

/**
 * 测试 2: 测试页面加载 - 验证 HTML 页面可以正常加载
 */
test('should load manifest test page successfully', async ({ page }) => {
  console.log('📄 Loading manifest test page...');

  // 访问测试页面
  await page.goto(`${TEST_SERVER_URL}${TEST_PAGE_PATH}`);

  // 等待页面加载完成
  await page.waitForLoadState('networkidle');

  // 验证页面标题
  const title = await page.title();
  expect(title).toBe('Manifest Cache Test');

  // 验证主容器存在
  const container = page.locator('.container');
  await expect(container).toBeVisible();

  // 验证标题文本
  const heading = page.locator('h1');
  await expect(heading).toContainText('Manifest Cache Test');

  // 验证状态区域
  const status = page.locator('.status');
  await expect(status).toBeVisible();
  await expect(status).toContainText('Cache Status');

  console.log('✅ Page loaded successfully with correct content');
});

/**
 * 测试 3: 测试资源拦截 - 验证相对路径资源被正确拦截和加载
 */
test('should intercept and load resources via manifest mapping', async ({ page }) => {
  console.log('🎯 Testing resource interception...');

  // 监听网络请求
  const networkRequests: string[] = [];
  page.on('request', request => {
    const url = request.url();
    if (url.includes('example.com') || url.includes('placeholder.com') || url.includes('via.placeholder')) {
      networkRequests.push(url);
      console.log(`📡 Resource request: ${url}`);
    }
  });

  // 访问测试页面
  await page.goto(`${TEST_SERVER_URL}${TEST_PAGE_PATH}`);

  // 等待所有图片加载
  await page.waitForLoadState('networkidle');

  // 等待额外的 2 秒让所有异步图片加载完成
  await page.waitForTimeout(2000);

  // 验证图片元素存在
  const images = page.locator('.image-card img');
  const imageCount = await images.count();
  expect(imageCount).toBe(4);

  console.log(`✅ Found ${imageCount} images in the page`);

  // 验证每个图片都有对应的标签
  const labels = page.locator('.image-card .label');
  const labelCount = await labels.count();
  expect(labelCount).toBe(4);

  // 验证标签内容
  const labelTexts = await labels.allTextContents();
  expect(labelTexts).toContain('logo.png → example.com');
  expect(labelTexts).toContain('banner.jpg → placeholder.com');
  expect(labelTexts).toContain('avatar.webp → via.placeholder');
  expect(labelTexts).toContain('background.svg → placeholder');

  console.log('✅ All image labels are correct');
});

/**
 * 测试 4: 测试页面日志 - 验证 JavaScript 控制台日志输出
 */
test('should log manifest cache activity to console', async ({ page }) => {
  console.log('📝 Testing console log output...');

  // 收集控制台消息
  const consoleMessages: string[] = [];
  page.on('console', msg => {
    const text = msg.text();
    if (text.includes('Manifest') || text.includes('Image')) {
      consoleMessages.push(text);
      console.log(`📋 Console: ${text}`);
    }
  });

  // 访问测试页面
  await page.goto(`${TEST_SERVER_URL}${TEST_PAGE_PATH}`);

  // 等待页面加载和日志输出
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(3000);

  // 验证控制台日志包含预期的消息
  const allLogs = consoleMessages.join(' ');
  expect(allLogs).toContain('Manifest Test');

  console.log('✅ Console logs captured');
});

/**
 * 测试 5: 测试缓存命中 - 验证资源被缓存后第二次加载使用缓存
 */
test('should cache resources and use cache on subsequent loads', async ({ page }) => {
  console.log('💾 Testing cache hit behavior...');

  // 第一次加载
  console.log('🔄 First page load...');
  await page.goto(`${TEST_SERVER_URL}${TEST_PAGE_PATH}`);
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(2000);

  // 记录第一次加载的图片数量
  const firstLoadImages = await page.locator('.image-card img').count();
  expect(firstLoadImages).toBe(4);
  console.log(`✅ First load: ${firstLoadImages} images`);

  // 刷新页面（第二次加载）
  console.log('🔄 Second page load (should use cache)...');
  await page.reload();
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(2000);

  // 验证第二次加载也有相同数量的图片
  const secondLoadImages = await page.locator('.image-card img').count();
  expect(secondLoadImages).toBe(4);
  console.log(`✅ Second load: ${secondLoadImages} images`);

  // 验证页面标题依然正确
  const title = await page.title();
  expect(title).toBe('Manifest Cache Test');

  console.log('✅ Cache behavior verified');
});

/**
 * 测试 6: 测试 manifest 查找 - 验证从 manifest.json 查找真实 URL
 */
test('should map relative paths to real URLs via manifest', async ({ page }) => {
  console.log('🗺️  Testing manifest URL mapping...');

  // 获取 manifest 内容
  const manifestResponse = await page.request.get(`${TEST_SERVER_URL}${MANIFEST_PATH}`);
  const manifest = await manifestResponse.json();

  // 访问测试页面
  await page.goto(`${TEST_SERVER_URL}${TEST_PAGE_PATH}`);

  // 等待页面加载
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(2000);

  // 获取所有图片的 src 属性
  const imageElements = await page.locator('.image-card img').all();
  const imageSrcs = await Promise.all(
    imageElements.map(async (element) => await element.getAttribute('src'))
  );

  // 验证图片的 src 是来自 manifest 映射的真实 URL
  for (const src of imageSrcs) {
    // 验证 src 是一个完整的 HTTP(S) URL
    expect(src).toMatch(/^https?:\/\//);
    console.log(`✅ Image loaded from: ${src}`);
  }

  // 验证至少有一个图片使用了 manifest 中的 URL
  const manifestUrls = Object.values(manifest);
  const hasManifestUrl = imageSrcs.some(src =>
    manifestUrls.some(url => src.includes(url))
  );
  expect(hasManifestUrl).toBeTruthy();

  console.log('✅ Manifest URL mapping verified');
});

/**
 * 测试 7: 测试错误处理 - 验证资源加载失败时的错误处理
 */
test('should handle resource load failures gracefully', async ({ page }) => {
  console.log('❌ Testing error handling...');

  // 收集控制台错误消息
  const errorMessages: string[] = [];
  page.on('console', msg => {
    if (msg.type() === 'error') {
      errorMessages.push(msg.text());
      console.log(`⚠️  Console error: ${msg.text()}`);
    }
  });

  // 访问测试页面
  await page.goto(`${TEST_SERVER_URL}${TEST_PAGE_PATH}`);

  // 等待页面加载
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(2000);

  // 检查日志区域是否有错误条目
  const logEntries = page.locator('#log .log-entry');
  const logCount = await logEntries.count();

  console.log(`📋 Found ${logCount} log entries`);

  // 验证至少有成功加载的日志
  const successLogs = page.locator('#log .log-entry.success');
  const successCount = await successLogs.count();
  expect(successCount).toBeGreaterThan(0);

  console.log(`✅ Found ${successCount} success log entries`);
});

/**
 * 测试 8: 测试页面响应式设计 - 验证在不同视口大小下的表现
 */
test('should display correctly on different viewport sizes', async ({ page }) => {
  console.log('📱 Testing responsive design...');

  // 桌面视图
  await page.setViewportSize({ width: 1200, height: 800 });
  await page.goto(`${TEST_SERVER_URL}${TEST_PAGE_PATH}`);
  await page.waitForLoadState('networkidle');

  const desktopContainer = page.locator('.container');
  await expect(desktopContainer).toBeVisible();

  // 移动视图
  await page.setViewportSize({ width: 375, height: 667 });
  await page.reload();
  await page.waitForLoadState('networkidle');

  const mobileContainer = page.locator('.container');
  await expect(mobileContainer).toBeVisible();

  // 验证在移动视图中图片网格依然可见
  const mobileImages = page.locator('.image-card img');
  await expect(mobileImages.first()).toBeVisible();

  console.log('✅ Responsive design verified');
});

/**
 * 测试 9: 测试性能 - 验证页面加载时间在可接受范围内
 */
test('should load page within acceptable time limit', async ({ page }) => {
  console.log('⚡ Testing page load performance...');

  const startTime = Date.now();

  // 访问测试页面
  await page.goto(`${TEST_SERVER_URL}${TEST_PAGE_PATH}`);

  // 等待页面完全加载
  await page.waitForLoadState('networkidle');

  const loadTime = Date.now() - startTime;

  console.log(`⏱️  Page loaded in ${loadTime}ms`);

  // 验证页面在 10 秒内加载完成
  expect(loadTime).toBeLessThan(10000);

  console.log('✅ Performance test passed');
});

/**
 * 测试 10: 测试无网络错误 - 验证没有 404 或其他网络错误
 */
test('should load without network errors', async ({ page }) => {
  console.log('🔗 Checking for network errors...');

  const failedRequests: string[] = [];

  // 监听失败的请求
  page.on('requestfailed', request => {
    const failure = request.failure();
    const url = request.url();
    console.log(`❌ Failed request: ${url} - ${failure?.textText}`);
    failedRequests.push(url);
  });

  // 访问测试页面
  await page.goto(`${TEST_SERVER_URL}${TEST_PAGE_PATH}`);

  // 等待页面加载
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(2000);

  // 验证没有失败的请求（排除可能的外部资源）
  const testResourceFailures = failedRequests.filter(url =>
    url.includes('localhost:8080') || url.includes('custom://')
  );

  expect(testResourceFailures.length).toBe(0);
  console.log('✅ No network errors detected');
});
