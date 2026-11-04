import Foundation
import PushPlatformSDK
import PushPlatformExtension

// Touch symbols from both modules so a static link must resolve Extension.
_ = String(describing: PushPlatform.self)
_ = String(describing: PushPlatformExtension.self)
print("static-pod-smoke-ok")
