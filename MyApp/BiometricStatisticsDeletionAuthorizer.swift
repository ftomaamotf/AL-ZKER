import LocalAuthentication

enum BiometricStatisticsDeletionAuthorizer {
    struct Failure: Error {
        let message: String
    }

    /// Uses Face ID or Touch ID first, with the iPhone passcode as the secure fallback.
    static func authorize(
        reason: String = "تأكيد حذف إحصاءات الذكر",
        failureMessage: String = "لم يتم تأكيد البصمة، لذلك لم تُحذف الإحصاءات."
    ) async -> Result<Void, Failure> {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .failure(Failure(message: "فعّل رمز دخول للآيفون أولاً."))
        }

        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return .success(())
        } catch {
            return .failure(Failure(message: failureMessage))
        }
    }
}
