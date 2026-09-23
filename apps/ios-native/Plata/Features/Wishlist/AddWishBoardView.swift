import SwiftUI
import PhotosUI

// Crear un tablero de deseos: nombre + categoría (usa las categorías creadas del
// hogar, su ícono y color) + portada opcional (URL o subir foto).

struct AddWishBoardView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    // Guardamos en `emoji` el slug del ícono de la categoría elegida (Hugeicon)
    // o, sin categorías, un emoji suelto de respaldo.
    @State private var emoji = "sparkles"
    @State private var coverMode: CoverMode = .none
    @State private var coverUrlText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var uploadedCover: String?
    @State private var uploading = false
    @State private var saving = false
    @State private var error: String?

    private enum CoverMode: String, CaseIterable { case none, url, upload
        var label: String { switch self { case .none: "Sin portada"; case .url: "URL"; case .upload: "Subir" } }
    }

    // Respaldo cuando el hogar aún no tiene categorías creadas.
    private let fallbackEmojis = ["✨","🏠","💻","🛋️","🧊","🚗","✈️","🎁","👕","📱","🎮","💍","🪑","🍳","🛁","🌴"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    field("Nombre") {
                        TextField("Casa, Tech, Viajes…", text: $name)
                            .textFieldStyle(.plain).font(Typo.body)
                            .padding(Space.m)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke))
                    }

                    field("Categoría") { categoryPicker }

                    field("Portada (opcional)") {
                        VStack(alignment: .leading, spacing: Space.m) {
                            Picker("", selection: $coverMode) {
                                ForEach(CoverMode.allCases, id: \.self) { Text($0.label).tag($0) }
                            }.pickerStyle(.segmented)

                            switch coverMode {
                            case .none: EmptyView()
                            case .url:
                                TextField("https://…", text: $coverUrlText)
                                    .textFieldStyle(.plain).font(Typo.body).autocorrectionDisabled().textInputAutocapitalization(.never)
                                    .padding(Space.m)
                                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke))
                            case .upload:
                                let hasCover = uploadedCover != nil
                                let isUploading = uploading
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    WishPhotoPickerLabel(hasImage: hasCover, uploading: isUploading)
                                }
                            }
                        }
                    }

                    if let error { Text(error).font(Typo.caption).foregroundStyle(.red) }
                }
                .padding(Space.l)
            }
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Nuevo tablero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || saving || uploading)
                }
            }
            .onChange(of: photoItem) { _, item in Task { await upload(item) } }
        }
    }

    // Selector de categoría a partir de las categorías del hogar (ícono Hugeicon
    // + color). Guarda el slug del ícono en `emoji`. Sin categorías → emojis.
    @ViewBuilder private var categoryPicker: some View {
        let cats = app.categories
        if cats.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(fallbackEmojis, id: \.self) { e in
                        Text(e).font(.system(size: 26))
                            .frame(width: 46, height: 46)
                            .background(emoji == e ? Palette.accent.opacity(0.18) : Palette.surface,
                                        in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                .strokeBorder(emoji == e ? Palette.accent : Palette.stroke, lineWidth: emoji == e ? 2 : 1))
                            .onTapGesture { emoji = e }
                    }
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.m) {
                    ForEach(cats) { c in
                        let selected = emoji == c.icon
                        let color = Color(hexString: c.color) ?? Palette.accent
                        VStack(spacing: 6) {
                            CategoryIcon(systemName: IconMapping.sfSymbol(for: c.icon),
                                         color: color, size: 50, slug: c.icon)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 50 * 0.32, style: .continuous)
                                        .strokeBorder(color, lineWidth: selected ? 2.5 : 0)
                                )
                            Text(c.name).font(Typo.caption).foregroundStyle(selected ? Palette.ink : Palette.inkTertiary)
                                .lineLimit(1).frame(maxWidth: 64)
                        }
                        .opacity(selected ? 1 : 0.7)
                        .onTapGesture { emoji = c.icon }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder private func field(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title).font(Typo.caption.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
            content()
        }
    }

    @MainActor
    private func upload(_ item: PhotosPickerItem?) async {
        guard let item, let uid = app.profile?.id else { return }
        uploading = true
        defer { uploading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.6) else {
                error = "No se pudo leer la imagen."; return
            }
            uploadedCover = try await Repository().uploadWishImage(userId: uid, jpeg: jpeg)
        } catch { self.error = error.localizedDescription }
    }

    @MainActor
    private func save() async {
        guard let hh = app.household?.id, let uid = app.profile?.id else { return }
        saving = true
        defer { saving = false }
        let cover: String? = {
            switch coverMode {
            case .none: return nil
            case .url: let t = coverUrlText.trimmingCharacters(in: .whitespaces); return t.isEmpty ? nil : t
            case .upload: return uploadedCover
            }
        }()
        do {
            try await Repository().addWishBoard(
                householdId: hh, userId: uid,
                name: name.trimmingCharacters(in: .whitespaces), emoji: emoji, coverUrl: cover)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
