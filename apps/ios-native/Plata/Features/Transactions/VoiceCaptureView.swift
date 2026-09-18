import SwiftUI

// Captura de un movimiento por voz. Botón de micrófono grande "hold-to-talk":
// se mantiene pulsado para hablar, se suelta para interpretar. Muestra la
// transcripción en vivo y ondas reactivas al nivel de audio. Al soltar, manda
// el texto al backend (Gemini) y devuelve los campos por onParsed; la pantalla
// de nuevo movimiento precarga el formulario (el usuario confirma antes de guardar).

struct VoiceCaptureView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    /// Devuelve los campos interpretados a AddTransactionView.
    var onParsed: (ParsedTransaction) -> Void

    @State private var speech = SpeechRecognizer()
    @State private var phase: Phase = .idle
    @State private var errorMessage: String?

    private enum Phase: Equatable {
        case idle, recording, processing
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.opacity(0.6).ignoresSafeArea()

                VStack(spacing: Space.xl) {
                    Spacer(minLength: 0)

                    prompt

                    Spacer(minLength: 0)

                    micButton

                    Text(hint)
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(height: 22)
                        .animation(Motion.ui, value: phase)

                    Spacer(minLength: Space.l)
                }
                .padding(.horizontal, Space.xl)
            }
            .navigationTitle("Dictar movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .tint(Palette.accent)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .glassSheetBackground()
        .alert("No se pudo dictar", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Inténtalo de nuevo.")
        }
    }

    // MARK: - Texto transcrito / ejemplo

    @ViewBuilder
    private var prompt: some View {
        if speech.transcript.isEmpty {
            VStack(spacing: Space.m) {
                Text("Cuéntame el movimiento")
                    .font(Typo.title)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text("Ej. “Gasté 50 mil en el mercado con la débito”")
                    .font(Typo.body)
                    .foregroundStyle(Palette.inkTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .transition(.opacity)
        } else {
            Text(speech.transcript)
                .font(Typo.title)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
                .animation(Motion.ui, value: speech.transcript)
        }
    }

    // MARK: - Botón de micrófono (hold-to-talk) con ondas

    private var micButton: some View {
        ZStack {
            // Ondas reactivas al nivel de audio (solo mientras graba).
            if phase == .recording {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Palette.accent.opacity(0.35 - Double(i) * 0.1), lineWidth: 2)
                        .frame(width: 96, height: 96)
                        .scaleEffect(1 + CGFloat(speech.level) * (0.6 + CGFloat(i) * 0.4))
                        .opacity(phase == .recording ? 1 : 0)
                        .animation(.easeOut(duration: 0.15), value: speech.level)
                }
            }

            Circle()
                .fill(phase == .recording ? Palette.accent : Palette.accent.opacity(0.9))
                .frame(width: 96, height: 96)
                .overlay {
                    if phase == .processing {
                        ProgressView().tint(Palette.onAccent).controlSize(.large)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Palette.onAccent)
                            .scaleEffect(phase == .recording ? 1.1 : 1)
                    }
                }
                .scaleEffect(phase == .recording ? 1.08 : 1)
                .shadow(color: Palette.accent.opacity(0.4), radius: phase == .recording ? 24 : 12, y: 6)
                .animation(Motion.ui, value: phase)
        }
        .frame(height: 180)
        // Hold-to-talk: presionar inicia, soltar procesa. Umbral 0 para arrancar ya.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if phase == .idle { beginRecording() } }
                .onEnded { _ in if phase == .recording { endRecording() } }
        )
        .disabled(phase == .processing)
    }

    private var hint: String {
        switch phase {
        case .idle: return "Mantén pulsado para hablar"
        case .recording: return "Suelta para interpretar"
        case .processing: return "Interpretando…"
        }
    }

    // MARK: - Flujo

    private func beginRecording() {
        phase = .recording
        Task {
            await speech.start()
            // Si arrancar falló (permiso/no disponible), volver a idle y mostrar error.
            if !speech.isRecording {
                phase = .idle
                if let msg = speech.errorMessage { errorMessage = msg }
            }
        }
    }

    private func endRecording() {
        speech.stop()
        let text = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            phase = .idle
            return
        }
        phase = .processing
        Task { await parse(text: text) }
    }

    /// Manda el texto + categorías/cuentas del hogar al backend y devuelve los
    /// campos. Mismo patrón de red que el OCR (URLSession + JWT del usuario).
    private func parse(text: String) async {
        do {
            let endpoint = SupabaseConfig.apiURL.appendingPathComponent("parse/transaction")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(
                "Bearer \(SupabaseClient.shared.accessToken ?? "")",
                forHTTPHeaderField: "Authorization"
            )

            let body = ParseRequestBody(
                text: text,
                categories: app.categories.map {
                    .init(id: $0.id, name: $0.name, type: $0.type == .income ? "income" : "expense")
                },
                accounts: app.accounts.map { .init(id: $0.id, name: $0.name) },
                today: Self.isoToday()
            )
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let detail = (try? JSONDecoder().decode(ParseErrorBody.self, from: data))?.detail
                throw SupabaseError(message: detail ?? "No se pudo interpretar el dictado.")
            }

            let parsed = try JSONDecoder().decode(ParsedTransaction.self, from: data)
            onParsed(parsed)
            dismiss()
        } catch {
            phase = .idle
            errorMessage = error.localizedDescription
        }
    }

    private static func isoToday() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}

// MARK: - Payload y respuesta

/// Campos interpretados que devuelve el backend (POST /parse/transaction).
struct ParsedTransaction: Decodable {
    let amount: Double?
    let type: String?          // income | expense | transfer
    let description: String?
    let date: String?          // yyyy-MM-dd
    let categoryId: String?
    let accountId: String?

    enum CodingKeys: String, CodingKey {
        case amount, type, description, date
        case categoryId = "category_id"
        case accountId = "account_id"
    }
}

private struct ParseRequestBody: Encodable {
    struct Cat: Encodable { let id: String; let name: String; let type: String }
    struct Acc: Encodable { let id: String; let name: String }
    let text: String
    let categories: [Cat]
    let accounts: [Acc]
    let today: String
}

private struct ParseErrorBody: Decodable {
    let detail: String?
}
