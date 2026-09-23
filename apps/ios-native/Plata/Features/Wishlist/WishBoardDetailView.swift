import SwiftUI

// Detalle de un tablero de deseos: galería de items con foto, precio, prioridad y
// link. Estilo Dreamboard (grid de fotos).

struct WishBoardDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    let board: WishBoard

    @State private var items: [WishItem] = []
    @State private var loading = false
    @State private var showAddItem = false

    private let columns = [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let total = totalText {
                    Text(total).font(Typo.subhead).foregroundStyle(Palette.inkSecondary)
                }
                if items.isEmpty && !loading {
                    empty
                } else {
                    LazyVGrid(columns: columns, spacing: Space.m) {
                        ForEach(items) { item in
                            WishCard(item: item, currency: app.currency,
                                     onOpen: { if let l = item.link, let u = URL(string: l) { openURL(u) } },
                                     onToggle: { Task { await toggle(item) } },
                                     onDelete: { Task { await delete(item) } })
                        }
                    }
                }
            }
            .padding(.horizontal, Space.l).padding(.top, Space.s)
        }
        .floatingTabBarInset()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("\(board.emoji ?? "") \(board.name)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddItem = true } label: {
                    Image(systemName: "plus").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.accent)
                }
            }
        }
        .sheet(isPresented: $showAddItem, onDismiss: { Task { await load() } }) {
            AddWishItemView(board: board)
        }
    }

    private var totalText: String? {
        let pending = items.filter { !$0.acquired }.compactMap { $0.price }.reduce(0, +)
        guard pending > 0 else { return nil }
        return "Total deseado: \(CurrencyFormatter.string(pending, currency: app.currency))"
    }

    private var empty: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40)).foregroundStyle(Palette.accent)
            Text("Añade tu primer deseo").font(Typo.headline).foregroundStyle(Palette.ink)
            Button { showAddItem = true } label: {
                Text("Añadir deseo").font(Typo.callout.weight(.semibold)).foregroundStyle(Palette.accent)
            }
        }.frame(maxWidth: .infinity).padding(.top, Space.xxl)
    }

    private func load() async {
        loading = true
        items = (try? await Repository().fetchWishItems(boardId: board.id)) ?? []
        loading = false
    }
    private func toggle(_ item: WishItem) async {
        try? await Repository().setWishAcquired(id: item.id, acquired: !item.acquired)
        await load()
    }
    private func delete(_ item: WishItem) async {
        try? await Repository().deleteWishItem(id: item.id)
        await load()
    }
}

// MARK: - Tarjeta de deseo

private struct WishCard: View {
    let item: WishItem
    let currency: String
    var onOpen: () -> Void
    var onToggle: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let url = item.imageUrl, let u = URL(string: url) {
                        AsyncImage(url: u) { img in img.resizable().scaledToFill() }
                        placeholder: { Palette.surfaceElevated.overlay(ProgressView()) }
                    } else {
                        Palette.surfaceElevated.overlay(
                            Image(systemName: "gift").font(.system(size: 34)).foregroundStyle(Palette.inkTertiary))
                    }
                }
                .frame(height: 150).frame(maxWidth: .infinity).clipped()
                .opacity(item.acquired ? 0.5 : 1)

                PriorityDot(priority: item.priority).padding(Space.s)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(Typo.subhead.weight(.semibold)).foregroundStyle(Palette.ink)
                    .lineLimit(2).strikethrough(item.acquired)
                if let price = item.price {
                    Text(CurrencyFormatter.string(price, currency: item.currency))
                        .font(Typo.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                }
            }
            .padding(Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .contextMenu {
            if item.link != nil { Button { onOpen() } label: { Label("Abrir link", systemImage: "safari") } }
            Button { onToggle() } label: {
                Label(item.acquired ? "Marcar como deseado" : "Marcar como logrado",
                      systemImage: item.acquired ? "arrow.uturn.backward" : "checkmark.circle")
            }
            Button(role: .destructive) { onDelete() } label: { Label("Eliminar", systemImage: "trash") }
        }
    }
}

private struct PriorityDot: View {
    let priority: WishPriority
    var color: Color { switch priority { case .high: .red; case .medium: Palette.amber; case .low: Palette.inkTertiary } }
    var body: some View {
        Text(priority.label)
            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            .padding(.vertical, 3).padding(.horizontal, 8)
            .background(color, in: Capsule())
    }
}
