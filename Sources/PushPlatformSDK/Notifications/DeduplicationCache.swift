import Foundation

/// LRU cache for event deduplication (call_id, event_id)
/// Thread-safe, 100 entries max, 24h TTL
class DeduplicationCache {
    private var cache: [String: Date] = [:]
    private let maxEntries = 100
    private let ttl: TimeInterval = 86400  // 24 hours
    private let queue = DispatchQueue(label: "com.pushplatform.sdk.deduplication")

    // MARK: - Public API

    /// Check if event ID exists in cache and is still valid
    func contains(_ eventID: String) -> Bool {
        queue.sync {
            guard let timestamp = cache[eventID] else {
                return false
            }

            // Check TTL
            if Date().timeIntervalSince(timestamp) > ttl {
                cache.removeValue(forKey: eventID)
                return false
            }

            return true
        }
    }

    /// Add event ID to cache
    func add(_ eventID: String) {
        queue.async {
            self.cache[eventID] = Date()

            // LRU eviction
            if self.cache.count > self.maxEntries {
                self.evictOldest()
            }
        }
    }

    /// Remove event ID from cache
    func remove(_ eventID: String) {
        queue.async {
            self.cache.removeValue(forKey: eventID)
        }
    }

    // MARK: - Private

    private func evictOldest() {
        guard let oldest = cache.min(by: { $0.value < $1.value }) else {
            return
        }
        cache.removeValue(forKey: oldest.key)
        Logger.debug("Evicted oldest event_id from deduplication cache")
    }
}
