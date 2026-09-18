import SwiftUI

// Cuentas conectadas (Syncfy). Lista las conexiones bancarias del hogar desde
// NUESTRA BD (funciona aunque Syncfy/el banco estén caídos), con "Actualizado
// hace X", y acciones: actualizar (re-sync), reconectar si requiere re-auth, y
// desconectar. Accesible desde Ajustes.

struct BankConnectionsView: View {
    @Environment(AppState.self) private var app
    @State private var connections: [BankConnection] = []
    @State private var loading = true
    @State private var busyCredential: String?
    @State private var errorMessage: String?
    @State private var reconnectTarget: BankConnection?

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            if loading {
                ProgressView().controlSize(.large).tint(Palette.accent)
            } else if connections.isEmpty {
                empty
            } else {
                list
            }
        }
        .navigationTitle("Cuentas conectadas")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("No se pudo", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: { Text(errorMessage ?? "Inténtalo de nuevo.") }
        .sheet(item: $reconnectTarget) { conn in
            ConnectBankView { Task { await load() } }
        }
    }

    private var empty: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "building.columns")
                .font(.system(size: 34)).foregroundStyle(Palette.inkTertiary)
            Text("No tienes bancos conectados")
                .font(Typo.callout).foregroundStyle(Palette.inkSecondary)
            Text("Conéctalos al crear una cuenta para traer saldos y movimientos solos.")
                .font(Typo.caption).foregroundStyle(Palette.inkTertiary)
                .multilineTextAlignment(.center).padding(.horizontal, Space.xl)
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: Space.l) {
                ForEach(connections) { conn in
                    connectionCard(conn)
                }
            }
            .padding(Space.l)
            .floatingTabBarInset()
        }
    }

    private func connectionCard(_ conn: BankConnection) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conn.institution).font(Typo.headline).foregroundStyle(Palette.ink)
                    Text(statusLine(conn)).font(Typo.caption).foregroundStyle(statusColor(conn))
                }
                Spacer()
                if busyCredential == conn.provider_credential_id {
                    ProgressView().controlSize(.small).tint(Palette.accent)
                }
            }

            ForEach(conn.accounts ?? []) { acc in
                HStack {
                    Text(acc.name).font(Typo.callout).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(CurrencyFormatter.string(acc.balance, currency: acc.currency ?? app.currency))
                        .font(Typo.callout.weight(.semibold)).foregroundStyle(Palette.ink)
                }
                .padding(.vertical, Space.xs)
            }

            HStack(spacing: Space.s) {
                if conn.status == "requires_reauth" {
                    actionButton("Reconectar", icon: "arrow.clockwise.circle") { reconnectTarget = conn }
                } else {
                    actionButton("Actualizar", icon: "arrow.clockwise") {
                        Task { await refresh(conn) }
                    }
                }
                actionButton("Desconectar", icon: "trash", destructive: true) {
                    Task { await disconnect(conn) }
                }
            }
        }
        .padding(Space.l)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
    }

    private func actionButton(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).font(Typo.caption.weight(.medium))
            }
            .foregroundStyle(destructive ? Palette.negative : Palette.accent)
            .padding(.vertical, Space.xs).padding(.horizontal, Space.m)
            .background((destructive ? Palette.negative : Palette.accent).opacity(0.12), in: Capsule())
        }
        .pressable()
    }

    // MARK: - Estado / textos

    private func statusLine(_ conn: BankConnection) -> String {
        switch conn.status {
        case "requires_reauth": return "Necesita reconectarse"
        case "error": return "Error al sincronizar"
        case "syncing": return "Sincronizando…"
        default: return "Actualizado \(relativeDate(conn.last_successful_sync_at))"
        }
    }

    private func statusColor(_ conn: BankConnection) -> Color {
        switch conn.status {
        case "requires_reauth", "error": return Palette.negative
        default: return Palette.inkTertiary
        }
    }

    private func relativeDate(_ iso: String?) -> String {
        guard let iso, let date = ISO8601DateFormatter().date(from: iso) ??
                ISO8601DateFormatter.withFractional.date(from: iso) else { return "hace poco" }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_CO")
        return f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Acciones

    private func load() async {
        loading = connections.isEmpty
        do { connections = try await BankService.connections() }
        catch { errorMessage = error.localizedDescription }
        loading = false
    }

    private func refresh(_ conn: BankConnection) async {
        busyCredential = conn.provider_credential_id
        do {
            let s = try await BankService.session()
            try await BankService.sync(token: s.token, idCredential: conn.provider_credential_id)
            await load()
            await app.refreshAll()
        } catch { errorMessage = error.localizedDescription }
        busyCredential = nil
    }

    private func disconnect(_ conn: BankConnection) async {
        busyCredential = conn.provider_credential_id
        do {
            let s = try await BankService.session()
            try await BankService.disconnect(token: s.token, idCredential: conn.provider_credential_id)
            await load()
        } catch { errorMessage = error.localizedDescription }
        busyCredential = nil
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}

private extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
