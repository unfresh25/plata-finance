import SwiftUI

// Lista de deseos estilo "Dreamboard": tableros (categorías con portada) y, dentro
// de cada uno, deseos con foto, precio, link y prioridad. Objetivos a corto plazo
// (nevera, lavadora, muebles, viajes…) de forma visual.

struct WishlistView: View {
    @Environment(AppState.self) private var app
    @State private var boards: [WishBoard] = []
    @State private var loading = false
    @State private var showAddBoard = false

    private let columns = [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                header

                if boards.isEmpty && !loading {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: Space.m) {
                        ForEach(boards) { board in
                            NavigationLink {
                                WishBoardDetailView(board: board)
                            } label: {
                                BoardCard(board: board)
                            }
                            .buttonStyle(.plain)
                            .pressable(scale: 0.97)
                        }
                    }
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.s)
        }
        .floatingTabBarInset()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Deseos")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddBoard = true } label: {
                    Image(systemName: "plus").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .sheet(isPresented: $showAddBoard, onDismiss: { Task { await load() } }) {
            AddWishBoardView()
        }
    }

    private var header: some View {
        Text("Guarda lo que sueñas comprar: neveras, muebles, viajes… con foto, precio y link.")
            .font(Typo.subhead).foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyState: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 44, weight: .semibold)).foregroundStyle(Palette.accent)
            Text("Aún no tienes tableros").font(Typo.headline).foregroundStyle(Palette.ink)
            Text("Crea uno (Casa, Tech, Viajes…) y llénalo de deseos.")
                .font(Typo.subhead).foregroundStyle(Palette.inkSecondary).multilineTextAlignment(.center)
            Button { showAddBoard = true } label: {
                Text("Crear tablero").font(Typo.callout.weight(.semibold)).foregroundStyle(Palette.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.xxl)
    }

    private func load() async {
        guard let hh = app.household?.id else { return }
        loading = true
        boards = (try? await Repository().fetchWishBoards(household: hh)) ?? []
        loading = false
    }
}

// MARK: - Tarjeta de tablero

private struct BoardCard: View {
    let board: WishBoard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let cover = board.coverUrl, let url = URL(string: cover) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Palette.surfaceElevated }
                    .frame(height: 130).clipped()
                } else {
                    LinearGradient(colors: [Palette.accent.opacity(0.5), Palette.accent.opacity(0.25)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 130)
                        .overlay(WishBoardGlyph(glyph: board.emoji, size: 44, tint: .white))
                }
            }
            HStack(spacing: Space.xs) {
                if board.coverUrl != nil { WishBoardGlyph(glyph: board.emoji, size: 20, tint: Palette.accent) }
                Text(board.name).font(Typo.callout.weight(.semibold)).foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }
            .padding(Space.m)
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
    }
}

// MARK: - Glifo del tablero
//
// El campo `emoji` del tablero guarda o bien un emoji suelto, o bien el slug del
// ícono de una categoría del hogar (Hugeicon). Este helper decide cómo pintarlo:
// si el slug tiene un Hugeicon real, se usa ese teñido; si no, se muestra como
// texto (emoji). Así los tableros usan las categorías creadas por el usuario.
struct WishBoardGlyph: View {
    let glyph: String?
    var size: CGFloat = 28
    var tint: Color = Palette.accent

    var body: some View {
        let g = glyph ?? "✨"
        if let hugeicon = CategoryIconAsset.image(forSlug: g) {
            hugeicon.resizable().scaledToFit()
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        } else if isLikelySlug(g) {
            // Slug sin asset Hugeicon → SF Symbol mapeado, teñido.
            Image(systemName: IconMapping.sfSymbol(for: g))
                .font(.system(size: size * 0.9, weight: .semibold))
                .foregroundStyle(tint)
        } else {
            Text(g).font(.system(size: size))
        }
    }

    // Heurística: un slug de categoría es ASCII con letras/dígitos/guiones; un
    // emoji contiene escalares fuera de ese rango.
    private func isLikelySlug(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }
}
