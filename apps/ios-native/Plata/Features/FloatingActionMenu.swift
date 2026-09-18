import SwiftUI

// FAB de acción flotante en la esquina inferior derecha (paridad con el
// FloatingMenu.tsx del legacy). Un botón "+" que despliega las 7 acciones de
// creación hacia arriba (speed-dial) con backdrop, stagger y rotación a "×".
// Encima del "+" flota un botón de micrófono para dictar desde cualquier
// pantalla (acceso rápido). No es un sheet: se anima sobre el contenido.
//
// Uso: se monta como overlay en MainTabView. `onSelect` recibe el destino
// elegido; `onVoice` abre el dictado.

struct FloatingActionMenu: View {
    var onSelect: (AddDestination) -> Void
    var onVoice: () -> Void

    @State private var isOpen = false

    // Orden visual: la primera del array queda pegada al FAB (más abajo). Se
    // pintan de abajo hacia arriba, como en el legacy (Transacción primero).
    private let actions: [AddDestination] = [
        .transaction, .budget, .shoppingList, .goal, .debt, .account, .recurring,
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Backdrop: oscurece y captura el tap para cerrar.
            if isOpen {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .transition(.opacity)
            }

            // Columna de acciones (speed-dial) + FAB + micrófono, anclada abajo-dcha.
            VStack(alignment: .trailing, spacing: Space.m) {
                if isOpen {
                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        SpeedDialRow(destination: action) {
                            select(action)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }

                // Micrófono: acceso rápido al dictado. Se oculta cuando el menú
                // está abierto para no competir con la "×".
                if !isOpen {
                    MicFloatingButton { onVoice() }
                        .transition(.scale.combined(with: .opacity))
                }

                // FAB principal.
                PlusFloatingButton(isOpen: isOpen) {
                    isOpen ? close() : open()
                }
            }
            .padding(.trailing, Space.l)
            // Sube sobre el tab bar flotante (cápsula ~96pt) + aire.
            .padding(.bottom, 96 + Space.m)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isOpen)
    }

    // MARK: - Acciones

    private func open() { isOpen = true }
    private func close() { isOpen = false }

    private func select(_ destination: AddDestination) {
        close()
        // Deja arrancar el cierre antes de presentar el add (evita solaparse).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onSelect(destination)
        }
    }
}

// MARK: - Fila del speed-dial ([label] [botón circular])

private struct SpeedDialRow: View {
    let destination: AddDestination
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                Text(destination.label)
                    .font(Typo.subhead.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Space.m)
                    .padding(.vertical, Space.xs)
                    .background(.black.opacity(0.35), in: Capsule())

                Image(systemName: destination.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 48, height: 48)
                    .background(destination.tint, in: Circle())
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            }
        }
        .pressable(scale: 0.94)
    }
}

// MARK: - FAB "+" (rota a × al abrir)

private struct PlusFloatingButton: View {
    let isOpen: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Palette.onAccent)
                .rotationEffect(.degrees(isOpen ? 135 : 0))
                .frame(width: 60, height: 60)
                .background(Palette.accent, in: Circle())
                .shadow(color: Palette.accent.opacity(0.4), radius: 12, y: 5)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .pressable(scale: 0.9)
        .accessibilityLabel(isOpen ? "Cerrar menú" : "Crear")
    }
}

// MARK: - Botón de micrófono flotante

private struct MicFloatingButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 48, height: 48)
                .liquidGlassCapsule(interactive: true)
                .overlay(Circle().strokeBorder(Palette.stroke.opacity(0.5), lineWidth: 1))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
        }
        .pressable(scale: 0.9)
        .accessibilityLabel("Dictar movimiento")
    }
}
