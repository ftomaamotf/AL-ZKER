import LocalAuthentication

enum BiometricStatisticsDeletionAuthorizer {
    struct Failure: Error {
        let message: String
    }

    /// Requires Face ID or Touch ID only. Device passcode is intentionally not accepted.
    static func authorize() async -> Result<Void, Failure> {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .failure(Failure(message: "فعّل بصمة الوجه أو بصمة الإصبع في إعدادات الآيفون أولاً."))
        }

        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "تأكيد حذف إحصاءات الذكر"
            )
            return .success(())
        } catch {
            return .failure(Failure(message: "لم يتم تأكيد البصمة، لذلك لم تُحذف الإحصاءات."))
        }
    }
}
