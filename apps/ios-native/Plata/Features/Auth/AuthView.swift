import SwiftUI

// Login + registro en una sola vista con un toggle. Estilo dark: campos sobre
// superficies elevadas, un único CTA con estado de carga. Los métodos de AppState
// (signIn/signUp) son async, fijan errorMessage y avanzan la fase por sí mismos.

// Campo con foco, compartido entre AuthView y su subcomponente de campo.
private enum AuthFieldKey: Hashable { case name, email, password }

struct AuthView: View {
    @Environment(AppState.self) private var app

    private enum Mode: Hashable { case signIn, signUp }

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @Namespace private var pillNS
    @FocusState private var focused: AuthFieldKey?

    private var isRegister: Bool { mode == .signUp }

    private var canSubmit: Bool {
        let base = email.contains("@") && password.count >= 6
        return isRegister ? (base && !name.trimmingCharacters(in: .whitespaces).isEmpty) : base
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    header

                    PillToggle(
                        options: [
                            (Mode.signIn, "Iniciar sesión", Palette.accent),
                            (Mode.signUp, "Crear cuenta", Palette.green),
                        ],
                        selection: $mode,
                        namespace: pillNS
                    )
                    .onChange(of: mode) { _, _ in app.errorMessage = nil }

                    VStack(spacing: Space.m) {
                        if isRegister {
                            AuthTextField(
                                icon: "person.fill",
                                placeholder: "Tu nombre",
                                text: $name,
                                field: .name,
                                focused: $focused,
                                onSubmit: { focused = .email }
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        AuthTextField(
                            icon: "envelope.fill",
                            placeholder: "Correo electrónico",
                            text: $email,
                            field: .email,
                            focused: $focused,
                            keyboard: .emailAddress,
                            content: .username,
                            onSubmit: { focused = .password }
                        )

                        AuthTextField(
                            icon: "lock.fill",
                            placeholder: "Contraseña",
                            text: $password,
                            field: .password,
                            focused: $focused,
                            isSecure: true,
                            content: isRegister ? .newPassword : .password,
                            onSubmit: submit
                        )
                    }
                    .animation(Motion.ui, value: isRegister)

                    if let error = app.errorMessage {
                        AuthErrorBanner(message: error)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    AuthSubmitButton(
                        title: isRegister ? "Crear cuenta" : "Entrar",
                        tint: isRegister ? Palette.green : Palette.accent,
                        isLoading: isSubmitting,
                        isEnabled: canSubmit && !isSubmitting,
                        action: submit
                    )

                    footer
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.xxxl)
                .padding(.bottom, Space.xl)
                .animation(Motion.ui, value: app.errorMessage)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: Secciones

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                Text("Plata")
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
            }
            Text(isRegister ? "Crea tu cuenta" : "Hola de nuevo")
                .font(Typo.title)
                .foregroundStyle(Palette.ink)
            Text(isRegister
                 ? "Empieza a llevar tus finanzas en pareja."
                 : "Nos alegra verte por aquí otra vez.")
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private var footer: some View {
        HStack(spacing: Space.xs) {
            Text(isRegister ? "¿Ya tienes cuenta?" : "¿Aún no tienes cuenta?")
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)
            Button(isRegister ? "Inicia sesión" : "Crea una") {
                withAnimation(Motion.ui) {
                    mode = isRegister ? .signIn : .signUp
                    app.errorMessage = nil
                }
            }
            .font(Typo.caption)
            .foregroundStyle(Palette.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.s)
    }

    // MARK: Acción

    private func submit() {
        guard canSubmit, !isSubmitting else { return }
        focused = nil
        app.errorMessage = nil
        isSubmitting = true
        let currentMode = mode
        Task {
            if currentMode == .signUp {
                await app.signUp(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    name: name.trimmingCharacters(in: .whitespaces)
                )
            } else {
                await app.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            }
            isSubmitting = false
        }
    }
}

// MARK: - Campo de texto con estilo dark

private struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let field: AuthFieldKey
    var focused: FocusState<AuthFieldKey?>.Binding
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var content: UITextContentType? = nil
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isFocused ? Palette.accent : Palette.inkTertiary)
                .frame(width: 22)

            Group {
                if isSecure {
                    SecureField("", text: $text, prompt: prompt)
                } else {
                    TextField("", text: $text, prompt: prompt)
                }
            }
            .font(Typo.body)
            .foregroundStyle(Palette.ink)
            .tint(Palette.accent)
            .keyboardType(keyboard)
            .textContentType(content)
            .textInputAutocapitalization(field == .name ? .words : .never)
            .autocorrectionDisabled()
            .submitLabel(field == .password ? .go : .next)
            .focused(focused, equals: field)
            .onSubmit(onSubmit)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.l)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(isFocused ? Palette.accent.opacity(0.6) : Palette.stroke, lineWidth: 1)
        )
        .animation(Motion.value, value: isFocused)
    }

    private var isFocused: Bool { focused.wrappedValue == field }

    private var prompt: Text {
        Text(placeholder).foregroundColor(Palette.inkTertiary)
    }
}

// MARK: - Banner de error

private struct AuthErrorBanner: View {
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

// MARK: - Botón de envío con estado de carga

private struct AuthSubmitButton: View {
    let title: String
    let tint: Color
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Palette.bg)
                } else {
                    Text(title).font(Typo.headline)
                }
            }
            .foregroundStyle(Palette.bg)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .padding(.vertical, Space.l)
            .background(tint, in: RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
        }
        .disabled(!isEnabled)
        .pressable()
        .animation(Motion.value, value: isLoading)
        .animation(Motion.value, value: isEnabled)
    }
}

#Preview {
    AuthView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
