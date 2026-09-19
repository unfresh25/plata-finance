import SwiftUI

// Flujo nativo (headless) para conectar una cuenta bancaria vía Syncfy:
// país (buscador + banderas) → banco (organización con logo) → site si tiene
// varios (Personas/Empresas) → credenciales (formulario dinámico) → MFA si
// aplica → conectado. No usa el widget de Syncfy. El formulario se construye
// desde credentials[] del site. La api_key vive en el backend; aquí solo circula
// un token temporal.

struct ConnectBankView: View {
    @Environment(\.dismiss) private var dismiss
    var onConnected: () -> Void = {}

    @State private var step: Step = .loading
    @State private var token = ""
    @State private var countries: [BankCountry] = []
    @State private var orgs: [BankOrganization] = []
    @State private var country: BankCountry?
    @State private var org: BankOrganization?
    @State private var site: BankSite?
    @State private var credentials: [String: String] = [:]
    @State private var twofaFields: [BankField] = []
    @State private var twofaAnswers: [String: String] = [:]
    @State private var idJob = ""
    @State private var idCredential = ""
    @State private var query = ""
    @State private var errorMessage: String?

    private enum Step: Equatable {
        case loading, country, bank, site, credentials, connecting, twofa, done, failed
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
        case .bank, .site: return "Elige tu banco"
        case .credentials: return org?.name ?? "Credenciales"
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
            countryList
        case .bank:
            bankList
        case .site:
            siteList
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
                step = credentials.isEmpty ? .country : .credentials
            }
        }
    }

    // MARK: - País (buscador + banderas)

    private var countryList: some View {
        VStack(spacing: 0) {
            searchBar(placeholder: "Buscar país")
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCountries) { c in
                        Button { pick(country: c) } label: {
                            HStack(spacing: Space.m) {
                                Text(c.flag).font(.system(size: 26))
                                Text(c.name).font(Typo.callout).foregroundStyle(Palette.ink)
                                Spacer()
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
    }

    private var filteredCountries: [BankCountry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        // Colombia primero (mercado principal), luego alfabético.
        let sorted = countries.sorted {
            if $0.code == "CO" { return true }
            if $1.code == "CO" { return false }
            return $0.name < $1.name
        }
        return q.isEmpty ? sorted : sorted.filter { $0.name.lowercased().contains(q) }
    }

    // MARK: - Banco (organización con logo)

    private var bankList: some View {
        VStack(spacing: 0) {
            searchBar(placeholder: "Buscar banco")
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredOrgs) { o in
                        Button { pick(org: o) } label: {
                            HStack(spacing: Space.m) {
                                bankLogo(o)
                                Text(o.name).font(Typo.callout).foregroundStyle(Palette.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkTertiary)
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
    }

    private var filteredOrgs: [BankOrganization] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let sorted = orgs.sorted { $0.name < $1.name }
        return q.isEmpty ? sorted : sorted.filter { $0.name.lowercased().contains(q) }
    }

    @ViewBuilder
    private func bankLogo(_ o: BankOrganization) -> some View {
        let url = o.avatar.flatMap { a -> URL? in
            a.hasPrefix("http") ? URL(string: a) : URL(string: "https://sync.paybook.com\(a)")
        }
        if let url {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: "building.columns.fill")
                .foregroundStyle(Palette.accent).frame(width: 32, height: 32)
        }
    }

    // MARK: - Site (Personas/Empresas)

    private var siteList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(org?.sites ?? []) { s in
                    Button { pick(site: s) } label: {
                        HStack {
                            Text(s.name).font(Typo.callout).foregroundStyle(Palette.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.inkTertiary)
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

    private func searchBar(placeholder: String) -> some View {
        HStack(spacing: Space.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkTertiary)
            TextField(placeholder, text: $query)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .foregroundStyle(Palette.ink)
        }
        .padding(Space.m)
        .background(Palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
        .padding(.horizontal, Space.l).padding(.top, Space.s).padding(.bottom, Space.m)
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
                        set: { credentials[field.name] = $0 }))
                }
                PrimaryButton(title: "Conectar", icon: "link") { Task { await connect() } }
                    .disabled(!credentialsComplete).opacity(credentialsComplete ? 1 : 0.5)
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
                        set: { twofaAnswers[field.name] = $0 }))
                }
                PrimaryButton(title: "Enviar", icon: "checkmark") { Task { await submitTwofa() } }
                    .disabled(twofaAnswers.values.allSatisfy { $0.isEmpty })
            }
            .padding(Space.l)
        }
    }

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
            default:
                fieldBox {
                    TextField("", text: binding).textInputAutocapitalization(.never).autocorrectionDisabled()
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

    // MARK: - Resultado

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

    // MARK: - Navegación de pasos

    private func pick(country c: BankCountry) {
        country = c; query = ""
        Task { await loadOrgs() }
    }

    private func pick(org o: BankOrganization) {
        org = o; query = ""
        let s = o.sites ?? []
        if s.count == 1 { site = s[0]; credentials = [:]; step = .credentials }
        else { step = .site }
    }

    private func pick(site s: BankSite) {
        site = s; credentials = [:]; step = .credentials
    }

    // MARK: - Lógica

    private func startSession() async {
        do {
            let s = try await BankService.session()
            token = s.token
            countries = try await BankService.countries(token: token)
            step = .country
        } catch { errorMessage = error.localizedDescription; step = .failed }
    }

    private func loadOrgs() async {
        guard let c = country else { return }
        step = .loading
        do {
            orgs = try await BankService.organizations(token: token, countryId: c.id)
            step = .bank
        } catch { errorMessage = error.localizedDescription; step = .failed }
    }

    private func connect() async {
        guard let s = site else { return }
        step = .connecting
        do {
            let r = try await BankService.connect(token: token, site: s,
                                                  institution: org?.name ?? s.name, credentials: credentials)
            idJob = r.id_job; idCredential = r.id_credential
            await pollJob()
        } catch { errorMessage = error.localizedDescription; step = .failed }
    }

    private func submitTwofa() async {
        step = .connecting
        do {
            try await BankService.answerTwofa(token: token, idJob: idJob, answers: twofaAnswers)
            twofaAnswers = [:]
            await pollJob()
        } catch { errorMessage = error.localizedDescription; step = .failed }
    }

    private func pollJob() async {
        for _ in 0..<40 {
            do {
                let status = try await BankService.jobStatus(token: token, idJob: idJob)
                switch status.code {
                case 200:
                    try? await BankService.sync(token: token, idCredential: idCredential)
                    step = .done; return
                case 410:
                    twofaFields = status.twofa ?? []; step = .twofa; return
                case 401:
                    errorMessage = "Credenciales inválidas."; step = .failed; return
                default: break
                }
            } catch { errorMessage = error.localizedDescription; step = .failed; return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        errorMessage = "La conexión tardó demasiado. Inténtalo de nuevo."; step = .failed
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil && step != .failed },
                set: { if !$0 { errorMessage = nil } })
    }
}
