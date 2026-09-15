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
                    .padding(.bottom, Space.xxxl)
                }

                VStack {
                    Spacer()
                    confirmButton
                        .padding(.horizontal, Space.l)
                        .padding(.bottom, Space.s)
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
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
        .onAppear {
            if selectedAccountId == nil {
                selectedAccountId = event.accountId ?? app.accounts.first?.id
            }
        }
        .sheet(isPresented: $showEdit) {
            EditRecurringView(event: event)
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
                            .strokeBorder(Palette.stroke.opacity(logo == nil ? 0 : 1), lineWidth: 1)
                    )
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

    private var sentence: some View {
        (
            Text("Gastas ")
                .foregroundStyle(Palette.inkSecondary)
            + Text(CurrencyFormatter.string(event.amount, currency: app.currency))
                .foregroundStyle(Palette.ink)
            + Text(" \(frequencyPhrase) en esta suscripción.")
                .foregroundStyle(Palette.inkSecondary)
        )
        .font(.system(size: 26, weight: .semibold, design: .rounded))
        .lineSpacing(4)
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
                    symbol: TransactionVisual.symbol(for: category, fallbackType: .expense),
                    text: category.name,
                    tint: TransactionVisual.color(for: category)
                )
            }
            RecurrentesInfoPill(
                symbol: "arrow.triangle.2.circlepath",
                text: "≈ \(CurrencyFormatter.string(RecurrentesMath.monthlyEquivalent(amount: event.amount, frequency: event.frequency), currency: app.currency)) al mes",
                tint: Palette.accent
            )
        }
    }

    // MARK: - Selector de cuenta

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Cuenta para el pago")
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)

            if app.accounts.isEmpty {
                Text("No tienes cuentas. Crea una para confirmar pagos.")
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
            .background(
                isSelected ? accentColor.opacity(0.14) : Palette.surface,
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? accentColor : Palette.stroke, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .pressable()
    }

    // MARK: - Botón confirmar pago

    private var confirmButton: some View {
        PrimaryButton(
            title: isConfirming ? "Confirmando…" : "Confirmar pago",
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

        let payload = NewTransaction(
            accountId: accountId,
            amount: event.amount,
            type: .expense,
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
            Text(text)
                .font(Typo.callout)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .background(Palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
    }
}

// MARK: - Edición de recurrente (reutiliza pickers de Add)

struct EditRecurringView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @Namespace private var freqNS

    let event: RecurringEvent

    @State private var amountDigits: String
    @State private var name: String
    @State private var selectedLogo: String?
    @State private var frequency: Frequency
    @State private var categoryId: String?
    @State private var accountId: String?
    @State private var nextDate: Date

    @State private var showLogoPicker = false
    @State private var showCategoryPicker = false
    @State private var isSaving = false
    @State private var saveError: String?

    init(event: RecurringEvent) {
        self.event = event
        _amountDigits = State(initialValue: String(Int(event.amount.rounded())))
        _name = State(initialValue: event.name)
        _selectedLogo = State(initialValue: RecurrentesVisual.slug(for: event.name))
        _frequency = State(initialValue: event.frequency)
        _categoryId = State(initialValue: event.categoryId)
        _accountId = State(initialValue: event.accountId)
        _nextDate = State(initialValue: RecurrentesDate.parse(event.nextDate) ?? Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                content
            }
            .navigationTitle("Editar suscripción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.bg)
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Space.xl) {
                    logoHeader.padding(.top, Space.m)
                    amountDisplay
                    selectors
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.l)
            }
            .scrollDismissesKeyboard(.interactively)

            PrimaryButton(
                title: isSaving ? "Guardando…" : "Actualizar",
                icon: isSaving ? nil : "checkmark",
                tint: canSave ? Palette.accent : Palette.surfaceElevated,
                fg: canSave ? Palette.bg : Palette.inkTertiary
            ) {
                save()
            }
            .disabled(!canSave || isSaving)
            .padding(.horizontal, Space.l)
            .padding(.top, Space.m)
            .padding(.bottom, Space.s)
        }
        .sheet(isPresented: $showLogoPicker) {
            RecurrentesLogoPicker(selection: $selectedLogo) { slug in
                if name.trimmingCharacters(in: .whitespaces).isEmpty, let slug {
                    name = RecurrentesLogoName.display(for: slug)
                }
            }
            .presentationDetents([.large])
            .presentationBackground(Palette.bg)
        }
        .sheet(isPresented: $showCategoryPicker) {
            RecurrentesCategoryPicker(categories: expenseCategories, selection: $categoryId)
                .presentationDetents([.medium, .large])
                .presentationBackground(Palette.bg)
        }
        .alert("No se pudo guardar", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(saveError ?? "Inténtalo de nuevo.")
        }
    }

    private var logoHeader: some View {
        Button {
            showLogoPicker = true
        } label: {
            VStack(spacing: Space.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.surface)
                        .frame(width: 88, height: 88)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Palette.stroke, lineWidth: 1)
                        )
                    if let image = SubscriptionLogo.image(for: selectedLogo) {
                        image.resizable().scaledToFit().frame(width: 52, height: 52)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                }
                Text(selectedLogo == nil ? "Elegir logo de la app" : "Cambiar logo")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.accent)
            }
            .frame(maxWidth: .infinity)
        }
        .pressable()
    }

    private var amountDisplay: some View {
        VStack(spacing: Space.s) {
            Text("MONTO")
                .font(Typo.overline)
                .tracking(1.2)
                .foregroundStyle(Palette.inkTertiary)

            Text(formattedAmount)
                .font(Typo.amountHero(amountFontSize))
                .monospacedDigit()
                .foregroundStyle(amountValue > 0 ? Palette.ink : Palette.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText(value: amountValue))
                .animation(Motion.value, value: amountValue)

            RecurrentesKeypad { key in tap(key) }
                .padding(.top, Space.s)
        }
    }

    private var selectors: some View {
        VStack(spacing: Space.m) {
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    RecurrentesSmallIcon(symbol: "textformat", tint: Palette.orange)
                    TextField(
                        "",
                        text: $name,
                        prompt: Text("Ej. Netflix, Spotify, Arriendo").foregroundColor(Palette.inkTertiary)
                    )
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .submitLabel(.done)
                }
            }

            VStack(alignment: .leading, spacing: Space.s) {
                Text("Frecuencia")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.leading, Space.xs)
                PillToggle(options: freqOptions, selection: $frequency, namespace: freqNS)
            }

            Button {
                showCategoryPicker = true
            } label: {
                RecurrentesSelectorRow(
                    leading: {
                        if let cat = selectedCategory {
                            CategoryIcon(
                                systemName: TransactionVisual.symbol(for: cat, fallbackType: .expense),
                                color: TransactionVisual.color(for: cat),
                                size: 36
                            )
                        } else {
                            RecurrentesSmallIcon(symbol: "square.grid.2x2", tint: Palette.accent)
                        }
                    },
                    label: "Categoría",
                    value: selectedCategory?.name ?? "Seleccionar"
                )
            }
            .pressable()
            .disabled(expenseCategories.isEmpty)

            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    RecurrentesSmallIcon(symbol: selectedAccount?.type.sfSymbol ?? "creditcard", tint: Palette.sky)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Cuenta")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkTertiary)
                        Text(selectedAccount?.name ?? "Sin asignar")
                            .font(Typo.callout)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                    }
                    Spacer()
                    if !app.accounts.isEmpty {
                        Menu {
                            Button("Sin asignar") { accountId = nil }
                            ForEach(app.accounts) { acc in
                                Button(acc.name) { accountId = acc.id }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.inkTertiary)
                        }
                    }
                }
            }

            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    RecurrentesSmallIcon(symbol: "calendar", tint: Palette.purple)
                    Text("Próximo cobro")
                        .font(Typo.callout)
                        .foregroundStyle(Palette.inkSecondary)
                    Spacer()
                    DatePicker("", selection: $nextDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Palette.accent)
                }
            }
        }
    }

    private func tap(_ key: RecurrentesKeypadKey) {
        switch key {
        case .digit(let d):
            guard amountDigits.count < 12 else { return }
            if amountDigits.isEmpty && d == "0" { return }
            amountDigits.append(d)
        case .delete:
            if !amountDigits.isEmpty { amountDigits.removeLast() }
        case .clear:
            amountDigits = ""
        }
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        saveError = nil

        struct Update: Encodable {
            let name: String
            let amount: Double
            let frequency: String
            let next_date: String
            let category_id: String?
            let account_id: String?
        }
        let update = Update(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amountValue,
            frequency: frequency.rawValue,
            next_date: RecurrentesDate.iso(nextDate),
            category_id: categoryId,
            account_id: accountId
        )

        Task {
            do {
                try await SupabaseClient.shared.update("recurring_events", values: update, match: ["id": event.id])
                await app.refreshAll()
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }

    private var freqOptions: [(value: Frequency, label: String, tint: Color)] {
        [
            (.monthly, "Mensual", Palette.accent),
            (.weekly, "Semanal", Palette.accent),
            (.yearly, "Anual", Palette.accent),
        ]
    }

    private var amountValue: Double { Double(amountDigits) ?? 0 }
    private var formattedAmount: String { CurrencyFormatter.string(amountValue, currency: app.currency) }
    private var amountFontSize: CGFloat {
        switch formattedAmount.count {
        case ...9: return 52
        case 10...12: return 42
        case 13...15: return 34
        default: return 28
        }
    }
    private var expenseCategories: [Category] { app.categories.filter { $0.type == .expense } }
    private var selectedCategory: Category? { app.category(for: categoryId) }
    private var selectedAccount: Account? { app.accounts.first { $0.id == accountId } }
    private var canSave: Bool {
        amountValue > 0 && !name.trimmingCharacters(in: .whitespaces).isEmpty && categoryId != nil
    }
    private var errorBinding: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
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
