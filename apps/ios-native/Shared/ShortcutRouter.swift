import Foundation

// Canal entre los App Intents y la UI. La app observa `pending` y ejecuta la
// acción al abrir. Compartido por app y widget (los intents lo referencian).

@MainActor
final class ShortcutRouter: ObservableObject {
    static let shared = ShortcutRouter()
    @Published var pending: Action?

    enum Action: Equatable {
        case dictar
        case chat
        case capturePayment(amount: Double, merchant: String)
    }
}
