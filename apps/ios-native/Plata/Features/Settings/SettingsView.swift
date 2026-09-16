import SwiftUI
import UIKit

// Ajustes — perfil (arriba), hogar + código de invitación, preferencias (moneda,
// tema) y cierre de sesión. Diseño PLANO: secciones con header y filas separadas
// por hairlines, sin cards. Todo lee/escribe sobre AppState; no se inventa API
// que no exista.

struct SettingsView: View {
    @Environment(AppState.self) private var app

    // Feedback transitorio al copiar el código de invitación.
    @State private var didCopyCode = false
    // Confirmación destructiva antes de cerrar sesión.
    @State private var showSignOutConfirm = false

    // Monedas soportadas (código ISO + etiqueta amable).
    private let currencies: [(code: String, label: String)] = [
        ("COP", "Peso colombiano"),
        ("USD", "Dólar estadounidense"),
        ("EUR", "Euro"),
        ("MXN", "Peso mexicano"),
    ]

    var body: some View {
        @Bindable var app = app

        ScrollView {
            VStack(spacing: Space.xxl) {
                SettingsProfileHeader(
                    name: app.profile?.name,
                    email: app.user?.email,
                    avatarUrl: app.profile?.avatarUrl
                )

                SettingsHouseholdSection(
                    householdName: app.household?.name,
                    inviteCode: app.household?.inviteCode,
                    didCopy: didCopyCode,
                    onCopy: copyInviteCode
                )

                SettingsPreferencesSection(
                    currencies: currencies,
                    selectedCurrency: currentCurrencyLabel,
                    onSelectCurrency: { code in
                        withAnimation(Motion.value) { app.profile?.currency = code }
                    }
                )

                SettingsManagementSection()

                SettingsSignOutButton { showSignOutConfirm = true }

                SettingsFooter()
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.m)
            .padding(.bottom, Space.xxxl)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "¿Cerrar sesión?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Cerrar sesión", role: .destructive) { app.signOut() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Volverás a la pantalla de inicio. Tus datos siguen a salvo.")
        }
    }

    private var currentCurrencyLabel: String {
        let code = app.currency
        return currencies.first { $0.code == code }?.label ?? code
    }

    private func copyInviteCode() {
        guard let code = app.household?.inviteCode, !code.isEmpty else { return }
        UIPasteboard.general.string = code
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(Motion.ui) { didCopyCode = true }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(Motion.value) { didCopyCode = false }
        }
    }
}

// MARK: - Perfil (encabezado plano, sin card)

private struct SettingsProfileHeader: View {
    let name: String?
    let email: String?
    var avatarUrl: String?

    var body: some View {
        HStack(spacing: Space.l) {
            AvatarView(name: name, urlString: avatarUrl, size: 64)

            VStack(alignment: .leading, spacing: 2) {
                Text(name?.isEmpty == false ? name! : "Sin nombre")
                    .font(Typo.title)
                    .tracking(-0.4)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Text(email ?? "Sin correo")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Hogar + código de invitación

private struct SettingsHouseholdSection: View {
    let householdName: String?
    let inviteCode: String?
    let didCopy: Bool
    let onCopy: () -> Void

    var body: some View {
        PlainSection(title: "Hogar") {
            SettingsRow(
                icon: "house.fill",
                tint: Palette.sky,
                title: "Nombre del hogar"
            ) {
                Text(displayHouseholdName)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }

            RowDivider(leadingInset: 40 + Space.m)

            if let code = inviteCode, !code.isEmpty {
                SettingsInviteCodeRow(code: code, didCopy: didCopy, onCopy: onCopy)
            } else {
                SettingsRow(
                    icon: "key.fill",
                    tint: Palette.amber,
                    title: "Código de invitación"
                ) {
                    Text("Aún no disponible")
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.inkTertiary)
                }
            }

            Text("Comparte el código para que tu pareja se una a este hogar.")
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Space.s)
        }
    }

    private var displayHouseholdName: String {
        (householdName?.isEmpty == false) ? householdName! : "Sin hogar"
    }
}

// MARK: - Gestión (categorías, etc.)

private struct SettingsManagementSection: View {
    var body: some View {
        PlainSection(title: "Gestión") {
            NavigationLink {
                CategoriesView()
            } label: {
                SettingsRow(
                    icon: "square.grid.2x2.fill",
                    tint: Palette.indigo,
                    title: "Gestionar categorías"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            .buttonStyle(.plain)
            .pressable()
        }
    }
}

private struct SettingsInviteCodeRow: View {
    let code: String
    let didCopy: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: Space.m) {
            CategoryIcon(systemName: "key.fill", color: Palette.indigo, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Código de invitación")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                Text(code)
                    .font(Typo.amount)
                    .monospacedDigit()
                    .tracking(2)
                    .foregroundStyle(Palette.ink)
            }

            Spacer(minLength: Space.s)

            Button(action: onCopy) {
                HStack(spacing: Space.xs) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                    Text(didCopy ? "Copiado" : "Copiar")
                        .font(Typo.caption)
                }
                .foregroundStyle(didCopy ? Palette.green : Palette.accent)
                .padding(.vertical, Space.s)
                .padding(.horizontal, Space.m)
                .background(
                    Capsule().fill((didCopy ? Palette.green : Palette.accent).opacity(0.14))
                )
                // Hairline luminoso sutil del color de acción, sin glow.
                .overlay(
                    Capsule().strokeBorder((didCopy ? Palette.green : Palette.accent).opacity(0.22), lineWidth: 0.5)
                )
                .animation(Motion.value, value: didCopy)
            }
            .pressable()
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Preferencias (moneda, tema)

private struct SettingsPreferencesSection: View {
    let currencies: [(code: String, label: String)]
    let selectedCurrency: String
    let onSelectCurrency: (String) -> Void
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        PlainSection(title: "Preferencias") {
            SettingsRow(
                icon: "dollarsign.circle.fill",
                tint: Palette.green,
                title: "Moneda"
            ) {
                Menu {
                    ForEach(currencies, id: \.code) { option in
                        Button {
                            onSelectCurrency(option.code)
                        } label: {
                            Text("\(option.label) · \(option.code)")
                        }
                    }
                } label: {
                    HStack(spacing: Space.xs) {
                        Text(selectedCurrency)
                            .font(Typo.callout)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
            }

            RowDivider(leadingInset: 40 + Space.m)

            SettingsRow(
                icon: theme.preference.sfSymbol,
                tint: Palette.purple,
                title: "Tema"
            ) {
                Menu {
                    ForEach(ThemePreference.allCases) { option in
                        Button {
                            withAnimation(Motion.ui) { theme.preference = option }
                        } label: {
                            Label(option.label, systemImage: option.sfSymbol)
                            if theme.preference == option { Image(systemName: "checkmark") }
                        }
                    }
                } label: {
                    HStack(spacing: Space.xs) {
                        Text(theme.preference.label)
                            .font(Typo.callout)
                            .foregroundStyle(Palette.inkSecondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Cerrar sesión

private struct SettingsSignOutButton: View {
    let action: () -> Void

    var body: some View {
        PrimaryButton(
            title: "Cerrar sesión",
            icon: "rectangle.portrait.and.arrow.right",
            tint: Palette.pink.opacity(0.16),
            fg: Palette.pink,
            action: action
        )
    }
}

// MARK: - Footer

private struct SettingsFooter: View {
    var body: some View {
        VStack(spacing: Space.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.accent)
            Text("Plata v1.0.0")
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)
            Text("Hecho para dos.")
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.m)
    }
}

// MARK: - Fila reutilizable de ajustes

/// Fila con ícono en círculo de color, título a la izquierda y valor/control
/// (trailing) a la derecha. Base común de las secciones de esta feature.
private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let tint: Color
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Space.m) {
            CategoryIcon(systemName: icon, color: tint, size: 40)

            Text(title)
                .font(Typo.callout)
                .foregroundStyle(Palette.ink)

            Spacer(minLength: Space.s)

            trailing
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}
