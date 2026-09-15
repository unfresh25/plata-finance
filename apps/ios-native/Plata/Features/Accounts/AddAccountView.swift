import SwiftUI

// Sheet para crear una cuenta nueva. Campos mínimos y claros: nombre, tipo,
// balance inicial y color. Al guardar inserta en Supabase y refresca el estado.

struct AddAccountView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: AccountType = .debit
    @State private var balanceText = ""
    @State private var colorHex = AddAccountPalette.swatches[2].hex // índigo por defecto

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var balance: Double {
        Double(balanceText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    previewCard

                    fieldGroup(label: "Nombre") {
                        TextField("Ej. Cuenta de ahorros", text: $name)
                            .font(Typo.body)
                            .foregroundStyle(Palette.ink)
                            .textInputAutocapitalization(.words)
                            .padding(Space.l)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                    .strokeBorder(Palette.stroke, lineWidth: 1)
                            )
                    }

                    fieldGroup(label: "Tipo") {
                        typePicker
                    }

                    fieldGroup(label: "Balance inicial") {
                        HStack(spacing: Space.s) {
                            Text(app.currency)
                                .font(Typo.callout)
                                .foregroundStyle(Palette.inkTertiary)
                            TextField("0", text: $balanceText)
                                .font(Typo.amountMedium)
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                                .keyboardType(.decimalPad)
                        }
                        .padding(Space.l)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                .strokeBorder(Palette.stroke, lineWidth: 1)
                        )
                    }

                    fieldGroup(label: "Color") {
                        colorPicker
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typo.subhead)
                            .foregroundStyle(Palette.negative)
                    }

                    PrimaryButton(title: isSaving ? "Guardando…" : "Guardar cuenta", icon: "checkmark") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                }
                .padding(Space.l)
            }
            // Velo tenue en vez de opaco: deja leer el material del sheet (glass).
            .background(Palette.bg.opacity(0.6).ignoresSafeArea())
            .navigationTitle("Nueva cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .tint(Palette.accent)
        .presentationDragIndicator(.visible)
        .glassSheetBackground()
    }

    // MARK: - Vista previa

    private var previewCard: some View {
        Card {
            HStack(spacing: Space.m) {
                CategoryIcon(systemName: type.sfSymbol, color: AddAccountPalette.color(for: colorHex))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name.isEmpty ? "Nueva cuenta" : name)
                        .font(Typo.headline)
                        .foregroundStyle(name.isEmpty ? Palette.inkTertiary : Palette.ink)
                    Text(type.label)
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.inkSecondary)
                }

                Spacer(minLength: Space.s)

                AmountText(amount: balance, currency: app.currency, font: Typo.amount)
            }
        }
    }

    // MARK: - Picker de tipo

    private var typePicker: some View {
        Menu {
            Picker("Tipo", selection: $type) {
                ForEach(AccountType.allCases, id: \.self) { t in
                    Label(t.label, systemImage: t.sfSymbol).tag(t)
                }
            }
        } label: {
            HStack(spacing: Space.m) {
                Image(systemName: type.sfSymbol)
                    .foregroundStyle(Palette.inkSecondary)
                Text(type.label)
                    .font(Typo.body)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(Space.l)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
        }
        .animation(Motion.ui, value: type)
    }

    // MARK: - Selector de color

    private var colorPicker: some View {
        HStack(spacing: Space.m) {
            ForEach(AddAccountPalette.swatches, id: \.hex) { swatch in
                let isSelected = swatch.hex == colorHex
                Button {
                    withAnimation(Motion.ui) { colorHex = swatch.hex }
                } label: {
                    Circle()
                        .fill(swatch.color)
                        .frame(width: 34, height: 34)
                        // Borde luminoso hairline del propio color: define sin glow.
                        .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
                        // Anillo de selección concéntrico, del propio color (no ink duro).
                        .overlay(
                            Circle()
                                .strokeBorder(swatch.color.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
                                .padding(-4)
                        )
                        .animation(Motion.ui, value: isSelected)
                }
                .pressable()
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Contenedor de campo

    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel(text: label)
            content()
        }
    }

    // MARK: - Guardar

    private func save() async {
        guard let householdId = app.household?.id,
              let ownerId = app.user?.id ?? SupabaseClient.shared.currentUserId else {
            errorMessage = "No se pudo identificar tu hogar. Intenta de nuevo."
            return
        }

        isSaving = true
        errorMessage = nil

        let payload = NewAccountInsert(
            household_id: householdId,
            owner_id: ownerId,
            name: name.trimmingCharacters(in: .whitespaces),
            type: type.rawValue,
            balance: balance,
            currency: app.currency,
            color: colorHex,
            icon: type.sfSymbol
        )

        do {
            let _: [Account] = try await SupabaseClient.shared.insert("accounts", values: payload)
            await app.refreshAll()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

// MARK: - Payload de inserción

/// Filas de `accounts` en snake_case, listo para PostgREST.
private struct NewAccountInsert: Encodable {
    let household_id: String
    let owner_id: String
    let name: String
    let type: String
    let balance: Double
    let currency: String
    let color: String
    let icon: String
}

// MARK: - Paleta del selector

/// Muestras de color para el selector, alineadas con `Palette.categoryWheel`.
/// Se guarda el hex string en la columna `color` de la cuenta.
enum AddAccountPalette {
    struct Swatch {
        let hex: String
        let color: Color
    }

    static let swatches: [Swatch] = [
        Swatch(hex: "#34D399", color: Palette.green),
        Swatch(hex: "#38BDF8", color: Palette.sky),
        Swatch(hex: "#818CF8", color: Palette.indigo),
        Swatch(hex: "#C084FC", color: Palette.purple),
        Swatch(hex: "#F43F5E", color: Palette.pink),
        Swatch(hex: "#FDE047", color: Palette.amber),
        Swatch(hex: "#FB923C", color: Palette.orange),
    ]

    static func color(for hex: String) -> Color {
        swatches.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }?.color
            ?? AccountsColor.parse(hex, fallbackFor: hex)
    }
}
