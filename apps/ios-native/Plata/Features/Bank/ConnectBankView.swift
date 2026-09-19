import SwiftUI

// Flujo nativo (headless) para conectar una cuenta bancaria vía Syncfy:
// país → banco → credenciales (formulario dinámico) → MFA si aplica → conectado.
// No usa el widget de Syncfy. El formulario se construye desde credentials[] del
// site. La api_key vive en el backend; aquí solo circula un token temporal.

struct ConnectBankView: View {
    @Environment(\.dismiss) private var dismiss
    var onConnected: () -> Void = {}

    @State private var step: Step = .loading
    @State private var token = ""
    @State private var countries: [BankCountry] = []
    @State private var sites: [BankSite] = []
    @State private var country: BankCountry?
    @State private var site: BankSite?
    @State private var credentials: [String: String] = [:]
    @State private var twofaFields: [BankField] = []
    @State private var twofaAnswers: [String: String] = [:]
    @State private var idJob = ""
    @State private var idCredential = ""
    @State private var errorMessage: String?

    // Producción: bancos reales del catálogo (Bancolombia, Davivienda, etc.).
    private let useTestSites = false

    private enum Step: Equatable {
        case loading, country, site, credentials, connecting, twofa, done, failed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.opacity(0.6).ignoresSafeArea()
                content
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .tint(Palette.accent)
        .glassSheetBackground()
        .task { await startSession() }
        .alert("No se pudo", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: { Text(errorMessage ?? "Inténtalo de nuevo.") }
    }

    private var navTitle: String {
        switch step {
        case .loading, .country: return "Elige el país"
        case .site: return "Elige tu banco"
        case .credentials: return site?.name ?? "Credenciales"
        case .connecting, .twofa: return "Conectando…"
        case .done: return "Conectado"
        case .failed: return "Conexión"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .loading, .connecting:
            VStack(spacing: Space.l) {
                ProgressView().controlSize(.large).tint(Palette.accent)
                Text(step == .connecting ? "Conectando con el banco…" : "Cargando…")
                    .font(Typo.subhead).foregroundStyle(Palette.inkSecondary)
            }
        case .country:
            pickList(countries.map { ($0.id, "\($0.name)") }) { id in
                country = countries.first { $0.id == id }
                Task { await loadSites() }
            }
        case .site:
            pickList(sites.map { ($0.id, $0.name) }) { id in
                site = sites.first { $0.id == id }
                credentials = [:]
                step = .credentials
            }
        case .credentials:
            credentialsForm
        case .twofa:
            twofaForm
        case .done:
            resultState(icon: "checkmark.circle.fill", tint: Palette.positive,
                        title: "¡Cuenta conectada!",
                        subtitle: "Ya estamos trayendo tus movimientos.") {
                onConnected(); dismiss()
            }
        case .failed:
            resultState(icon: "xmark.circle.fill", tint: Palette.negative,
                        title: "No se pudo conectar",
                        subtitle: errorMessage ?? "Revisa tus datos e inténtalo de nuevo.") {
                step = .credentials
            }
        }
    }

    // MARK: - Listas (país / banco)

    private func pickList(_ items: [(String, String)], onSelect: @escaping (String) -> Void) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(items, id: \.0) { item in
                    Button { onSelect(item.0) } label: {
                        HStack {
                            Text(item.1).font(Typo.callout).foregroundStyle(Palette.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.inkTertiary)
                        }
                        .padding(.vertical, Space.m)
                        .contentShape(Rectangle())
                    }
                    .pressable()
                    RowDivider()
                }
            }
            .padding(.horizontal, Space.l)
        }
    }

    // MARK: - Formulario dinámico de credenciales

    private var credentialsForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Introduce tus datos de acceso. Nunca guardamos tus credenciales; se envían cifradas al banco.")
                    .font(Typo.caption).foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(site?.credentials ?? [], id: \.name) { field in
                    dynamicField(field, binding: Binding(
                        get: { credentials[field.name] ?? "" },
                        set: { credentials[field.name] = $0 }
                    ))
                }

                PrimaryButton(title: "Conectar", icon: "link") {
                    Task { await connect() }
                }
                .disabled(!credentialsComplete)
                .opacity(credentialsComplete ? 1 : 0.5)
            }
            .padding(Space.l)
        }
    }

    private var twofaForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Tu banco pide un paso de verificación.")
                    .font(Typo.subhead).foregroundStyle(Palette.inkSecondary)
                ForEach(twofaFields, id: \.name) { field in
                    dynamicField(field, binding: Binding(
                        get: { twofaAnswers[field.name] ?? "" },
                        set: { twofaAnswers[field.name] = $0 }
                    ))
                }
                PrimaryButton(title: "Enviar", icon: "checkmark") {
                    Task { await submitTwofa() }
                }
                .disabled(twofaAnswers.values.allSatisfy { $0.isEmpty })
            }
            .padding(Space.l)
        }
    }

    /// Renderiza un campo según su tipo (text / password / select).
    @ViewBuilder
    private func dynamicField(_ field: BankField, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel(text: field.label ?? field.name)
            switch field.type {
            case "password":
                fieldBox { SecureField("", text: binding).textContentType(.password) }
            case "select":
                Menu {
                    ForEach(field.options ?? [], id: \.value) { opt in
                        Button(opt.label) { binding.wrappedValue = opt.value }
                    }
                } label: {
                    HStack {
                        Text(selectedLabel(field, binding.wrappedValue))
                            .font(Typo.body)
                            .foregroundStyle(binding.wrappedValue.isEmpty ? Palette.inkTertiary : Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkTertiary)
                    }
                    .padding(Space.l)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
                }
            default: // text y otros
                fieldBox {
                    TextField("", text: binding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
        }
    }

    private func fieldBox<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .font(Typo.body).foregroundStyle(Palette.ink)
            .padding(Space.l)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
    }

    private func selectedLabel(_ field: BankField, _ value: String) -> String {
        field.options?.first { $0.value == value }?.label ?? "Seleccionar"
    }

    private var credentialsComplete: Bool {
        for f in site?.credentials ?? [] where (f.required ?? true) {
            if (credentials[f.name] ?? "").isEmpty { return false }
        }
        return true
    }

    // MARK: - Estado de resultado

    private func resultState(icon: String, tint: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: Space.l) {
            Image(systemName: icon).font(.system(size: 56)).foregroundStyle(tint)
            Text(title).font(Typo.title).foregroundStyle(Palette.ink)
            Text(subtitle).font(Typo.subhead).foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, Space.xl)
            PrimaryButton(title: step == .done ? "Listo" : "Reintentar") { action() }
                .frame(maxWidth: 240)
        }
        .padding(Space.xl)
    }

    // MARK: - Lógica

    private func startSession() async {
        do {
            let s = try await BankService.session()
            token = s.token
            countries = try await BankService.countries(token: token)
            step = .country
        } catch {
            errorMessage = error.localizedDescription; step = .failed
        }
    }

    private func loadSites() async {
        guard let c = country else { return }
        step = .loading
        do {
            sites = try await BankService.sites(token: token, countryId: c.id, isTest: useTestSites)
            step = .site
        } catch {
            errorMessage = error.localizedDescription; step = .failed
        }
    }

    private func connect() async {
        guard let s = site else { return }
        step = .connecting
        do {
            let r = try await BankService.connect(token: token, site: s, credentials: credentials)
            idJob = r.id_job
            idCredential = r.id_credential
            await pollJob()
        } catch {
            errorMessage = error.localizedDescription; step = .failed
        }
    }

    private func submitTwofa() async {
        step = .connecting
        do {
            try await BankService.answerTwofa(token: token, idJob: idJob, answers: twofaAnswers)
            twofaAnswers = [:]
            await pollJob()
        } catch {
            errorMessage = error.localizedDescription; step = .failed
        }
    }

    /// Poll suave del job hasta éxito (200), MFA (410) o error (401/otro).
    private func pollJob() async {
        for _ in 0..<40 {   // ~40 intentos * 2s = 80s máx
            do {
                let status = try await BankService.jobStatus(token: token, idJob: idJob)
                switch status.code {
                case 200:
                    // Conectado: traer y persistir cuentas + movimientos.
                    try? await BankService.sync(token: token, idCredential: idCredential)
                    step = .done; return
                case 410:
                    twofaFields = status.twofa ?? []
                    step = .twofa; return
                case 401:
                    errorMessage = "Credenciales inválidas."; step = .failed; return
                default:
                    break   // 100/101/102 en proceso → seguir
                }
            } catch {
                errorMessage = error.localizedDescription; step = .failed; return
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        errorMessage = "La conexión tardó demasiado. Inténtalo de nuevo."; step = .failed
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil && step != .failed },
                set: { if !$0 { errorMessage = nil } })
    }
}
