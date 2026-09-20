import SwiftUI
import UIKit

// Conectar WhatsApp: genera un código de vinculación que el usuario envía una vez
// por WhatsApp al número de Plata. Tras eso puede registrar gastos por texto/voz/
// foto desde WhatsApp.

struct WhatsAppConnectView: View {
    @Environment(AppState.self) private var app

    // Número de WhatsApp de Plata (el conectado en Kapso), solo dígitos.
    private let botNumber = "12017513637"

    @State private var code: String?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header

                VStack(alignment: .leading, spacing: Space.l) {
                    step(1, "Genera tu código", "Toca “Generar código” abajo.")
                    step(2, "Envíalo por WhatsApp", "Abre el chat de Plata y manda el código una sola vez.")
                    step(3, "Registra gastos", "Después escríbele “almuerzo 25 mil” o mándale una nota de voz y Plata lo registra.")
                }

                if let code {
                    VStack(spacing: Space.s) {
                        Text("TU CÓDIGO").font(Typo.overline).tracking(1).foregroundStyle(Palette.inkTertiary)
                        Text(code)
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.ink).tracking(2)
                        Text("Válido por 15 minutos").font(Typo.caption).foregroundStyle(Palette.inkTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Space.l)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))

                    Button { openWhatsApp(with: code) } label: {
                        Label("Abrir WhatsApp con el código", systemImage: "arrow.up.forward.app")
                            .font(Typo.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, Space.l)
                            .background(Palette.accent, in: Capsule())
                    }.buttonStyle(.plain).pressable()
                } else {
                    Button(action: generate) {
                        Group {
                            if loading { ProgressView().tint(.white) }
                            else { Text("Generar código").font(Typo.headline).foregroundStyle(.white) }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, Space.l)
                        .background(Palette.accent, in: Capsule())
                    }.buttonStyle(.plain).pressable()
                }

                if let error {
                    Text(error).font(Typo.subhead).foregroundStyle(Palette.negative)
                }
            }
            .padding(Space.l)
        }
        .floatingTabBarInset()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Conectar WhatsApp")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Image(systemName: "message.fill")
                .font(.system(size: 32, weight: .semibold)).foregroundStyle(Palette.accent)
            Text("Registra gastos por WhatsApp")
                .font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.ink)
            Text("Manda un texto, una nota de voz o una foto de tu recibo y Plata lo registra por ti.")
                .font(Typo.subhead).foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Text("\(n)").font(Typo.callout.weight(.bold)).foregroundStyle(.white)
                .frame(width: 28, height: 28).background(Palette.accent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.callout.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(Typo.subhead).foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func generate() {
        guard let uid = app.profile?.id, let hh = app.household?.id else { return }
        loading = true; error = nil
        Task {
            do { code = try await Repository().createWhatsAppCode(userId: uid, householdId: hh) }
            catch { self.error = "No se pudo generar el código. Inténtalo de nuevo." }
            loading = false
        }
    }

    private func openWhatsApp(with code: String) {
        let text = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        if let url = URL(string: "https://wa.me/\(botNumber)?text=\(text)") {
            UIApplication.shared.open(url)
        }
    }
}
