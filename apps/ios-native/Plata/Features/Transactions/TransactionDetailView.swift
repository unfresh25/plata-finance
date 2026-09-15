import SwiftUI

// Detalle de un movimiento. Paridad con app RN transaction/[id].tsx: una frase
// narrativa ("X gastó $Y hoy por concepto de …") con el color del signo, píldoras
// de fecha / tipo / categoría, y acción de eliminar. Los datos salen del propio
// `Transaction` + AppState (categoría, cuenta). Al eliminar, borra la fila en
// `transactions`, revierte el saldo de la cuenta vía RPC apply_account_delta y
// refresca AppState.

struct TransactionDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var isIncome: Bool { transaction.type == .income }

    private var category: Category? { app.category(for: transaction.categoryId) }

    private var account: Account? {
        app.accounts.first { $0.id == transaction.accountId }
    }

    private var signColor: Color { isIncome ? Palette.green : Palette.pink }

    // Nombre del autor: solo conocemos con certeza al usuario actual; para otros
    // miembros mostramos un genérico amable.
    private var creatorName: String {
        if transaction.createdBy == app.profile?.id, let n = app.profile?.name, !n.isEmpty {
            return n
        }
        return "Un miembro"
    }

    private var creatorInitial: String {
        String(creatorName.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            content
        }
        .navigationTitle("Movimiento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(Palette.pink)
            }
        }
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .tint(Palette.accent)
        .confirmationDialog(
            "¿Eliminar este movimiento?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { delete() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se ajustará el saldo de la cuenta automáticamente.")
        }
        .alert("No se pudo eliminar", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(deleteError ?? "Inténtalo de nuevo.")
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header
                sentence
                pills

                PrimaryButton(
                    title: isDeleting ? "Eliminando…" : "Eliminar movimiento",
                    icon: isDeleting ? nil : "trash",
                    tint: Palette.pink.opacity(0.16),
                    fg: Palette.pink
                ) {
                    showDeleteConfirm = true
                }
                .disabled(isDeleting)
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.l)
            .padding(.bottom, Space.xxl)
        }
    }

    // MARK: - Encabezado (autor)

    private var header: some View {
        HStack(spacing: Space.m) {
            Text(creatorInitial)
                .font(Typo.headline)
                .foregroundStyle(Palette.bg)
                .frame(width: 44, height: 44)
                .background(TransactionVisual.color(for: category), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(creatorName)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                Text("Miembro del hogar")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer()
        }
    }

    // MARK: - Frase narrativa

    private var sentence: some View {
        // Compone la frase con tramos de distinto color/peso, como el original.
        let concept = (transaction.description?.isEmpty == false
                       ? transaction.description!
                       : category?.name ?? "movimiento").lowercased()

        var text = Text(creatorName + (isIncome ? " recibió " : " gastó "))
            .foregroundColor(Palette.inkSecondary)
        text = text + Text(CurrencyFormatter.string(transaction.amount, currency: app.currency) + " ")
            .foregroundColor(signColor)
            .fontWeight(.heavy)
        text = text + Text(TransactionDetailDate.sentence(transaction.date) + " por concepto de ")
            .foregroundColor(Palette.inkSecondary)
        text = text + Text(concept + " ")
            .foregroundColor(Palette.ink)
            .fontWeight(.bold)
        text = text + Text(isIncome ? "en " : "desde ")
            .foregroundColor(Palette.inkSecondary)
        text = text + Text(account?.name ?? "una cuenta")
            .foregroundColor(Palette.ink)
            .fontWeight(.bold)
        text = text + Text(".").foregroundColor(Palette.inkSecondary)

        return text
            .font(.system(size: 26, weight: .medium))
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Píldoras

    private var pills: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            TransactionDetailPill(
                symbol: "calendar",
                text: TransactionDetailDate.short(transaction.date)
            )
            TransactionDetailPill(
                symbol: "wallet.pass",
                text: isIncome ? "Ingreso" : (transaction.type == .transfer ? "Transferencia" : "Gasto")
            )
            TransactionDetailPill(
                symbol: "folder",
                text: category?.name ?? "General"
            )
        }
    }

    // MARK: - Eliminar

    private func delete() {
        guard !isDeleting else { return }
        isDeleting = true
        deleteError = nil

        // Revertir el efecto en el saldo: un income eliminado resta; un expense suma.
        let revertDelta = isIncome ? -transaction.amount : transaction.amount

        Task {
            do {
                let _: EmptyResponse? = try? await SupabaseClient.shared.rpc(
                    "apply_account_delta",
                    params: ["p_account_id": transaction.accountId, "p_delta": revertDelta]
                )
                try await SupabaseClient.shared.deleteRow("transactions", match: ["id": transaction.id])
                await app.refreshAll()
                isDeleting = false
                dismiss()
            } catch {
                isDeleting = false
                deleteError = error.localizedDescription
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
    }
}

// MARK: - Píldora de metadato

private struct TransactionDetailPill: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
            Text(text)
                .font(Typo.callout)
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                .strokeBorder(Palette.stroke, lineWidth: 1)
        )
    }
}

// MARK: - Formato de fecha

enum TransactionDetailDate {
    private static func parse(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        return iso.date(from: String(raw.prefix(10)))
    }

    /// Tramo temporal para la frase narrativa: "hoy", "ayer", "el 5 de marzo".
    static func sentence(_ raw: String) -> String {
        guard let date = parse(raw) else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "hoy" }
        if cal.isDateInYesterday(date) { return "ayer" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "es_CO")
        out.dateFormat = "'el' d 'de' MMMM"
        return out.string(from: date)
    }

    /// Fecha corta para píldoras: "5 mar 2026".
    static func short(_ raw: String) -> String {
        guard let date = parse(raw) else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "es_CO")
        out.dateFormat = "d MMM yyyy"
        let text = out.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

// MARK: - DELETE (helper local sobre PostgREST)

extension SupabaseClient {
    /// Borra filas que cumplan `match` (igualdad). PostgREST exige un filtro para
    /// no permitir DELETE sin condición. Usa solo miembros públicos del cliente.
    func deleteRow(_ table: String, match: [String: String]) async throws {
        var comps = URLComponents(
            url: SupabaseConfig.url.appendingPathComponent("/rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = match.map { URLQueryItem(name: $0.key, value: "eq.\($0.value)") }

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "DELETE"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError(message: "Respuesta inválida del servidor.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                ?? String(data: data, encoding: .utf8)
                ?? "Error \(http.statusCode)"
            throw SupabaseError(message: msg)
        }
    }
}
