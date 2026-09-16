import Foundation
import PushKit

/// PushKit VoIP token manager with automatic registration
class PushKitManager: NSObject {
    private let tokenRegistry: TokenRegistry
    private let pushRegistry: PKPushRegistry
    private var currentVoIPToken: Data?

    weak var delegate: PushKitManagerDelegate?

    init(tokenRegistry: TokenRegistry) {
        self.tokenRegistry = tokenRegistry
        self.pushRegistry = PKPushRegistry(queue: .main)
        super.init()

        // Set delegate and register for VoIP push
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]

        self.tokenRegistry.delegate = self
    }

    /// Handle VoIP token registration
    /// - Parameter token: VoIP token data
    func didReceiveVoIPToken(_ token: Data) {
        // Check if token changed
        if currentVoIPToken == token {
            Logger.debug("VoIP token unchanged, skipping re-registration")
            return
        }

        currentVoIPToken = token

        let environment = Configuration.shared.environment.rawValue
        Logger.info("VoIP token received: \(Logger.tokenMasked(token)), environment: \(environment)")

        // Register with backend (separate subscription from APNs)
        tokenRegistry.registerToken(token, provider: "apns_voip", environment: environment)
    }
}

// MARK: - PKPushRegistryDelegate

extension PushKitManager: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }

        let token = credentials.token
        Logger.debug("PKPushRegistry didUpdate credentials for VoIP")

        didReceiveVoIPToken(token)
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }

        Logger.info("VoIP push received")

        // Parse payload and delegate to CallKit handler
        // TODO: Implement in TASK-006A-06 (CallKit Integration)
        delegate?.didReceiveVoIPPush(payload: payload.dictionaryPayload, completion: completion)
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }

        Logger.warning("VoIP push token invalidated")
        currentVoIPToken = nil
        delegate?.didInvalidateVoIPToken()
    }
}

// MARK: - TokenRegistryDelegate

extension PushKitManager: TokenRegistryDelegate {
    func didRegisterToken(provider: String) {
        guard provider == "apns_voip" else { return }
        delegate?.didRegisterVoIPToken()
    }

    func didFailToRegisterToken(provider: String, error: SDKError) {
        guard provider == "apns_voip" else { return }
        delegate?.didFailToRegisterVoIPToken(error: error)
    }
}

// MARK: - Delegate Protocol

protocol PushKitManagerDelegate: AnyObject {
    func didRegisterVoIPToken()
    func didFailToRegisterVoIPToken(error: SDKError)
    func didReceiveVoIPPush(payload: [AnyHashable: Any], completion: @escaping () -> Void)
    func didInvalidateVoIPToken()
}

// MARK: - Logger Extension

extension Logger {
    static func warning(_ message: String) {
        print("[PushPlatform WARNING] \(message)")
    }
}
