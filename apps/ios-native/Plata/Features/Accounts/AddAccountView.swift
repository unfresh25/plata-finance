import SwiftUI

// Sheet para crear una cuenta nueva. Campos mínimos y claros: nombre, tipo,
// balance inicial y color. Al guardar inserta en Supabase y refresca el estado.

struct AddAccountView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    /// Si viene una cuenta, la pantalla opera en MODO EDICIÓN: precarga el
    /// formulario y guarda con UPDATE (PATCH de la fila; el balance va directo,
    /// sin RPC). Si es nil, es alta normal. Un mismo view para las dos rutas.
    var editing: Account? = nil
    /// Garantiza que la precarga del modo edición ocurra una sola vez.
    @State private var didSeedEdit = false

    @State private var name = ""
    @State private var type: AccountType = .debit
    @State private var balanceText = ""
    @State private var creditLimitText = ""
    @State private var colorHex = AddAccountPalette.swatches[2].hex // índigo por defecto

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isCredit: Bool { type == .credit }

    private var balance: Double {
        Double(balanceText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var creditLimit: Double? {
        guard isCredit else { return nil }
        let v = Double(creditLimitText.replacingOccurrences(of: ",", with: ".")) ?? 0
        return v > 0 ? v : nil
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

                    // En una tarjeta de crédito el "balance" es la deuda usada.
                    fieldGroup(label: isCredit ? "Deuda actual" : "Balance inicial") {
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

                    if isCredit {
                        fieldGroup(label: "Cupo total") {
                            HStack(spacing: Space.s) {
                                Text(app.currency)
                                    .font(Typo.callout)
                                    .foregroundStyle(Palette.inkTertiary)
                                TextField("0", text: $creditLimitText)
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
                    }

                    fieldGroup(label: "Color") {
                        colorPicker
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typo.subhead)
                            .foregroundStyle(Palette.negative)
                    }

                    PrimaryButton(
                        title: isSaving ? "Guardando…" : (editing == nil ? "Guardar cuenta" : "Guardar cambios"),
                        icon: "checkmark"
                    ) {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                }
                .padding(Space.l)
            }
            // Velo tenue en vez de opaco: deja leer el material del sheet (glass).
            .background(Palette.bg.opacity(0.6).ignoresSafeArea())
            .navigationTitle(editing == nil ? "Nueva cuenta" : "Editar cuenta")
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
        .onAppear(perform: seedEdit)
    }

    // MARK: - Precarga (modo edición)

    /// Vuelca los valores de la cuenta en el formulario, una sola vez. El balance
    /// se muestra como texto editable (mismo formato que el TextField de alta).
    private func seedEdit() {
        guard let e = editing, !didSeedEdit else { return }
        didSeedEdit = true
        name = e.name
        type = e.type
        balanceText = Self.balanceString(e.balance)
        if let limit = e.creditLimit { creditLimitText = Self.balanceString(limit) }
        colorHex = e.color
    }

    /// Formatea el balance para el campo de texto: entero si no tiene decimales
    /// (COP típico), con punto decimal en caso contrario.
    private static func balanceString(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(value)
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
        // 12 muestras no caben en el ancho de la pantalla: van en un scroll
        // horizontal. Sin esto, el HStack forzaba el ancho de TODO el formulario
        // más allá de la pantalla y corría los inputs fuera del margen.
        ScrollView(.horizontal, showsIndicators: false) {
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
            }
            // Aire para que el anillo de selección (padding -4) no se recorte.
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
        // El scroll no debe dictar el ancho del formulario.
        .frame(maxWidth: .infinity, alignment: .leading)
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
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // MODO EDICIÓN: PATCH de la fila. El balance es columna directa (va en el
        // patch, sin apply_account_delta). No se tocan id/household_id/owner_id.
        if let e = editing {
            isSaving = true
            errorMessage = nil

            let patch = AccountPatch(
                name: trimmedName,
                type: type.rawValue,
                balance: balance,
                color: colorHex,
                icon: type.sfSymbol,
                credit_limit: creditLimit
            )

            do {
                try await SupabaseClient.shared.update("accounts", values: patch, match: ["id": e.id])
                await app.refreshAll()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
            return
        }

        // MODO ALTA: INSERT (sin cambios respecto al comportamiento original).
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
            name: trimmedName,
            type: type.rawValue,
            balance: balance,
            currency: app.currency,
            color: colorHex,
            icon: type.sfSymbol,
            credit_limit: creditLimit
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
    let credit_limit: Double?
}

/// PATCH de edición: solo columnas editables desde el formulario. El balance va
/// directo (columna de la tabla), sin apply_account_delta. No incluye
/// id/household_id/owner_id/currency (no editables aquí).
private struct AccountPatch: Encodable {
    let name: String
    let type: String
    let balance: Double
    let color: String
    let icon: String
    let credit_limit: Double?
}

// MARK: - Paleta del selector

/// Muestras de color del selector de cuentas: la paleta ÚNICA de personalización
/// (CustomPalette, 12 colores). Se guarda el hex string en la columna `color`.
enum AddAccountPalette {
    typealias Swatch = CustomPalette.Swatch
    static let swatches: [Swatch] = CustomPalette.swatches

    static func color(for hex: String) -> Color {
        swatches.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }?.color
            ?? AccountsColor.parse(hex, fallbackFor: hex)
    }
}
