import SwiftUI

// Chat con IA sobre las finanzas del hogar (estilo Cleo). Estado vacío con
// saludo + chips de preguntas sugeridas; conversación con burbujas; input abajo.
// El contexto es un resumen precomputado (AppState.financeSummaryForChat) y la
// memoria de la conversación vive mientras el chat está abierto (ChatModel).

// MARK: - Modelo de mensaje

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

// MARK: - Modelo del chat (red + memoria de sesión)

@Observable
@MainActor
final class ChatModel {
    private(set) var messages: [ChatMessage] = []
    private(set) var isThinking = false
    var errorMessage: String?

    /// Envía una pregunta con el resumen del hogar como contexto y agrega la
    /// respuesta del asistente al hilo.
    func send(_ text: String, context: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }
        messages.append(ChatMessage(role: .user, text: trimmed))
        isThinking = true
        errorMessage = nil

        let history = messages.map {
            ChatWire.Message(role: $0.role == .user ? "user" : "assistant", content: $0.text)
        }

        Task {
            do {
                let reply = try await ChatModel.ask(context: context, messages: history)
                messages.append(ChatMessage(role: .assistant, text: reply))
            } catch {
                errorMessage = error.localizedDescription
            }
            isThinking = false
        }
    }

    /// Llama al backend /chat/ask (mismo patrón de red que el dictado/OCR).
    private static func ask(context: String, messages: [ChatWire.Message]) async throws -> String {
        let endpoint = SupabaseConfig.apiURL.appendingPathComponent("chat/ask")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseClient.shared.accessToken ?? "")",
                         forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(ChatWire.Request(context: context, messages: messages))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(ChatWire.ErrorBody.self, from: data))?.detail
            throw SupabaseError(message: detail ?? "No se pudo obtener respuesta.")
        }
        return try JSONDecoder().decode(ChatWire.Response.self, from: data).reply
    }
}

private enum ChatWire {
    struct Message: Codable { let role: String; let content: String }
    struct Request: Encodable { let context: String; let messages: [Message] }
    struct Response: Decodable { let reply: String }
    struct ErrorBody: Decodable { let detail: String? }
}

// MARK: - Vista

struct ChatView: View {
    @Environment(AppState.self) private var app
    var onClose: () -> Void = {}
    @State private var model = ChatModel()
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    // Preguntas sugeridas del estado vacío.
    private let suggestions = [
        "¿En qué gastamos más este mes?",
        "¿Cómo vamos con las metas?",
        "¿Cuánto llevamos gastado?",
        "Dame un consejo para ahorrar",
    ]

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            Group {
                if model.messages.isEmpty {
                    emptyState
                } else {
                    conversation
                }
            }
            // El input flota anclado al fondo (sube con el teclado) y deja hueco
            // para el tab bar flotante para no quedar tapado por él.
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
        }
        .navigationTitle("Plata IA")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .alert("No se pudo responder", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "Inténtalo de nuevo.")
        }
    }

    // MARK: Estado vacío

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Spacer(minLength: Space.xl)

                // Saludo + insight proactivo.
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Hola 👋")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(greetingInsight)
                        .font(Typo.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Chips de preguntas sugeridas.
                VStack(spacing: Space.s) {
                    ForEach(suggestions, id: \.self) { s in
                        Button {
                            model.send(s, context: app.financeSummaryForChat())
                        } label: {
                            HStack {
                                Text(s)
                                    .font(Typo.callout)
                                    .foregroundStyle(Palette.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: Space.s)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.accent)
                            }
                            .padding(Space.l)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                    .strokeBorder(Palette.stroke, lineWidth: 1)
                            )
                        }
                        .pressable()
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.l)
        }
    }

    /// Insight simple del resumen para el saludo.
    private var greetingInsight: String {
        let cur = app.currency
        if app.monthExpense > 0 {
            return "Este mes llevan \(CurrencyFormatter.string(app.monthExpense, currency: cur)) en gastos. Pregúntame lo que quieras sobre su plata."
        }
        return "Pregúntame lo que quieras sobre las finanzas del hogar."
    }

    // MARK: Conversación

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Space.m) {
                    ForEach(model.messages) { msg in
                        ChatBubble(message: msg).id(msg.id)
                    }
                    if model.isThinking {
                        HStack {
                            ThinkingDots()
                            Spacer()
                        }
                        .id("thinking")
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.messages.count) { _, _ in scrollToEnd(proxy) }
            .onChange(of: model.isThinking) { _, _ in scrollToEnd(proxy) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(Motion.ui) {
            if model.isThinking {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = model.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(spacing: Space.s) {
            TextField("Pregúntale a Plata…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .font(Typo.callout)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.s)
                .background(Palette.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(sendDraft)

            Button(action: sendDraft) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(canSend ? Palette.accent : Palette.inkTertiary)
            }
            .disabled(!canSend)
            .pressable(scale: 0.9)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isThinking
    }

    private func sendDraft() {
        guard canSend else { return }
        let text = draft
        draft = ""
        model.send(text, context: app.financeSummaryForChat())
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}

// MARK: - Burbuja

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(Self.rendered(message.text))
                .font(Typo.callout)
                .foregroundStyle(message.role == .user ? Palette.onAccent : Palette.ink)
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.s)
                .background(
                    message.role == .user ? Palette.accent : Palette.surface,
                    in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .strokeBorder(message.role == .user ? .clear : Palette.stroke, lineWidth: 1)
                )
                .textSelection(.enabled)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    /// Parsea markdown inline (negrita, cursiva, etc.) preservando los saltos de
    /// línea: AttributedString(markdown:) los colapsa, así que se procesa línea a
    /// línea y se reensambla con '\n'.
    private static func rendered(_ text: String) -> AttributedString {
        var out = AttributedString()
        let lines = text.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            if let parsed = try? AttributedString(
                markdown: line,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                out += parsed
            } else {
                out += AttributedString(line)
            }
            if i < lines.count - 1 { out += AttributedString("\n") }
        }
        return out
    }
}

// MARK: - Indicador "pensando"

private struct ThinkingDots: View {
    @State private var phase = 0.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Palette.inkTertiary)
                        .frame(width: 7, height: 7)
                        .opacity(0.4 + 0.6 * (0.5 + 0.5 * sin(t * 4 + Double(i) * 0.6)))
                }
            }
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
        }
    }
}
