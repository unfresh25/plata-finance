import SwiftUI
import PhotosUI
import UIKit

// Pantalla insignia: registrar un movimiento. Monto GIGANTE con teclado
// numérico propio (más elegante y controlado que el del sistema), PillToggle de
// tipo arriba, y tarjetas selectoras compactas para categoría, cuenta, fecha y
// descripción. Guarda vía Repository().addTransaction y refresca AppState.

struct AddTransactionView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @Namespace private var pillNS

    /// Si viene un movimiento, la pantalla opera en MODO EDICIÓN: precarga el
    /// formulario y guarda con updateTransaction (ajustando saldos). Si es nil,
    /// es alta normal. Un mismo view para las dos rutas evita duplicar la UI.
    var editing: Transaction? = nil
    /// Campos interpretados por voz (dictado desde el FAB) para precargar el alta.
    var voicePrefill: ParsedTransaction? = nil
    /// Garantiza que la precarga del modo edición ocurra una sola vez.
    @State private var didSeedEdit = false
    /// Garantiza que la precarga por voz ocurra una sola vez.
    @State private var didSeedVoice = false

    // Estado del formulario
    @State private var type: TransactionType = .expense
    @State private var amountDigits = ""          // solo dígitos (centavos implícitos = 0)
    @State private var categoryId: String?
    @State private var accountId: String?
    @State private var date = Date()
    @State private var note = ""

    // Presentación
    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var showDatePicker = false
    @State private var isSaving = false
    @State private var saveError: String?

    // Escaneo de recibo (OCR)
    @State private var showScanSource = false
    @State private var showPhotosPicker = false
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var scanError: String?

    // Dictado por voz

    var body: some View {
        NavigationStack {
            ZStack {
                // Velo tenue en vez de opaco: deja leer el material del sheet (glass).
                Palette.bg.opacity(0.6).ignoresSafeArea()

                if app.accounts.isEmpty {
                    AddTxNoAccounts { dismiss() }
                } else {
                    content
                }
            }
            .navigationTitle(editing == nil ? "Nuevo movimiento" : "Editar movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .tint(Palette.accent)
        .presentationDragIndicator(.visible)
        .glassSheetBackground()
        .onAppear(perform: seedDefaults)
        .onChange(of: type) { _, _ in reconcileCategoryForType() }
    }

    // MARK: - Contenido principal

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Space.xl) {
                    PillToggle(options: typeOptions, selection: $type, namespace: pillNS)
                        .padding(.top, Space.s)

                    amountDisplay
                        .padding(.vertical, Space.m)

                    scanReceiptButton

                    selectors
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.l)
            }
            .scrollDismissesKeyboard(.interactively)

            keypad

            PrimaryButton(
                title: isSaving ? "Guardando…" : (editing == nil ? "Guardar" : "Guardar cambios"),
                icon: isSaving ? nil : "checkmark",
                tint: canSave ? typeTint : Palette.surfaceElevated,
                fg: canSave ? Palette.bg : Palette.inkTertiary
            ) {
                save()
            }
            .disabled(!canSave || isSaving)
            .padding(.horizontal, Space.l)
            .padding(.top, Space.m)
            .padding(.bottom, Space.s)
        }
        .alert("No se pudo guardar", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(saveError ?? "Inténtalo de nuevo.")
        }
        // Menú de opciones (cámara/galería): action sheet legítimo. Se fuerza la
        // adaptación a sheet para que en iOS 26 no salga como popover con flecha.
        .confirmationDialog("Escanear recibo", isPresented: $showScanSource, titleVisibility: .visible) {
            if AddTxCameraPicker.isAvailable {
                Button("Tomar foto") { showCamera = true }
            }
            Button("Elegir de la galería") { showPhotosPicker = true }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Toma una foto o elige una imagen del recibo para autocompletar el movimiento.")
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $photoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .fullScreenCover(isPresented: $showCamera) {
            AddTxCameraPicker { image in
                showCamera = false
                if let data = image?.jpegData(compressionQuality: 0.7) {
                    scanReceipt(imageData: data)
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            loadAndScan(from: newItem)
        }
        .alert("No se pudo escanear", isPresented: scanErrorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(scanError ?? "Inténtalo de nuevo.")
        }
    }

    // MARK: - Monto gigante

    private var amountDisplay: some View {
        VStack(spacing: Space.xs) {
            Text(type.label.uppercased())
                .font(Typo.overline)
                .tracking(1.2)
                .foregroundStyle(typeTint)

            Text(formattedAmount)
                .font(Typo.amountHero(amountFontSize))
                .monospacedDigit()
                .tracking(-0.5) // tracking negativo sutil en cifra display grande
                .foregroundStyle(amountValue > 0 ? Palette.ink : Palette.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText(value: amountValue))
                .animation(Motion.value, value: amountValue)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Escanear recibo

    /// Acción bajo el monto: escanear un recibo (OCR en el backend) para
    /// autocompletar el formulario. El dictado por voz vive en el FAB flotante.
    /// Botón plano (sin fondo), solo ícono + texto en el color de acento.
    private var scanReceiptButton: some View {
        Button {
            showScanSource = true
        } label: {
            HStack(spacing: Space.s) {
                if isScanning {
                    ProgressView().controlSize(.small).tint(Palette.accent)
                } else {
                    Image(systemName: "viewfinder").font(.system(size: 15, weight: .semibold))
                }
                Text(isScanning ? "Escaneando…" : "Escanear recibo")
                    .font(Typo.callout.weight(.medium))
            }
            .foregroundStyle(isScanning ? Palette.inkSecondary : Palette.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.s)
            .contentShape(Rectangle())
        }
        .pressable()
        .disabled(isScanning)
        .animation(Motion.ui, value: isScanning)
    }

    // MARK: - Selectores (filas planas con separador, sin cards)

    private var selectors: some View {
        VStack(spacing: 0) {
            // Categoría
            Button {
                showCategoryPicker = true
            } label: {
                SelectorRow(
                    leading: {
                        if let cat = selectedCategory {
                            CategoryIcon(
                                systemName: TransactionVisual.symbol(for: cat, fallbackType: type),
                                color: TransactionVisual.color(for: cat),
                                size: 36
                            )
                        } else {
                            SelectorPlaceholderIcon(symbol: "square.grid.2x2", tint: typeTint)
                        }
                    },
                    label: "Categoría",
                    value: selectedCategory?.name ?? "Seleccionar"
                )
            }
            .pressable()
            .disabled(categoriesForType.isEmpty)

            RowDivider(leadingInset: 36 + Space.m)

            // Cuenta
            Button {
                showAccountPicker = true
            } label: {
                SelectorRow(
                    leading: {
                        SelectorPlaceholderIcon(
                            symbol: selectedAccount?.type.sfSymbol ?? "creditcard",
                            tint: Palette.sky
                        )
                    },
                    label: "Cuenta",
                    value: selectedAccount?.name ?? "Seleccionar"
                )
            }
            .pressable()

            RowDivider(leadingInset: 36 + Space.m)

            // Fecha — la fila abre un DatePicker gráfico en un sheet (no un widget
            // suelto que desentona). La fila muestra la fecha elegida.
            Button {
                showDatePicker = true
            } label: {
                SelectorRow(
                    leading: {
                        SelectorPlaceholderIcon(symbol: "calendar", tint: Palette.purple)
                    },
                    label: "Fecha",
                    value: Self.displayDate(date)
                )
            }
            .pressable()

            RowDivider(leadingInset: 36 + Space.m)

            // Descripción
            HStack(spacing: Space.m) {
                SelectorPlaceholderIcon(symbol: "text.alignleft", tint: Palette.orange)
                TextField(
                    "",
                    text: $note,
                    prompt: Text("Descripción (opcional)").foregroundColor(Palette.inkTertiary)
                )
                .font(Typo.callout)
                .foregroundStyle(Palette.ink)
                .submitLabel(.done)
            }
            .padding(.vertical, Space.m)
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(
                categories: categoriesForType,
                selection: $categoryId,
                type: type
            )
            .presentationDetents([.medium, .large])
            .glassSheetBackground()
        }
        .sheet(isPresented: $showAccountPicker) {
            AccountPickerSheet(accounts: app.accounts, selection: $accountId)
                .presentationDetents([.medium])
                .glassSheetBackground()
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $date)
                .presentationDetents([.height(460)])
                .glassSheetBackground()
        }
    }

    // MARK: - Teclado numérico propio

    private var keypad: some View {
        VStack(spacing: Space.s) {
            ForEach(keypadRows, id: \.self) { row in
                HStack(spacing: Space.s) {
                    ForEach(row, id: \.self) { key in
                        KeypadButton(key: key) { tap(key) }
                    }
                }
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
    }

    private let keypadRows: [[KeypadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.clear, .digit("0"), .delete],
    ]

    private func tap(_ key: KeypadKey) {
        switch key {
        case .digit(let d):
            guard amountDigits.count < 12 else { return }
            if amountDigits.isEmpty && d == "0" { return } // evita ceros a la izquierda
            amountDigits.append(d)
        case .delete:
            if !amountDigits.isEmpty { amountDigits.removeLast() }
        case .clear:
            amountDigits = ""
        }
    }

    // MARK: - Guardar

    private func save() {
        guard canSave, let accountId, let hh = app.household?.id, let uid = app.profile?.id else { return }
        isSaving = true
        saveError = nil

        let payload = NewTransaction(
            accountId: accountId,
            amount: amountValue,
            type: type,
            categoryId: type == .transfer ? nil : categoryId,
            description: note.isEmpty ? nil : note,
            date: Self.isoDate(date)
        )

        Task {
            do {
                if let tx = editing {
                    try await Repository().updateTransaction(id: tx.id, original: tx, payload: payload)
                } else {
                    try await Repository().addTransaction(payload, householdId: hh, userId: uid)
                }
                await app.refreshAll()
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }

    // MARK: - Escaneo (OCR)

    /// Carga los bytes del ítem de la galería y dispara el OCR. Re-encodea a
    /// JPEG para garantizar el mime_type que espera el backend.
    private func loadAndScan(from item: PhotosPickerItem) {
        isScanning = true
        scanError = nil
        Task {
            do {
                guard
                    let data = try await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data),
                    let jpeg = image.jpegData(compressionQuality: 0.7)
                else {
                    isScanning = false
                    scanError = "No se pudo leer la imagen seleccionada."
                    photoItem = nil
                    return
                }
                photoItem = nil
                await performScan(jpeg: jpeg)
            } catch {
                isScanning = false
                scanError = error.localizedDescription
                photoItem = nil
            }
        }
    }

    /// Entrada desde la cámara: ya tenemos los bytes JPEG.
    private func scanReceipt(imageData: Data) {
        isScanning = true
        scanError = nil
        Task { await performScan(jpeg: imageData) }
    }

    /// El OCR corre en el backend (la clave de Gemini vive server-side). Se manda
    /// el JWT del usuario para autenticar y se rellena el formulario con la
    /// respuesta {amount, description, date}. Un recibo se asume gasto.
    private func performScan(jpeg: Data) async {
        do {
            let base64 = jpeg.base64EncodedString()
            let endpoint = SupabaseConfig.apiURL.appendingPathComponent("ocr/receipt")

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(
                "Bearer \(SupabaseClient.shared.accessToken ?? "")",
                forHTTPHeaderField: "Authorization"
            )
            let body: [String: String] = ["image_base64": base64, "mime_type": "image/jpeg"]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let detail = (try? JSONDecoder().decode(OCRErrorResponse.self, from: data))?.detail
                throw SupabaseError(message: detail ?? "No se pudo procesar la imagen.")
            }

            let parsed = try JSONDecoder().decode(OCRReceiptResponse.self, from: data)
            applyScan(parsed)
            isScanning = false
        } catch {
            isScanning = false
            scanError = error.localizedDescription
        }
    }

    /// Rellena los campos con lo detectado. El monto se normaliza a dígitos
    /// enteros para el teclado propio (sin decimales, como COP).
    private func applyScan(_ result: OCRReceiptResponse) {
        type = .expense // un recibo se asume gasto
        reconcileCategoryForType()

        if let amount = result.amount, amount > 0 {
            let whole = Int(amount.rounded())
            amountDigits = String(min(whole, 999_999_999_999)) // respeta el tope de 12 dígitos
        }
        if let description = result.description, !description.isEmpty {
            note = description
        }
        if let dateString = result.date, let scanned = Self.parseOCRDate(dateString) {
            date = min(scanned, Date()) // el DatePicker no permite futuro
        }
    }

    /// Rellena el formulario con lo interpretado del dictado por voz. Respeta el
    /// tipo (para reconciliar categoría) y solo aplica ids válidos (el backend ya
    /// los validó contra las categorías/cuentas del hogar). El usuario confirma.
    private func applyParsed(_ result: ParsedTransaction) {
        if let t = result.type, let parsedType = TransactionType(rawValue: t) {
            type = parsedType
        }
        reconcileCategoryForType()

        if let amount = result.amount, amount > 0 {
            let whole = Int(amount.rounded())
            amountDigits = String(min(whole, 999_999_999_999))
        }
        if let description = result.description, !description.isEmpty {
            note = description
        }
        if type != .transfer, let cat = result.categoryId,
           app.category(for: cat)?.type == (type == .income ? .income : .expense) {
            categoryId = cat
        }
        if let acc = result.accountId, app.accounts.contains(where: { $0.id == acc }) {
            accountId = acc
        }
        if let dateString = result.date, let parsed = Self.parseOCRDate(dateString) {
            date = min(parsed, Date())
        }
    }

    private var scanErrorBinding: Binding<Bool> {
        Binding(get: { scanError != nil }, set: { if !$0 { scanError = nil } })
    }

    private static func parseOCRDate(_ string: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: string) { return d }
        // Respaldo: fecha ISO 8601 completa (ej. "2026-01-15T00:00:00Z").
        let iso = ISO8601DateFormatter()
        return iso.date(from: string)
    }

    // MARK: - Derivados

    private var typeOptions: [(value: TransactionType, label: String, tint: Color)] {
        [
            (.expense, "Gasto", Palette.pink),
            (.income, "Ingreso", Palette.green),
            (.transfer, "Transferencia", Palette.sky),
        ]
    }

    private var typeTint: Color {
        switch type {
        case .expense: return Palette.pink
        case .income: return Palette.green
        case .transfer: return Palette.sky
        }
    }

    /// Monto en unidades de moneda. Los dígitos son enteros (sin centavos), como
    /// es común en COP; el teclado escribe pesos completos.
    private var amountValue: Double {
        Double(amountDigits) ?? 0
    }

    private var formattedAmount: String {
        CurrencyFormatter.string(amountValue, currency: app.currency)
    }

    private var amountFontSize: CGFloat {
        switch formattedAmount.count {
        case ...9: return 56
        case 10...12: return 46
        case 13...15: return 38
        default: return 30
        }
    }

    private var categoriesForType: [Category] {
        let want: CategoryType = type == .income ? .income : .expense
        return app.categories.filter { $0.type == want }
    }

    private var selectedCategory: Category? {
        app.category(for: categoryId)
    }

    private var selectedAccount: Account? {
        app.accounts.first { $0.id == accountId }
    }

    private var canSave: Bool {
        amountValue > 0 && accountId != nil
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    // MARK: - Efectos

    private func seedDefaults() {
        // Modo edición: volcar los valores del movimiento en el formulario (una vez).
        if let tx = editing, !didSeedEdit {
            didSeedEdit = true
            type = tx.type
            amountDigits = String(Int(tx.amount.rounded()))
            accountId = tx.accountId
            categoryId = tx.categoryId
            note = tx.description ?? ""
            date = Self.parseISO(tx.date) ?? date
            return   // no pisar con defaults de alta
        }
        if accountId == nil { accountId = app.accounts.first?.id }
        reconcileCategoryForType()

        // Precarga por voz (dictado desde el FAB): aplica lo interpretado una vez,
        // después de fijar los defaults para no pisarlos.
        if let prefill = voicePrefill, !didSeedVoice {
            didSeedVoice = true
            applyParsed(prefill)
        }
    }

    /// La categoría seleccionada debe coincidir con el tipo actual. Transfer no
    /// usa categoría.
    private func reconcileCategoryForType() {
        guard type != .transfer else { categoryId = nil; return }
        if let current = selectedCategory, current.type == (type == .income ? .income : .expense) {
            return
        }
        categoryId = categoriesForType.first?.id
    }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Parsea la fecha almacenada (yyyy-MM-dd, o ISO completa) a Date local.
    private static func parseISO(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: String(s.prefix(10))) { return d }
        return ISO8601DateFormatter().date(from: s)
    }

    /// Fecha amable para la fila: "Hoy", "Ayer" o "d MMM yyyy" en español.
    private static func displayDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Hoy" }
        if cal.isDateInYesterday(date) { return "Ayer" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return f.string(from: date)
    }
}

// MARK: - Teclado: modelo y botón

enum KeypadKey: Hashable {
    case digit(String)
    case delete
    case clear
}

private struct KeypadButton: View {
    let key: KeypadKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            content
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Rectangle())
        }
        .pressable(scale: 0.94)
    }

    @ViewBuilder private var content: some View {
        switch key {
        case .digit(let d): Text(d).monospacedDigit()
        case .delete: Image(systemName: "delete.left")
        case .clear: Image(systemName: "xmark")
        }
    }

    private var foreground: Color {
        switch key {
        case .digit: return Palette.ink
        case .delete: return Palette.inkSecondary
        case .clear: return Palette.inkTertiary
        }
    }
}

// MARK: - Fila selectora (plana, sin card) + ícono placeholder

private struct SelectorRow<Leading: View>: View {
    @ViewBuilder var leading: () -> Leading
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Space.m) {
            leading()
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                Text(value)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: Space.s)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

private struct SelectorPlaceholderIcon: View {
    let symbol: String
    var tint: Color = Palette.accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
    }
}

// MARK: - Picker de categoría

private struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    @Binding var selection: String?
    let type: TransactionType

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: Space.m)]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.opacity(0.6).ignoresSafeArea()
                if categories.isEmpty {
                    VStack(spacing: Space.s) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 30))
                            .foregroundStyle(Palette.inkTertiary)
                        Text("No hay categorías de este tipo")
                            .font(Typo.callout)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: Space.m) {
                            ForEach(categories) { cat in
                                Button {
                                    selection = cat.id
                                    dismiss()
                                } label: {
                                    categoryCell(cat)
                                }
                                .pressable()
                            }
                        }
                        .padding(Space.l)
                    }
                }
            }
            .navigationTitle("Categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }.foregroundStyle(Palette.accent)
                }
            }
        }
        .tint(Palette.accent)
    }

    private func categoryCell(_ cat: Category) -> some View {
        let isSelected = selection == cat.id
        let color = TransactionVisual.color(for: cat)
        return VStack(spacing: Space.s) {
            CategoryIcon(
                systemName: TransactionVisual.symbol(for: cat, fallbackType: type),
                color: color,
                size: 48
            )
            Text(cat.name)
                .font(Typo.caption)
                .foregroundStyle(isSelected ? Palette.ink : Palette.inkSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.m)
        .background(
            Palette.surface,
            in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(isSelected ? color : Palette.stroke, lineWidth: isSelected ? 1.5 : 1)
        )
    }
}

// MARK: - Picker de cuenta

private struct AccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let accounts: [Account]
    @Binding var selection: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.opacity(0.6).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        let last = accounts.last?.id
                        ForEach(accounts) { account in
                            Button {
                                selection = account.id
                                dismiss()
                            } label: {
                                accountRow(account)
                            }
                            .buttonStyle(.plain)
                            .pressable()
                            if account.id != last {
                                RowDivider(leadingInset: 40 + Space.m)
                            }
                        }
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.vertical, Space.s)
                }
            }
            .navigationTitle("Cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }.foregroundStyle(Palette.accent)
                }
            }
        }
        .tint(Palette.accent)
    }

    private func accountRow(_ account: Account) -> some View {
        let isSelected = selection == account.id
        let tint = Color(hexString: account.color) ?? Palette.sky
        return HStack(spacing: Space.m) {
            Image(systemName: account.type.sfSymbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(account.type.label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer(minLength: Space.s)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Sheet de fecha (DatePicker gráfico, integrado — no un widget suelto)

private struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var date: Date

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 0) {
                    DatePicker(
                        "",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .tint(Palette.accent)
                    .padding(.horizontal, Space.l)
                    Spacer(minLength: 0)
                }
                .padding(.top, Space.m)
            }
            .navigationTitle("Fecha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                        .font(Typo.headline)
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .tint(Palette.accent)
    }
}

// MARK: - Estado sin cuentas

private struct AddTxNoAccounts: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Space.l) {
            Image(systemName: "creditcard")
                .font(.system(size: 36))
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 84, height: 84)

            VStack(spacing: Space.xs) {
                Text("Primero crea una cuenta")
                    .font(Typo.title)
                    .foregroundStyle(Palette.ink)
                Text("Necesitas al menos una cuenta (débito, efectivo, ahorros…) para registrar movimientos.")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xl)
            }

            SecondaryButton(title: "Entendido", action: onDismiss)
                .frame(maxWidth: 220)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Respuestas del OCR

/// Respuesta esperada del endpoint /ocr/receipt: {amount, description, date}.
private struct OCRReceiptResponse: Decodable {
    let amount: Double?
    let description: String?
    let date: String?
}

private struct OCRErrorResponse: Decodable {
    let detail: String?
}

// MARK: - Cámara (UIImagePickerController envuelto)

/// Envoltorio mínimo de UIImagePickerController para captura con cámara. La
/// galería usa PhotosPicker (nativo, sin permisos complejos); la cámara sí
/// requiere UIKit. Devuelve la imagen elegida (o nil si se cancela).
private struct AddTxCameraPicker: UIViewControllerRepresentable {
    var onFinish: (UIImage?) -> Void

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            onFinish(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
