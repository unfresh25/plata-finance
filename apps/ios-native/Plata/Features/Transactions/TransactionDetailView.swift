import SwiftUI

// Detalle de un movimiento. Rediseño FLAT (sin cards): encabezado con el MIEMBRO
// REAL que registró el movimiento (AvatarView + nombre real vía app.member),
// una frase narrativa en texto plano ("X gastó $Y hoy por concepto de …") y los
// metadatos como filas planas separadas por hairlines (PlainSection/PlainList),
// sin fondos de container. Acciones: Editar (abre AddTransaction) y Eliminar
// (destructivo). Al eliminar, borra la fila en `transactions`, revierte el saldo
// de la cuenta vía RPC apply_account_delta y refresca AppState.

struct TransactionDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showEdit = false

    private var isIncome: Bool { transaction.type == .income }

    private var category: Category? { app.category(for: transaction.categoryId) }

    private var account: Account? {
        app.accounts.first { $0.id == transaction.accountId }
    }

    private var signColor: Color { isIncome ? Palette.green : Palette.pink }

    // Miembro real del hogar que registró el movimiento (created_by). Si no se
    // resuelve el perfil (miembro fuera de caché), caemos en un genérico amable.
    private var creator: Profile? { app.member(for: transaction.createdBy) }

    private var creatorName: String {
        let name = creator?.name.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? "Un miembro" : name
    }

    // Logo de app conocida (Spotify, Netflix…) si la descripción coincide.
    private var appLogo: Image? {
        let source = transaction.description?.isEmpty == false
            ? transaction.description!
            : (category?.name ?? "")
        return SubscriptionLogo.image(for: TransactionDetailLogo.slug(for: source))
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
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(Palette.accent)
        .sheet(isPresented: $showEdit) {
            // Edición aún no soportada como flujo dedicado: reutilizamos la
            // pantalla de alta (ver nota en el resumen). Al cerrarse, refrescamos.
            AddTransactionView()
        }
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
            VStack(alignment: .leading, spacing: Space.xxl) {
                header
                sentence
                details
                actions
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.l)
            .padding(.bottom, Space.xxl)
        }
    }

    // MARK: - Encabezado (autor real)

    private var header: some View {
        HStack(spacing: Space.m) {
            AvatarView(name: creatorName, urlString: creator?.avatarUrl, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(creatorName)
                    .font(Typo.headline)
                    .tracking(-0.2)
                    .foregroundStyle(Palette.ink)
                Text(isIncome ? "Registró este ingreso" : "Registró este gasto")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer(minLength: Space.s)
            // Logo de la app o ícono de categoría, con aire (RowLeadingIcon).
            RowLeadingIcon(
                logo: appLogo,
                systemName: TransactionVisual.symbol(for: category, fallbackType: transaction.type),
                color: TransactionVisual.color(for: category),
                size: 44
            )
        }
    }

    // MARK: - Frase narrativa (texto plano, sin card)

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
            .tracking(-0.4)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Detalles (filas planas con hairlines, sin card)

    private var details: some View {
        PlainSection(title: "Detalles") {
            PlainList(detailRows, dividerInset: 0) { row in
                TransactionDetailRow(symbol: row.symbol, label: row.label, value: row.value)
            }
        }
    }

    private var detailRows: [TransactionDetailRowModel] {
        var rows: [TransactionDetailRowModel] = [
            .init(id: "fecha", symbol: "calendar", label: "Fecha",
                  value: TransactionDetailDate.short(transaction.date)),
            .init(id: "tipo", symbol: "arrow.left.arrow.right", label: "Tipo",
                  value: typeLabel),
            .init(id: "categoria", symbol: "folder", label: "Categoría",
                  value: category?.name ?? "General"),
        ]
        if let account {
            rows.append(.init(id: "cuenta", symbol: "creditcard", label: "Cuenta", value: account.name))
        }
        return rows
    }

    private var typeLabel: String {
        isIncome ? "Ingreso" : (transaction.type == .transfer ? "Transferencia" : "Gasto")
    }

    // MARK: - Acciones (Editar + Eliminar)

    private var actions: some View {
        VStack(spacing: Space.m) {
            SecondaryButton(title: "Editar movimiento", icon: "pencil") {
                showEdit = true
            }
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

// MARK: - Fila de metadato plana (label a la izquierda, valor a la derecha)

private struct TransactionDetailRowModel: Identifiable {
    let id: String
    let symbol: String
    let label: String
    let value: String
}

private struct TransactionDetailRow: View {
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 20)
            Text(label)
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
            Spacer(minLength: Space.m)
            Text(value)
                .font(Typo.callout)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Resolución de logo de app conocida por texto

private enum TransactionDetailLogo {
    /// Deriva el slug de logo (Spotify, Netflix…) del texto del movimiento,
    /// comparando contra el catálogo de SubscriptionLogo. Nil si no hay match.
    static func slug(for text: String) -> String? {
        let n = text
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return nil }
        for slug in SubscriptionLogo.all {
            let key = slug.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespaces)
            guard key.count >= 3 else { continue }
            if n.contains(key) { return slug }
        }
        return nil
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
