/**
 * 全局测试设置
 * 在所有测试运行前执行一次
 */
import { FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  console.log('🚀 Starting global setup...');

  // 清理端口 8080 上的现有进程
  console.log('🧹 Cleaning up port 8080...');
  const { execSync } = await import('child_process');
  try {
    const pids = execSync('lsof -ti:8080', { encoding: 'utf-8' }).trim();
    if (pids) {
      console.log(`🔍 Found process(es) on port 8080: ${pids}`);
      execSync(`kill -9 ${pids}`, { encoding: 'utf-8' });
      console.log('✅ Killed existing process(es)');
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  } catch (error) {
    // No process found, that's fine
    console.log('ℹ️  No existing process on port 8080');
  }

  // 启动测试服务器
  console.log('📡 Starting test server on port 8080...');
  const { spawn } = await import('child_process');

  const serverProcess = spawn('python3', ['scripts/test_server.py'], {
    cwd: '/Users/xuyingzhou/Project/temporary/WebBridgeKit',
    stdio: 'pipe',
  });

  // 监听服务器输出以便调试
  serverProcess.stdout.on('data', (data) => {
    console.log(`[Server stdout]: ${data}`);
  });

  serverProcess.stderr.on('data', (data) => {
    console.error(`[Server stderr]: ${data}`);
  });

  serverProcess.on('error', (error) => {
    console.error(`[Server error]: ${error}`);
  });

  // 等待服务器启动 - 增加等待时间
  console.log('⏳ Waiting for server to be ready...');
  await new Promise(resolve => setTimeout(resolve, 3000));

  // 验证服务器是否启动成功
  try {
    const response = await fetch('http://localhost:8080/test_resources/manifest.json');
    if (response.ok) {
      console.log('✅ Test server is ready');
    } else {
      console.warn('⚠️  Test server responded with non-OK status');
    }
  } catch (error) {
    console.error('❌ Failed to connect to test server:', error);
    throw new Error('Test server failed to start');
  }

  console.log('✅ Global setup completed');
}

export default globalSetup;
