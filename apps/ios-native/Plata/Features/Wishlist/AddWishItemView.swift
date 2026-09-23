import SwiftUI
import PhotosUI

// Añadir un deseo a un tablero: nombre, foto (URL o subir), precio, link, prioridad.

struct AddWishItemView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let board: WishBoard

    @State private var name = ""
    @State private var photoMode: PhotoMode = .url
    @State private var imageUrlText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var uploadedImage: String?
    @State private var uploading = false
    @State private var priceText = ""
    @State private var link = ""
    @State private var priority: WishPriority = .medium
    @State private var saving = false
    @State private var error: String?

    private enum PhotoMode: String, CaseIterable { case url, upload
        var label: String { self == .url ? "URL" : "Subir" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    field("Nombre") {
                        TextField("Nevera Samsung, sofá…", text: $name)
                            .textFieldStyle(.plain).font(Typo.body).padding(Space.m)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke))
                    }

                    field("Foto") {
                        VStack(alignment: .leading, spacing: Space.m) {
                            Picker("", selection: $photoMode) {
                                ForEach(PhotoMode.allCases, id: \.self) { Text($0.label).tag($0) }
                            }.pickerStyle(.segmented)

                            if photoMode == .url {
                                TextField("https://…", text: $imageUrlText)
                                    .textFieldStyle(.plain).font(Typo.body).autocorrectionDisabled().textInputAutocapitalization(.never)
                                    .padding(Space.m)
                                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke))
                            } else {
                                let hasImage = uploadedImage != nil
                                let isUploading = uploading
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    WishPhotoPickerLabel(hasImage: hasImage, uploading: isUploading)
                                }
                            }

                            if let preview = previewURL, let u = URL(string: preview) {
                                AsyncImage(url: u) { img in img.resizable().scaledToFill() }
                                placeholder: { Palette.surfaceElevated.overlay(ProgressView()) }
                                .frame(height: 140).frame(maxWidth: .infinity).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                            }
                        }
                    }

                    field("Precio (opcional)") {
                        TextField("0", text: $priceText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain).font(Typo.body).padding(Space.m)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke))
                    }

                    field("Link de la tienda (opcional)") {
                        TextField("https://…", text: $link)
                            .textFieldStyle(.plain).font(Typo.body).autocorrectionDisabled().textInputAutocapitalization(.never)
                            .padding(Space.m)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke))
                    }

                    field("Prioridad") {
                        Picker("", selection: $priority) {
                            ForEach(WishPriority.allCases, id: \.self) { Text($0.label).tag($0) }
                        }.pickerStyle(.segmented)
                    }

                    if let error { Text(error).font(Typo.caption).foregroundStyle(.red) }
                }
                .padding(Space.l)
            }
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Nuevo deseo")
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

    private var previewURL: String? {
        switch photoMode {
        case .url: let t = imageUrlText.trimmingCharacters(in: .whitespaces); return t.isEmpty ? nil : t
        case .upload: return uploadedImage
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
            uploadedImage = try await Repository().uploadWishImage(userId: uid, jpeg: jpeg)
        } catch { self.error = error.localizedDescription }
    }

    @MainActor
    private func save() async {
        guard let hh = app.household?.id, let uid = app.profile?.id else { return }
        saving = true
        defer { saving = false }
        let price = Double(priceText.replacingOccurrences(of: ",", with: "."))
        let linkTrim = link.trimmingCharacters(in: .whitespaces)
        do {
            try await Repository().addWishItem(
                boardId: board.id, householdId: hh, userId: uid,
                name: name.trimmingCharacters(in: .whitespaces),
                imageUrl: previewURL, price: price, currency: app.currency,
                link: linkTrim.isEmpty ? nil : linkTrim, priority: priority)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

// Label del PhotosPicker aislado en su propia View: el closure-label de
// PhotosPicker es @Sendable, así que recibe solo valores Sendable (Bool) y
// evita los warnings de aislamiento del actor.
struct WishPhotoPickerLabel: View {
    let hasImage: Bool
    let uploading: Bool

    var body: some View {
        HStack {
            Image(systemName: hasImage ? "checkmark.circle.fill" : "photo.badge.plus")
            Text(uploading ? "Subiendo…" : (hasImage ? "Foto lista" : "Elegir foto"))
        }
        .font(Typo.callout.weight(.semibold)).foregroundStyle(Palette.accent)
        .frame(maxWidth: .infinity).padding(Space.m)
        .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
    }
}
