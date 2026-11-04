import FoundationModels
import SwiftUI

/// Every feature in this folder runs on the on-device model, with no network or API key.
enum ChefModel {
    static var statusDescription: String {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return "Unavailable" }
        return model.variant.displayName
    }

    /// Turns a failure into something a person can act on. `LanguageModelError` is non-exhaustive, so
    /// new cases fall through to the framework's own description.
    static func message(for error: any Error) -> String {
        if let error = error as? LanguageModelError {
            switch error {
            case .guardrailViolation:
                return "The model's safety checks blocked this. Try rewording your request."
            case .refusal:
                return "The model declined this request. Try asking for something else."
            case .contextSizeExceeded:
                return "This conversation is too long for the on-device model. Start a new one."
            case .unsupportedLanguageOrLocale:
                return "The on-device model doesn't support this language."
            case .rateLimited:
                return "The model is busy. Try again in a moment."
            case .timeout:
                return "The model took too long to respond. Try again."
            default:
                return error.localizedDescription
            }
        }
        #if targetEnvironment(simulator)
        return "The model couldn't run in this Simulator. Try again, or use a physical device."
        #else
        return error.localizedDescription
        #endif
    }
}

/// Shows its content only when the model can run, and otherwise says why it can't.
struct ModelGate<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        switch SystemLanguageModel.default.availability {
        case .available:
            content()
        case .unavailable(.deviceNotEligible):
            unavailable("This device doesn't support Apple Intelligence.", icon: "iphone.slash")
        case .unavailable(.appleIntelligenceNotEnabled):
            unavailable("Turn on Apple Intelligence in Settings to use this.", icon: "gear")
        case .unavailable(.modelNotReady):
            unavailable("The model is still downloading. Try again later.", icon: "arrow.down.circle")
        @unknown default:
            unavailable("The model isn't available right now.", icon: "exclamationmark.triangle")
        }
    }

    private func unavailable(_ message: String, icon: String) -> some View {
        ContentUnavailableView("Chef Isn't Available", systemImage: icon, description: Text(message))
    }
}
