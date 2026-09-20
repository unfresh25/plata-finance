import SwiftUI
import UIKit

// Guía para capturar pagos de Apple Pay automáticamente. iOS no permite crear la
// automatización desde la app; el usuario la arma una vez en Atajos. Esta pantalla
// explica los pasos y ofrece atajos: abrir la app Atajos y (si está publicado)
// instalar el atajo pre-armado desde iCloud.

struct ApplePayGuideView: View {
    // Pega aquí el enlace iCloud del atajo pre-armado cuando lo publiques.
    // Mientras esté vacío, solo se muestra el botón "Abrir Atajos".
    private let shortcutURL: URL? = URL(string: "https://www.icloud.com/shortcuts/aa3ded1de96348208744ead55483ea0c")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header

                VStack(alignment: .leading, spacing: Space.l) {
                    step(1, "Abre la app Atajos", "Toca el botón de abajo o busca “Atajos” en tu iPhone.")
                    step(2, "Nueva automatización", "En la pestaña Automatización, toca + y elige “Transacción” (Wallet / Apple Pay).")
                    step(3, "Elige cuándo", "Selecciona la tarjeta y “Se realiza” un pago. Marca “Ejecutar de inmediato”.")
                    step(4, "Agrega la acción", "Busca la acción “Capturar pago en Plata” y pásale el Monto y el Comercio de la transacción.")
                    step(5, "Listo", "Cada vez que pagues con esa tarjeta, Plata abrirá el gasto ya prellenado para confirmar.")
                }

                VStack(spacing: Space.m) {
                    if let url = shortcutURL {
                        Button { UIApplication.shared.open(url) } label: {
                            Label("Instalar atajo pre-armado", systemImage: "square.and.arrow.down")
                                .font(Typo.headline).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, Space.l)
                                .background(Palette.accent, in: Capsule())
                        }.buttonStyle(.plain).pressable()
                    }
                    Button { openShortcutsApp() } label: {
                        Label("Abrir Atajos", systemImage: "arrow.up.forward.app")
                            .font(Typo.callout.weight(.semibold)).foregroundStyle(Palette.accent)
                            .frame(maxWidth: .infinity).padding(.vertical, Space.l)
                            .background(Palette.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
                    }.buttonStyle(.plain).pressable()
                }

                Text("Nota: iOS no permite que una app cree esta automatización por ti ni lea tus pagos directamente; por eso se configura una vez en Atajos.")
                    .font(Typo.caption).foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.l)
        }
        .floatingTabBarInset()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Capturar pagos")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 32, weight: .semibold)).foregroundStyle(Palette.accent)
            Text("Registra tus pagos con Apple Pay")
                .font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.ink)
            Text("Configura una vez y cada compra con Apple Pay se registra sola en Plata.")
                .font(Typo.subhead).foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Text("\(n)")
                .font(Typo.callout.weight(.bold)).foregroundStyle(.white)
                .frame(width: 28, height: 28).background(Palette.accent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.callout.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(Typo.subhead).foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func openShortcutsApp() {
        if let url = URL(string: "shortcuts://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
