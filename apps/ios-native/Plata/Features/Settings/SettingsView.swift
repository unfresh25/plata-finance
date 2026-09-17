import SwiftUI
import UIKit
import PhotosUI

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

    // Edición de perfil (nombre + foto).
    @State private var showNameEdit = false
    @State private var nameInput = ""
    @State private var showPhotosPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isSavingProfile = false
    @State private var profileError: String?

    // Regenerar código de invitación (confirmación + spinner).
    @State private var showRegenConfirm = false
    @State private var isRegenerating = false

    // Editar nombre del hogar.
    @State private var showHouseholdEdit = false
    @State private var householdNameInput = ""

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
                    avatarUrl: app.profile?.avatarUrl,
                    isSaving: isSavingProfile,
                    onEditName: {
                        nameInput = app.profile?.name ?? ""
                        showNameEdit = true
                    },
                    onChangePhoto: { showPhotosPicker = true }
                )

                SettingsHouseholdSection(
                    householdName: app.household?.name,
                    inviteCode: app.household?.inviteCode,
                    didCopy: didCopyCode,
                    isRegenerating: isRegenerating,
                    canEditName: app.household != nil,
                    onEditName: {
                        householdNameInput = app.household?.name ?? ""
                        showHouseholdEdit = true
                    },
                    onCopy: copyInviteCode,
                    onRegenerate: { showRegenConfirm = true }
                )

                SettingsPreferencesSection(
                    currencies: currencies,
                    selectedCurrency: currentCurrencyLabel,
                    onSelectCurrency: { code in
                        withAnimation(Motion.value) { app.profile?.currency = code }
                        // Persistir en la BD (antes solo cambiaba en memoria).
                        Task { await app.setCurrency(code) }
                    }
                )

                SettingsManagementSection()

                SettingsSignOutButton { showSignOutConfirm = true }

                SettingsFooter()
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.m)
        }
        .floatingTabBarInset()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.large)
        // Alert nativo (centrado) para la confirmación destructiva. En iOS 26 el
        // confirmationDialog a veces se presenta como popover con flecha en iPhone
        // (bug de SwiftUI); el alert siempre sale como el diálogo estándar de Apple.
        .alert("¿Cerrar sesión?", isPresented: $showSignOutConfirm) {
            Button("Cerrar sesión", role: .destructive) { app.signOut() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Volverás a la pantalla de inicio. Tus datos siguen a salvo.")
        }
        // Editar nombre para mostrar (alert con campo de texto).
        .alert("Editar nombre", isPresented: $showNameEdit) {
            TextField("Tu nombre", text: $nameInput)
                .textInputAutocapitalization(.words)
            Button("Guardar") { Task { await saveName() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Este es el nombre que verá tu pareja.")
        }
        // Cambiar foto de perfil.
        .photosPicker(isPresented: $showPhotosPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, newItem in
            if let newItem { Task { await saveAvatar(from: newItem) } }
        }
        .alert("No se pudo actualizar el perfil", isPresented: profileErrorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(profileError ?? "")
        }
        // Regenerar código de invitación (invalida el anterior).
        .alert("¿Regenerar código?", isPresented: $showRegenConfirm) {
            Button("Regenerar", role: .destructive) { Task { await regenerateCode() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El código actual dejará de funcionar. Tendrás que compartir el nuevo.")
        }
        // Editar nombre del hogar.
        .alert("Nombre del hogar", isPresented: $showHouseholdEdit) {
            TextField("Nombre del hogar", text: $householdNameInput)
                .textInputAutocapitalization(.words)
            Button("Guardar") { Task { await app.setHouseholdName(householdNameInput) } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Así verán tú y tu pareja este hogar.")
        }
    }

    private func regenerateCode() async {
        isRegenerating = true
        await app.regenerateInviteCode()
        isRegenerating = false
    }

    // MARK: - Guardado de perfil

    private var profileErrorBinding: Binding<Bool> {
        Binding(get: { profileError != nil }, set: { if !$0 { profileError = nil } })
    }

    private func saveName() async {
        let trimmed = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let uid = app.profile?.id else { return }
        isSavingProfile = true
        do {
            try await Repository().updateProfile(userId: uid, name: trimmed)
            app.profile?.name = trimmed
        } catch {
            profileError = error.localizedDescription
        }
        isSavingProfile = false
    }

    private func saveAvatar(from item: PhotosPickerItem) async {
        guard let uid = app.profile?.id else { return }
        isSavingProfile = true
        defer { isSavingProfile = false; photoItem = nil }
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data),
                let jpeg = image.jpegData(compressionQuality: 0.6)
            else {
                profileError = "No se pudo leer la imagen seleccionada."
                return
            }
            let url = try await Repository().uploadAvatar(userId: uid, jpeg: jpeg)
            try await Repository().updateProfile(userId: uid, avatarUrl: url)
            app.profile?.avatarUrl = url
        } catch {
            profileError = error.localizedDescription
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
    var isSaving: Bool = false
    var onEditName: () -> Void = {}
    var onChangePhoto: () -> Void = {}

    var body: some View {
        HStack(spacing: Space.l) {
            // Avatar tappable: al tocar, cambia la foto. Badge de cámara + spinner.
            Button(action: onChangePhoto) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(name: name, urlString: avatarUrl, size: 64)
                        .opacity(isSaving ? 0.5 : 1)
                    if isSaving {
                        ProgressView().tint(Palette.accent)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.onAccent)
                            .frame(width: 22, height: 22)
                            .background(Palette.accent, in: Circle())
                            .overlay(Circle().strokeBorder(Palette.bg, lineWidth: 2))
                    }
                }
            }
            .buttonStyle(.plain)
            .pressable(scale: 0.96)
            .disabled(isSaving)

            // Nombre + correo. El nombre es tappable para editarlo.
            VStack(alignment: .leading, spacing: 2) {
                Button(action: onEditName) {
                    HStack(spacing: Space.xs) {
                        Text(name?.isEmpty == false ? name! : "Sin nombre")
                            .font(Typo.title)
                            .tracking(-0.4)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
                .buttonStyle(.plain)
                .pressable(scale: 0.97)

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
    var isRegenerating: Bool = false
    var canEditName: Bool = false
    var onEditName: () -> Void = {}
    let onCopy: () -> Void
    var onRegenerate: () -> Void = {}

    var body: some View {
        PlainSection(title: "Hogar") {
            Button(action: onEditName) {
                SettingsRow(
                    icon: "house.fill",
                    tint: Palette.sky,
                    title: "Nombre del hogar"
                ) {
                    HStack(spacing: Space.xs) {
                        Text(displayHouseholdName)
                            .font(Typo.callout)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        if canEditName {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Palette.inkTertiary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!canEditName)
            .pressable(scale: 0.98)

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

            HStack(alignment: .top, spacing: Space.s) {
                Text("Comparte el código para que tu pareja se una a este hogar.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if inviteCode?.isEmpty == false {
                    Button(action: onRegenerate) {
                        HStack(spacing: Space.xs) {
                            if isRegenerating {
                                ProgressView().controlSize(.mini).tint(Palette.accent)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text("Regenerar")
                                .font(Typo.caption)
                        }
                        .foregroundStyle(Palette.accent)
                    }
                    .buttonStyle(.plain)
                    .pressable(scale: 0.95)
                    .disabled(isRegenerating)
                }
            }
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
