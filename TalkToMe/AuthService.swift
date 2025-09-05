// AuthService.swift

import Foundation
import LocalAuthentication

enum AuthService {
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "" // Hide “Enter Password” button text if you want only the system’s default

        let policy: LAPolicy = .deviceOwnerAuthentication // biometrics with passcode fallback

        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else {
            // Device doesn’t support biometrics/passcode policy (or it’s not enrolled)
            return false
        }

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            return success
        } catch {
            return false
        }
    }
}
