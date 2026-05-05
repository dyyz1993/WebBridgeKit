/**
 * 全局测试清理
 * 在所有测试运行后执行一次
 */
import { FullConfig } from '@playwright/test';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

async function globalTeardown(config: FullConfig) {
  console.log('🧹 Starting global teardown...');

  try {
    // 通过端口号查找并终止进程
    const { stdout } = await execAsync("lsof -ti:8080");
    const pids = stdout.trim().split('\n').filter(Boolean);

    if (pids.length > 0) {
      console.log(`🔍 Found ${pids.length} process(es) on port 8080`);

      for (const pid of pids) {
        try {
          await execAsync(`kill -9 ${pid}`);
          console.log(`✅ Killed process ${pid}`);
        } catch (error) {
          console.warn(`⚠️  Failed to kill process ${pid}:`, error);
        }
      }

      // 等待进程完全终止
      await new Promise(resolve => setTimeout(resolve, 1000));

      console.log('✅ Test server stopped');
    } else {
      console.log('ℹ️  No processes found on port 8080');
    }
  } catch (error) {
    console.warn('⚠️  Error during teardown:', error);
  }

  console.log('✅ Global teardown completed');
}

export default globalTeardown;
