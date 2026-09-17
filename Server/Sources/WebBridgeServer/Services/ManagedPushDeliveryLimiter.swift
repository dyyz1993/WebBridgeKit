import Foundation

/// Bounds APNs signing work for a single bearer `deviceKey`. The capability
/// still authorizes normal delivery; this only prevents an accidentally shared
/// key from becoming an unbounded notification/cost amplifier. State is
/// intentionally in-memory: a process restart clears throttling but cannot
/// reveal or alter a registration.
actor ManagedPushDeliveryLimiter {
  private let maxDeliveries: Int
  private let window: TimeInterval
  private var timestamps: [String: [Date]] = [:]

  init(maxDeliveries: Int = 60, window: TimeInterval = 60) {
    self.maxDeliveries = max(1, maxDeliveries)
    self.window = max(1, window)
  }

  func allow(deviceKey: String, now: Date = Date()) -> Bool {
    let cutoff = now.addingTimeInterval(-window)
    var recent = (timestamps[deviceKey] ?? []).filter { $0 > cutoff }
    guard recent.count < maxDeliveries else {
      timestamps[deviceKey] = recent
      return false
    }
    recent.append(now)
    timestamps[deviceKey] = recent
    return true
  }
}
