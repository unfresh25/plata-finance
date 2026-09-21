import WidgetKit
import SwiftUI
import AppIntents

// Widget de accesos rápidos, CONFIGURABLE por el usuario (long-press → Editar,
// elige la acción). Sin App Group ni datos en vivo: el personaje "se asoma" y al
// tocar abre la app en la acción elegida (voz / chat / registrar).

// MARK: - Acción configurable

enum WidgetAction: String, AppEnum {
    case voz, chat, registrar

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Acción"
    static let caseDisplayRepresentations: [WidgetAction: DisplayRepresentation] = [
        .voz: "Dictar por voz",
        .chat: "Preguntar a Plata",
        .registrar: "Registrar gasto",
    ]

    var label: String {
        switch self { case .voz: "Dictar"; case .chat: "Plata IA"; case .registrar: "Registrar" }
    }
    var art: String {
        switch self { case .voz: "WidgetVoz"; case .chat: "WidgetChat"; case .registrar: "WidgetRegistrar" }
    }
}

struct PlataWidgetConfig: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Acceso rápido de Plata"
    static let description = IntentDescription("Elige qué hace este widget.")

    @Parameter(title: "Acción", default: .voz)
    var action: WidgetAction
}

// MARK: - Provider

struct QuickEntry: TimelineEntry {
    let date: Date
    let action: WidgetAction
}

struct QuickProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickEntry { QuickEntry(date: .now, action: .voz) }
    func snapshot(for configuration: PlataWidgetConfig, in context: Context) async -> QuickEntry {
        QuickEntry(date: .now, action: configuration.action)
    }
    func timeline(for configuration: PlataWidgetConfig, in context: Context) async -> Timeline<QuickEntry> {
        Timeline(entries: [QuickEntry(date: .now, action: configuration.action)], policy: .never)
    }
}

// MARK: - Vista

struct PlataWidgetView: View {
    let entry: QuickEntry

    private var intent: any AppIntent {
        switch entry.action {
        case .voz: RegistrarGastoIntent()
        case .chat: PreguntarPlataIntent()
        case .registrar: RegistrarGastoIntent()   // abre dictado; ajustable a alta directa
        }
    }

    var body: some View {
        VStack {
            Text(entry.action.label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.20, green: 0.16, blue: 0.34))
                .padding(.top, 12)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // La imagen del personaje va como fondo del contenedor del widget,
        // anclada abajo para que "se asome". Fallback lila si no cargara.
        .containerBackground(for: .widget) {
            ZStack {
                Color(red: 0.93, green: 0.91, blue: 1.0)
                Image(entry.action.art)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

// MARK: - Widget

struct PlataWidget: Widget {
    let kind = "PlataWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PlataWidgetConfig.self, provider: QuickProvider()) { entry in
            Button(intent: intentFor(entry.action)) {
                PlataWidgetView(entry: entry)
            }
            .buttonStyle(.plain)
        }
        .configurationDisplayName("Plata — Acceso rápido")
        .description("Un toque para dictar, preguntar o registrar. Mantén pulsado para elegir la acción.")
        .supportedFamilies([.systemSmall])
    }

    private func intentFor(_ a: WidgetAction) -> any AppIntent {
        switch a {
        case .voz, .registrar: RegistrarGastoIntent()
        case .chat: PreguntarPlataIntent()
        }
    }
}

@main
struct PlataWidgetBundle: WidgetBundle {
    var body: some Widget { PlataWidget() }
}
