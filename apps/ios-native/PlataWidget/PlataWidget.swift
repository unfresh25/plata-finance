import WidgetKit
import SwiftUI
import AppIntents

// Widget de accesos rápidos (sin App Group / sin datos en vivo): dos botones que
// abren la app en el dictado por voz o en el chat, vía los App Intents que ya
// existen en la app (RegistrarGastoIntent / PreguntarPlataIntent).

struct QuickEntry: TimelineEntry { let date: Date }

struct QuickProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickEntry { QuickEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (QuickEntry) -> Void) {
        completion(QuickEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickEntry>) -> Void) {
        completion(Timeline(entries: [QuickEntry(date: Date())], policy: .never))
    }
}

struct PlataWidgetView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("plata.")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                quickButton(intent: RegistrarGastoIntent(), icon: "mic.fill", label: "Dictar")
                quickButton(intent: PreguntarPlataIntent(), icon: "sparkles", label: "Plata IA")
            }
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func quickButton(intent: some AppIntent, icon: String, label: String) -> some View {
        Button(intent: intent) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(red: 0.49, green: 0.42, blue: 1.0), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

struct PlataWidget: Widget {
    let kind = "PlataWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickProvider()) { _ in
            PlataWidgetView()
        }
        .configurationDisplayName("Plata — Accesos rápidos")
        .description("Registra un gasto por voz o pregúntale a Plata.")
        .supportedFamilies([.systemMedium, .systemSmall])
    }
}

@main
struct PlataWidgetBundle: WidgetBundle {
    var body: some Widget { PlataWidget() }
}
