import Foundation

/// LRU cache for event deduplication (call_id, event_id)
/// Thread-safe, 100 entries max, 24h TTL
class DeduplicationCache {
    private var cache: [String: Date] = [:]
    private var insertionOrder: [String: UInt64] = [:]
    private var nextSequence: UInt64 = 0
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
                insertionOrder.removeValue(forKey: eventID)
                return false
            }

            return true
        }
    }

    /// Add event ID to cache. The update is synchronous so a following lookup sees it.
    func add(_ eventID: String) {
        queue.sync {
            self.nextSequence += 1
            self.cache[eventID] = Date()
            self.insertionOrder[eventID] = self.nextSequence

            while self.cache.count > self.maxEntries {
                self.evictOldest()
            }
        }
    }

    /// Remove event ID from cache. The update is synchronous so a following lookup sees it.
    func remove(_ eventID: String) {
        queue.sync {
            self.cache.removeValue(forKey: eventID)
            self.insertionOrder.removeValue(forKey: eventID)
        }
    }

    // MARK: - Private

    private func evictOldest() {
        guard let oldest = insertionOrder.min(by: { $0.value < $1.value }) else {
            return
        }
        cache.removeValue(forKey: oldest.key)
        insertionOrder.removeValue(forKey: oldest.key)
        Logger.debug("Evicted oldest event_id from deduplication cache")
    }
}
