import Foundation
import Network

/// Network reachability monitor for connection restore detection
class Reachability {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.pushplatform.sdk.network")
    private var isConnected = false
    private var onConnectionRestored: (() -> Void)?

    /// Start monitoring network status
    /// - Parameter onConnectionRestored: Callback when connection is restored
    func startMonitoring(onConnectionRestored: @escaping () -> Void) {
        self.onConnectionRestored = onConnectionRestored

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let wasConnected = self.isConnected
            self.isConnected = (path.status == .satisfied)

            if !wasConnected && self.isConnected {
                Logger.info("Network connection restored")
                DispatchQueue.main.async {
                    self.onConnectionRestored?()
                }
            }
        }

        monitor.start(queue: queue)
    }

    /// Stop monitoring network status
    func stopMonitoring() {
        monitor.cancel()
    }

    /// Current connection status
    var isReachable: Bool {
        return isConnected
    }
}
