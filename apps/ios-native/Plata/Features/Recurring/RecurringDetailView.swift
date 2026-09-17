import SwiftUI

// Detalle de una suscripción / pago recurrente. Logo grande, resumen en frase
// ("Gastas $X cada mes en esta suscripción"), pills de próximo cobro / estado /
// categoría, selector de cuenta y botón "Confirmar pago" que registra la
// transacción, ajusta el saldo (RPC apply_account_delta) y avanza next_date.
// Menú para editar, pausar/reanudar y eliminar. Paridad con app/recurring/[id].

struct RecurringDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    let event: RecurringEvent

    @State private var selectedAccountId: String?
    @State private var isConfirming = false
    @State private var isPausing = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    private var category: Category? { app.category(for: event.categoryId) }
    private var tint: Color { RecurrentesVisual.tint(for: event, category: category) }
    private var logo: Image? { RecurrentesVisual.logo(for: event) }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        header
                        sentence
                        pills
                        accountSection
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                }
                .floatingTabBarInset()

                VStack {
                    Spacer()
                    confirmButton
                        .padding(.horizontal, Space.l)
                        .padding(.bottom, Space.s)
                        .padding(.top, Space.l)
                        // Velo neutro que desvanece el contenido al hacer scroll
                        // detrás del botón flotante (sin ocultar el glass del botón).
                        .background(
                            LinearGradient(
                                colors: [Palette.bg.opacity(0), Palette.bg.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .allowsHitTesting(false)
                            .ignoresSafeArea(edges: .bottom)
                        )
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEdit = true
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        Button {
                            togglePause()
                        } label: {
                            Label(event.isActive ? "Pausar" : "Reanudar",
                                  systemImage: event.isActive ? "pause.circle" : "play.circle")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                    }
                }
            }
            .toolbarBackground(.thinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Palette.accent)
        .onAppear {
            if selectedAccountId == nil {
                selectedAccountId = event.accountId ?? app.accounts.first?.id
            }
        }
        .sheet(isPresented: $showEdit) {
            AddRecurringView(editing: event)
                .presentationBackground(Palette.bg)
        }
        .alert("Eliminar suscripción", isPresented: $showDeleteConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) { delete() }
        } message: {
            Text("Se eliminará “\(event.name)”. Esta acción no se puede deshacer.")
        }
        .alert("Ocurrió un error", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Inténtalo de nuevo.")
        }
    }

    // MARK: - Encabezado con logo grande

    private var header: some View {
        HStack(spacing: Space.l) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(logo == nil ? tint.opacity(0.16) : Palette.surface)
                    .frame(width: 72, height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                logo == nil ? tint.opacity(0.22) : Palette.stroke.opacity(0.7),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                if let logo {
                    logo.resizable().scaledToFit().frame(width: 44, height: 44)
                } else {
                    Image(systemName: RecurrentesVisual.symbol(for: event, category: category))
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(event.name)
                    .font(Typo.title)
                    .tracking(-0.3)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Text(event.frequency.label)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Resumen en frase

    private var isIncome: Bool { event.type == .income }

    private var sentence: some View {
        (
            Text(isIncome ? "Cobras " : "Pagas ")
                .foregroundStyle(Palette.inkSecondary)
            + Text(CurrencyFormatter.string(event.amount, currency: app.currency))
                .foregroundStyle(isIncome ? Palette.positive : Palette.negative)
            + Text(" \(frequencyPhrase) por esta suscripción.")
                .foregroundStyle(Palette.inkSecondary)
        )
        .font(.system(size: 26, weight: .semibold, design: .rounded))
        .tracking(-0.4)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var frequencyPhrase: String {
        switch event.frequency {
        case .daily: return "cada día"
        case .weekly: return "cada semana"
        case .biweekly: return "cada quincena"
        case .monthly: return "una vez al mes"
        case .yearly: return "una vez al año"
        }
    }

    // MARK: - Pills de metadatos

    private var pills: some View {
        GlassGroup(spacing: Space.s) {
            VStack(alignment: .leading, spacing: Space.s) {
            RecurrentesInfoPill(
                symbol: "calendar",
                text: "Próximo pago: \(RecurrentesDate.fullLabel(event.nextDate))",
                tint: Palette.inkSecondary
            )
            RecurrentesInfoPill(
                symbol: event.isActive ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                text: event.isActive ? "Activa" : "Pausada",
                tint: event.isActive ? Palette.green : Palette.warning
            )
            if let category {
                RecurrentesInfoPill(
                    symbol: TransactionVisual.symbol(for: category, fallbackType: event.type),
                    text: category.name,
                    tint: TransactionVisual.color(for: category)
                )
            }
            RecurrentesInfoPill(
                symbol: "arrow.triangle.2.circlepath",
                text: "≈ \(CurrencyFormatter.string(RecurrentesMath.monthlyEquivalent(amount: event.amount, frequency: event.frequency), currency: app.currency)) \(isIncome ? "entran" : "salen") al mes",
                tint: isIncome ? Palette.positive : Palette.accent
            )
            }
        }
    }

    // MARK: - Selector de cuenta

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(isIncome ? "Cuenta para el cobro" : "Cuenta para el pago")
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)

            if app.accounts.isEmpty {
                Text(isIncome ? "No tienes cuentas. Crea una para confirmar cobros." : "No tienes cuentas. Crea una para confirmar pagos.")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(app.accounts) { account in
                            accountPill(account)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func accountPill(_ account: Account) -> some View {
        let isSelected = selectedAccountId == account.id
        let accentColor = Color(hexString: account.color) ?? Palette.sky
        return Button {
            withAnimation(Motion.press) { selectedAccountId = account.id }
        } label: {
            HStack(spacing: Space.s) {
                Image(systemName: account.type.sfSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? accentColor : Palette.inkSecondary)
                Text(account.name)
                    .font(Typo.callout)
                    .foregroundStyle(isSelected ? Palette.ink : Palette.inkSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.m)
            // Seleccionado: cápsula teñida sólida (no glass). Sin seleccionar:
            // glass sutil como track interactivo → nunca glass sobre glass.
            .modifier(AccountPillSurface(isSelected: isSelected, tint: accentColor))
        }
        .pressable()
    }

    // MARK: - Botón confirmar pago

    private var confirmButton: some View {
        PrimaryButton(
            title: isConfirming ? "Confirmando…" : (isIncome ? "Confirmar cobro" : "Confirmar pago"),
            icon: isConfirming ? nil : "checkmark.circle.fill",
            tint: canConfirm ? Palette.green : Palette.surfaceElevated,
            fg: canConfirm ? Palette.bg : Palette.inkTertiary
        ) {
            confirmPayment()
        }
        .disabled(!canConfirm || isConfirming)
    }

    private var canConfirm: Bool {
        event.isActive && selectedAccountId != nil
    }

    // MARK: - Acciones

    private func confirmPayment() {
        guard let accountId = selectedAccountId, let hh = app.household?.id, let uid = app.profile?.id else { return }
        isConfirming = true
        errorMessage = nil

        // income suma a la cuenta, expense resta — el delta lo aplica
        // Repository().addTransaction según el type (igual que el abono a deuda).
        let payload = NewTransaction(
            accountId: accountId,
            amount: event.amount,
            type: event.type,
            categoryId: event.categoryId,
            description: event.name,
            date: RecurrentesDate.iso(Date())
        )

        struct NextDateUpdate: Encodable { let next_date: String }
        let newNext = RecurrentesDate.advance(event.nextDate, by: event.frequency)

        Task {
            do {
                try await Repository().addTransaction(payload, householdId: hh, userId: uid)
                try await SupabaseClient.shared.update(
                    "recurring_events",
                    values: NextDateUpdate(next_date: newNext),
                    match: ["id": event.id]
                )
                await app.refreshAll()
                isConfirming = false
                dismiss()
            } catch {
                isConfirming = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func togglePause() {
        isPausing = true
        errorMessage = nil
        struct ActiveUpdate: Encodable { let is_active: Bool }
        let newActive = !event.isActive
        Task {
            do {
                try await SupabaseClient.shared.update(
                    "recurring_events",
                    values: ActiveUpdate(is_active: newActive),
                    match: ["id": event.id]
                )
                await app.refreshAll()
                isPausing = false
                dismiss()
            } catch {
                isPausing = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func delete() {
        errorMessage = nil
        // Baja lógica: is_active = false. fetchRecurring filtra por is_active,
        // así que el evento desaparece de la lista sin borrar histórico.
        struct ActiveUpdate: Encodable { let is_active: Bool }
        Task {
            do {
                try await SupabaseClient.shared.update(
                    "recurring_events",
                    values: ActiveUpdate(is_active: false),
                    match: ["id": event.id]
                )
                await app.refreshAll()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}

// MARK: - Fondo de pill de cuenta (glass sutil / teñido según selección)

private struct AccountPillSurface: ViewModifier {
    let isSelected: Bool
    let tint: Color

    func body(content: Content) -> some View {
        if isSelected {
            content
                .background(tint.opacity(0.16), in: Capsule())
                .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1))
        } else {
            content
                .liquidGlassCapsule(interactive: true)
                .overlay(Capsule().strokeBorder(Palette.stroke.opacity(0.5), lineWidth: 1))
        }
    }
}

// MARK: - Pill de información

private struct RecurrentesInfoPill: View {
    let symbol: String
    let text: String
    var tint: Color = Palette.inkSecondary

    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(Typo.callout)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s + 2)
        // Chip de estado con glass sutil (elemento interactivo/ligero). El tint
        // vive solo en el ícono → sin glass sobre glass ni tinte pesado.
        .liquidGlassCapsule()
        .overlay(Capsule().strokeBorder(Palette.stroke.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - Avance de fecha según frecuencia

extension RecurrentesDate {
    static func advance(_ isoDate: String, by frequency: Frequency) -> String {
        let base = parse(isoDate) ?? Date()
        let cal = Calendar.current
        var comp = DateComponents()
        switch frequency {
        case .daily: comp.day = 1
        case .weekly: comp.day = 7
        case .biweekly: comp.day = 14
        case .monthly: comp.month = 1
        case .yearly: comp.year = 1
        }
        let next = cal.date(byAdding: comp, to: base) ?? base
        return iso(next)
    }
}
