import SwiftUI

// Configuración de hogar tras autenticarse. Dos caminos en Cards grandes:
// crear un hogar nuevo, o unirse con un código de invitación. Los métodos de
// AppState (createHousehold/joinHousehold) son async, fijan errorMessage y
// avanzan la fase por sí mismos.

struct HouseholdSetupView: View {
    @Environment(AppState.self) private var app

    private enum Path: Hashable { case create, join }

    @State private var selected: Path? = nil
    @State private var householdName = ""
    @State private var inviteCode = ""
    @State private var isSubmitting = false
    @State private var showScanner = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    header

                    VStack(spacing: Space.l) {
                        HouseholdOptionCard(
                            icon: "house.fill",
                            tint: Palette.green,
                            title: "Crear un hogar nuevo",
                            subtitle: "Empieza de cero e invita a tu pareja después.",
                            isExpanded: selected == .create
                        ) {
                            expand(.create)
                        } expandedContent: {
                            HouseholdInlineForm(
                                placeholder: "Nombre del hogar",
                                icon: "textformat",
                                text: $householdName,
                                buttonTitle: "Crear hogar",
                                tint: Palette.green,
                                isLoading: isSubmitting,
                                isEnabled: canCreate && !isSubmitting,
                                autocapitalization: .words,
                                focused: $isFieldFocused,
                                action: createHousehold
                            )
                        }

                        HouseholdOptionCard(
                            icon: "person.2.fill",
                            tint: Palette.sky,
                            title: "Unirme con un código",
                            subtitle: "¿Tu pareja ya creó el hogar? Usa su código.",
                            isExpanded: selected == .join
                        ) {
                            expand(.join)
                        } expandedContent: {
                            VStack(spacing: Space.m) {
                                HouseholdInlineForm(
                                    placeholder: "Código de invitación",
                                    icon: "number",
                                    text: $inviteCode,
                                    buttonTitle: "Unirme",
                                    tint: Palette.sky,
                                    isLoading: isSubmitting,
                                    isEnabled: canJoin && !isSubmitting,
                                    autocapitalization: .characters,
                                    focused: $isFieldFocused,
                                    action: joinHousehold
                                )
                                // Escanear el QR de la pareja en vez de teclear.
                                Button {
                                    isFieldFocused = false
                                    showScanner = true
                                } label: {
                                    HStack(spacing: Space.s) {
                                        Image(systemName: "qrcode.viewfinder")
                                        Text("Escanear QR")
                                    }
                                    .font(Typo.callout)
                                    .foregroundStyle(Palette.sky)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Space.m)
                                    .background(Palette.sky.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .pressable()
                            }
                        }
                    }
                    .animation(Motion.ui, value: selected)

                    if let error = app.errorMessage {
                        HouseholdErrorBanner(message: error)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer(minLength: Space.l)

                    Button {
                        app.signOut()
                    } label: {
                        Text("Cerrar sesión")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkTertiary)
                            .frame(maxWidth: .infinity)
                    }
                    .pressable()
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.xxxl)
                .padding(.bottom, Space.xl)
                .animation(Motion.ui, value: app.errorMessage)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showScanner) {
            HouseholdQRScanSheet { scanned in
                showScanner = false
                // El QR puede traer el código directo o texto con él; toma solo
                // caracteres alfanuméricos por si viene envuelto.
                let code = scanned.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                inviteCode = code
                joinHousehold()
            }
        }
    }

    // MARK: Secciones

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            CategoryIcon(systemName: "sparkles", color: Palette.accent, size: 52)
            Text("Casi listo")
                .font(Typo.title)
                .tracking(-0.4)
                .foregroundStyle(Palette.ink)
                .padding(.top, Space.xs)
            Text("Un hogar reúne las finanzas tuyas y las de tu pareja en un mismo lugar.")
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Estado

    private var canCreate: Bool {
        !householdName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var canJoin: Bool {
        inviteCode.trimmingCharacters(in: .whitespaces).count >= 4
    }

    private func expand(_ path: Path) {
        withAnimation(Motion.ui) {
            selected = (selected == path) ? nil : path
            app.errorMessage = nil
        }
    }

    // MARK: Acciones

    private func createHousehold() {
        guard canCreate, !isSubmitting else { return }
        run { await app.createHousehold(name: householdName.trimmingCharacters(in: .whitespaces)) }
    }

    private func joinHousehold() {
        guard canJoin, !isSubmitting else { return }
        let code = inviteCode.trimmingCharacters(in: .whitespaces).uppercased()
        run { await app.joinHousehold(code: code) }
    }

    private func run(_ operation: @escaping () async -> Void) {
        isFieldFocused = false
        app.errorMessage = nil
        isSubmitting = true
        Task {
            await operation()
            isSubmitting = false
        }
    }
}

// MARK: - Card de opción (expandible)

private struct HouseholdOptionCard<Expanded: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let isExpanded: Bool
    let onTap: () -> Void
    @ViewBuilder let expandedContent: Expanded

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: Space.l) {
                    CategoryIcon(systemName: icon, color: tint, size: 48)

                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(title)
                            .font(Typo.headline)
                            .foregroundStyle(Palette.ink)
                        Text(subtitle)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: Space.s)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pressable(scale: 0.985)

            if isExpanded {
                expandedContent
                    .padding(.top, Space.l)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Space.l)
        // Card de setup con material glass sutil. Los hijos (campo) son sólidos → sin glass sobre glass.
        .liquidGlass(cornerRadius: Radius.m)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(isExpanded ? tint.opacity(0.4) : Palette.stroke.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Formulario inline (campo + botón)

private struct HouseholdInlineForm: View {
    let placeholder: String
    let icon: String
    @Binding var text: String
    let buttonTitle: String
    let tint: Color
    let isLoading: Bool
    let isEnabled: Bool
    let autocapitalization: TextInputAutocapitalization
    var focused: FocusState<Bool>.Binding
    let action: () -> Void

    var body: some View {
        VStack(spacing: Space.m) {
            HStack(spacing: Space.m) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(width: 22)

                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Palette.inkTertiary))
                    .font(Typo.body)
                    .foregroundStyle(Palette.ink)
                    .tint(tint)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused(focused)
                    .onSubmit { if isEnabled { action() } }
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.l)
            .background(Palette.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )

            Button(action: action) {
                HStack(spacing: Space.s) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Palette.bg)
                    } else {
                        Text(buttonTitle).font(Typo.headline)
                    }
                }
                .foregroundStyle(Palette.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .padding(.vertical, Space.m)
                .background(tint, in: RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
                .opacity(isEnabled ? 1 : 0.45)
            }
            .disabled(!isEnabled)
            .pressable()
            .animation(Motion.value, value: isLoading)
            .animation(Motion.value, value: isEnabled)
        }
    }
}

// MARK: - Banner de error

private struct HouseholdErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.pink)
            Text(message)
                .font(Typo.caption)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Space.m)
        .background(Palette.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                .strokeBorder(Palette.pink.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Sheet del escáner de QR

private struct HouseholdQRScanSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void

    var body: some View {
        ZStack {
            QRScannerView(onScan: onScan)
                .ignoresSafeArea()

            // Marco guía + instrucción.
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    .padding()
                }
                Spacer()
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 240, height: 240)
                Spacer()
                Text("Apunta al código QR de tu pareja")
                    .font(Typo.callout)
                    .foregroundStyle(.white)
                    .padding(.vertical, Space.m)
                    .padding(.horizontal, Space.l)
                    .background(.black.opacity(0.4), in: Capsule())
                    .padding(.bottom, Space.xxxl)
            }
        }
        .presentationBackground(.black)
    }
}

#Preview {
    HouseholdSetupView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
