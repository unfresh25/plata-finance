import SwiftUI

// Pago de una tarjeta de crédito: mueve dinero de otra cuenta a la tarjeta para
// liberar cupo. El monto reduce la deuda; los intereses/adicionales (opcionales)
// se descuentan de la cuenta origen pero NO reducen la deuda. Todo atómico vía la
// RPC pay_credit_card.

struct PayCreditCardView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    /// Tarjeta a pagar. Si viene nil, se elige entre las tarjetas del hogar.
    var card: Account?

    @State private var selectedCardId: String?
    @State private var amountDigits = ""
    @State private var sourceAccountId: String?
    @State private var hasFees = false
    @State private var feesDigits = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var amountFocused: Bool

    private var creditCards: [Account] { app.accounts.filter { $0.isCredit } }
    private var sourceAccounts: [Account] { app.accounts.filter { !$0.isCredit } }
    private var activeCard: Account? {
        if let card { return card }
        return app.accounts.first { $0.id == selectedCardId }
    }

    private var amount: Double { Double(amountDigits) ?? 0 }
    private var fees: Double { hasFees ? (Double(feesDigits) ?? 0) : 0 }
    private var canSave: Bool { amount > 0 && sourceAccountId != nil && activeCard != nil && !isSaving }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: Space.xl) {
                            amountHero.padding(.top, Space.m)
                            formCard
                        }
                        .padding(.horizontal, Space.l).padding(.bottom, Space.l)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    PrimaryButton(
                        title: isSaving ? "Pagando…" : "Pagar tarjeta",
                        icon: isSaving ? nil : "creditcard.and.123",
                        tint: canSave ? Palette.accent : Palette.surfaceElevated,
                        fg: canSave ? Palette.bg : Palette.inkTertiary
                    ) { save() }
                    .disabled(!canSave)
                    .padding(.horizontal, Space.l).padding(.top, Space.m).padding(.bottom, Space.s)
                }
            }
            .navigationTitle("Pagar tarjeta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Palette.inkSecondary)
                }
            }
            .alert("No se pudo pagar", isPresented: errorBinding) {
                Button("Entendido", role: .cancel) {}
            } message: { Text(saveError ?? "Inténtalo de nuevo.") }
        }
        .tint(Palette.accent)
        .presentationDragIndicator(.visible)
        .glassSheetBackground()
        .onAppear {
            if selectedCardId == nil { selectedCardId = card?.id ?? creditCards.first?.id }
            if sourceAccountId == nil { sourceAccountId = sourceAccounts.first?.id }
            amountFocused = true
        }
    }

    private var amountHero: some View {
        VStack(spacing: Space.xs) {
            Text("MONTO A PAGAR").font(Typo.overline).tracking(1.2).foregroundStyle(Palette.accent)
            ZStack {
                Text(CurrencyFormatter.string(amount, currency: app.currency))
                    .font(Typo.amountHero(amount > 0 ? 52 : 44))
                    .monospacedDigit().tracking(-0.5)
                    .foregroundStyle(amount > 0 ? Palette.ink : Palette.inkTertiary)
                    .lineLimit(1).minimumScaleFactor(0.4)
                    .contentTransition(.numericText(value: amount))
                    .animation(Motion.value, value: amount)
                    .frame(maxWidth: .infinity)
                TextField("", text: $amountDigits)
                    .keyboardType(.numberPad).focused($amountFocused)
                    .foregroundStyle(.clear).tint(.clear).multilineTextAlignment(.center)
                    .onChange(of: amountDigits) { _, v in
                        let clean = String(v.filter(\.isNumber).prefix(12))
                        if clean != v { amountDigits = clean }
                    }
            }
            .contentShape(Rectangle()).onTapGesture { amountFocused = true }

            if let c = activeCard, let debt = Optional(c.balance), debt > 0 {
                Button {
                    amountDigits = String(Int(debt.rounded()))
                } label: {
                    Text("Deuda: \(CurrencyFormatter.string(debt, currency: app.currency)) · Pagar todo")
                        .font(Typo.caption).foregroundStyle(Palette.accent)
                }.buttonStyle(.plain)
            }
        }
    }

    private var formCard: some View {
        VStack(spacing: Space.l) {
            // Tarjeta (solo si no vino fija y hay varias).
            if card == nil && creditCards.count > 1 {
                VStack(alignment: .leading, spacing: Space.s) {
                    SectionLabel(text: "Tarjeta")
                    accountChips(creditCards, selection: $selectedCardId)
                }
            }
            // Cuenta de origen.
            VStack(alignment: .leading, spacing: Space.s) {
                SectionLabel(text: "Pagar desde")
                if sourceAccounts.isEmpty {
                    Text("No tienes otra cuenta para pagar.").font(Typo.subhead).foregroundStyle(Palette.inkTertiary)
                } else {
                    accountChips(sourceAccounts, selection: $sourceAccountId)
                }
            }
            // Intereses / adicionales.
            VStack(alignment: .leading, spacing: Space.s) {
                Toggle(isOn: $hasFees.animation(Motion.ui)) {
                    Text("Intereses o adicionales").font(Typo.callout).foregroundStyle(Palette.ink)
                }.tint(Palette.accent)
                if hasFees {
                    HStack(spacing: Space.s) {
                        Text(app.currency).font(Typo.callout).foregroundStyle(Palette.inkTertiary)
                        TextField("0", text: $feesDigits).keyboardType(.numberPad)
                            .font(Typo.amountMedium).monospacedDigit().foregroundStyle(Palette.ink)
                    }
                    .padding(Space.l)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
                    Text("Se descuenta de tu cuenta pero no reduce la deuda de la tarjeta.")
                        .font(Typo.caption).foregroundStyle(Palette.inkTertiary)
                }
            }
        }
    }

    private func accountChips(_ accounts: [Account], selection: Binding<String?>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                ForEach(accounts) { a in
                    let selected = selection.wrappedValue == a.id
                    HStack(spacing: Space.xs) {
                        Image(systemName: a.type.sfSymbol).font(.system(size: 13, weight: .semibold))
                        Text(a.name).font(Typo.callout).lineLimit(1)
                    }
                    .foregroundStyle(selected ? Palette.accent : Palette.inkSecondary)
                    .padding(.horizontal, Space.m).padding(.vertical, Space.s)
                    .background(selected ? Palette.accent.opacity(0.16) : Palette.surface, in: Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).strokeBorder(selected ? Palette.accent : Palette.stroke, lineWidth: selected ? 1.5 : 1))
                    .onTapGesture { selection.wrappedValue = a.id }
                }
            }.padding(.vertical, 2)
        }
    }

    private func save() {
        guard let card = activeCard, let source = sourceAccountId else { return }
        isSaving = true; saveError = nil
        Task {
            do {
                try await Repository().payCreditCard(
                    cardId: card.id, sourceAccountId: source, amount: amount, fees: fees,
                    date: Self.isoDate(Date()), categoryId: nil,
                    description: "Pago de tarjeta \(card.name)")
                await app.refreshAll()
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
