import Foundation
import CallKit
import PushKit

/// CallKit integration for incoming VoIP calls
class CallKitIntegration: NSObject {
    private let provider: CXProvider
    private let callController: CXCallController
    private let deduplicationCache: DeduplicationCache

    weak var delegate: CallKitIntegrationDelegate?

    override init() {
        // Configure CallKit provider
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]

        self.provider = CXProvider(configuration: configuration)
        self.callController = CXCallController()
        self.deduplicationCache = DeduplicationCache()

        super.init()

        provider.setDelegate(self, queue: nil)
    }

    // MARK: - VoIP Push Handling

    /// Handle incoming VoIP push and register with CallKit
    /// - Parameters:
    ///   - payload: VoIP push payload
    ///   - completion: Completion handler (must be called for PushKit compliance)
    func handleIncomingVoIPPush(payload: [AnyHashable: Any], completion: @escaping () -> Void) {
        // Parse required fields
        guard let callID = payload["call_id"] as? String,
              let callerName = payload["caller_name"] as? String else {
            Logger.error("VoIP push missing call_id or caller_name")
            completion()
            return
        }

        // CRITICAL: Check deduplication BEFORE CallKit
        if deduplicationCache.contains(callID) {
            Logger.debug("Duplicate call_id: \(callID), ignoring")
            completion()
            return
        }

        // Add to deduplication cache
        deduplicationCache.add(callID)

        // Convert call_id to UUID (required by CallKit)
        guard let callUUID = UUID(uuidString: callID) else {
            Logger.error("Invalid call_id UUID format: \(callID)")
            completion()
            return
        }

        // Configure CallKit update
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.hasVideo = false
        update.localizedCallerName = callerName

        // CRITICAL: Report incoming call immediately (Apple requirement)
        Logger.info("Registering CallKit incoming call: \(callID)")

        provider.reportNewIncomingCall(with: callUUID, update: update) { [weak self] error in
            if let error = error {
                Logger.error("CallKit registration failed: \(error.localizedDescription)")
                // Remove from dedup cache on failure (allow retry)
                self?.deduplicationCache.remove(callID)
            } else {
                Logger.info("CallKit incoming call registered: \(callID)")

                // Notify app delegate (optional)
                let metadata = payload as? [String: Any] ?? [:]
                self?.delegate?.didReceiveIncomingCall(
                    callID: callID,
                    callerName: callerName,
                    metadata: metadata
                )
            }

            completion()
        }
    }
}

// MARK: - CXProviderDelegate

extension CallKitIntegration: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        Logger.info("CallKit provider reset")
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Logger.info("CallKit: Answer call action")
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Logger.info("CallKit: End call action")
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        Logger.debug("CallKit: Audio session activated")
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Logger.debug("CallKit: Audio session deactivated")
    }
}

// MARK: - Delegate Protocol

protocol CallKitIntegrationDelegate: AnyObject {
    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any])
}
