import Foundation

/// 重试助手类
/// 提供异步重试机制，用于处理可能失败的临时性操作
public class RetryHelper {

    /// 执行带有重试机制的同步操作
    /// - Parameters:
    ///   - maxRetries: 最大重试次数（默认3次）
    ///   - delay: 重试之间的延迟时间（秒，默认1.0秒）
    ///   - operation: 要执行的操作，可以抛出错误
    /// - Returns: 操作成功的返回值
    /// - Throws: 如果所有重试都失败，抛出最后一次的错误
    public static func execute<T>(
        maxRetries: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let result = try operation()
                if attempt > 0 {
                    NSLog("✅ [RetryHelper] 操作成功（第 \(attempt + 1) 次尝试）")
                }
                return result
            } catch {
                lastError = error
                NSLog("⚠️ [RetryHelper] 第 \(attempt + 1) 次尝试失败: \(error.localizedDescription)")

                if attempt < maxRetries - 1 {
                    // 等待指定延迟时间
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        let finalError = lastError ?? WebBridgeError.cacheLoadFailed(reason: "Max retries exceeded")
        NSLog("❌ [RetryHelper] 所有重试均失败，最终错误: \(finalError.localizedDescription)")
        throw finalError
    }

    /// 执行带有重试机制的异步操作
    /// - Parameters:
    ///   - maxRetries: 最大重试次数（默认3次）
    ///   - delay: 重试之间的延迟时间（秒，默认1.0秒）
    ///   - operation: 要执行的异步操作，可以抛出错误
    /// - Returns: 操作成功的返回值
    /// - Throws: 如果所有重试都失败，抛出最后一次的错误
    public static func executeAsync<T>(
        maxRetries: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let result = try await operation()
                if attempt > 0 {
                    NSLog("✅ [RetryHelper] 异步操作成功（第 \(attempt + 1) 次尝试）")
                }
                return result
            } catch {
                lastError = error
                NSLog("⚠️ [RetryHelper] 第 \(attempt + 1) 次异步尝试失败: \(error.localizedDescription)")

                if attempt < maxRetries - 1 {
                    // 等待指定延迟时间
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        let finalError = lastError ?? WebBridgeError.cacheLoadFailed(reason: "Max retries exceeded")
        NSLog("❌ [RetryHelper] 所有异步重试均失败，最终错误: \(finalError.localizedDescription)")
        throw finalError
    }

    /// 执行带有指数退避的重试机制
    /// - Parameters:
    ///   - maxRetries: 最大重试次数（默认3次）
    ///   - baseDelay: 基础延迟时间（秒，默认1.0秒）
    ///   - operation: 要执行的操作，可以抛出错误
    /// - Returns: 操作成功的返回值
    /// - Throws: 如果所有重试都失败，抛出最后一次的错误
    /// - Discussion: 每次重试的延迟时间会指数增长（1秒、2秒、4秒...）
    public static func executeWithExponentialBackoff<T>(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        operation: @escaping () throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let result = try operation()
                if attempt > 0 {
                    NSLog("✅ [RetryHelper] 指数退避操作成功（第 \(attempt + 1) 次尝试）")
                }
                return result
            } catch {
                lastError = error
                NSLog("⚠️ [RetryHelper] 第 \(attempt + 1) 次尝试失败: \(error.localizedDescription)")

                if attempt < maxRetries - 1 {
                    // 计算指数退避延迟时间
                    let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
                    NSLog("⏳ [RetryHelper] 等待 \(exponentialDelay) 秒后重试...")
                    try? await Task.sleep(nanoseconds: UInt64(exponentialDelay * 1_000_000_000))
                }
            }
        }

        let finalError = lastError ?? WebBridgeError.cacheLoadFailed(reason: "Max retries exceeded")
        NSLog("❌ [RetryHelper] 所有指数退避重试均失败，最终错误: \(finalError.localizedDescription)")
        throw finalError
    }
}
