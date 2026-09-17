import SwiftUI

// Suscripciones y pagos recurrentes del hogar. Cada fila muestra el logo de la
// app (si el nombre coincide con un slug del catálogo) o el ícono de su
// categoría, junto al nombre, la frecuencia (Frequency.label), el próximo cobro
// y el monto. Tap abre el detalle (sheet) con el flujo de confirmar pago.
// Paridad con app/recurring en la app RN original.

struct RecurringView: View {
    @Environment(AppState.self) private var app

    @State private var showAdd = false
    @State private var selected: RecurringEvent?

    private var events: [RecurringEvent] {
        // El mismo orden que trae el Repository (next_date asc), activos primero.
        app.recurringEvents.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
            return lhs.nextDate < rhs.nextDate
        }
    }

    // Solo gastos: el encabezado muestra el "gasto mensual estimado", así que los
    // recurrentes de ingreso no deben inflar esa cifra.
    private var monthlyTotal: Double {
        app.recurringEvents
            .filter { $0.isActive && $0.type == .expense }
            .reduce(0) { $0 + RecurrentesMath.monthlyEquivalent(amount: $1.amount, frequency: $1.frequency) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if events.isEmpty {
                    RecurrentesEmptyState { showAdd = true }
                        .padding(.top, Space.xxxl)
                } else {
                    RecurrentesSummaryHeader(monthlyTotal: monthlyTotal, count: events.filter(\.isActive).count)
                        .padding(.top, Space.s)

                    RowDivider()
                        .padding(.vertical, Space.l)

                    PlainSection(title: "Suscripciones") {
                        PlainList(events, dividerInset: 46 + Space.l) { event in
                            Button {
                                selected = event
                            } label: {
                                RecurrentesRow(event: event)
                            }
                            .buttonStyle(.plain)
                            .pressable()
                        }
                    }
                }
            }
            .padding(.horizontal, Space.l)
        }
        .floatingTabBarInset()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Recurrentes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddRecurringView()
                .presentationBackground(Palette.bg)
        }
        .sheet(item: $selected) { event in
            RecurringDetailView(event: event)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.bg)
        }
    }
}

// MARK: - Resumen (total mensual estimado) — plano, sin card

private struct RecurrentesSummaryHeader: View {
    @Environment(AppState.self) private var app
    let monthlyTotal: Double
    let count: Int

    var body: some View {
        HStack(alignment: .center, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("GASTO MENSUAL ESTIMADO")
                    .font(Typo.overline)
                    .tracking(0.8)
                    .foregroundStyle(Palette.inkTertiary)
                AmountText(amount: monthlyTotal, currency: app.currency, font: Typo.amountLarge)
                    .tracking(-0.5)
                Text(count == 1 ? "1 suscripción activa" : "\(count) suscripciones activas")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: Space.s)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 48, height: 48)
                .background(Palette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Fila de recurrente

private struct RecurrentesRow: View {
    @Environment(AppState.self) private var app
    let event: RecurringEvent

    private var category: Category? { app.category(for: event.categoryId) }
    private var tint: Color { RecurrentesVisual.tint(for: event, category: category) }

    var body: some View {
        HStack(spacing: Space.l) {
            // Logo de la app (con aire, vía RowLeadingIcon) o el ícono de su
            // categoría teñido si no hay logo conocido.
            RowLeadingIcon(
                logo: RecurrentesVisual.logo(for: event),
                categoryIcon: CategoryIconAsset.image(forSlug: category?.icon),
                systemName: RecurrentesVisual.symbol(for: event, category: category),
                color: tint,
                size: 46
            )
            .opacity(event.isActive ? 1 : 0.55)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.name)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                HStack(spacing: Space.xs) {
                    Text(event.frequency.label)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkSecondary)
                    Text("·")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                    Text(RecurrentesDate.nextLabel(event.nextDate))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
            }

            Spacer(minLength: Space.s)

            VStack(alignment: .trailing, spacing: 3) {
                // Ingreso: +verde · Gasto: −pink (signo y color por tipo).
                AmountText(
                    amount: event.type == .income ? event.amount : -event.amount,
                    currency: app.currency,
                    font: Typo.amount,
                    signed: true,
                    tintBySign: true
                )
                if !event.isActive {
                    // Badge de estado: capa teñida sutil con borde luminoso (sin glow).
                    Text("Pausada")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.warning)
                        .padding(.horizontal, Space.s)
                        .padding(.vertical, 2)
                        .background(Palette.warning.opacity(0.14), in: Capsule())
                        .overlay(Capsule().strokeBorder(Palette.warning.opacity(0.28), lineWidth: 0.5))
                }
            }
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Estado vacío

private struct RecurrentesEmptyState: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: Space.l) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 34))
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 84, height: 84)
                .background(Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))

            VStack(spacing: Space.xs) {
                Text("Sin recurrentes")
                    .font(Typo.title)
                    .foregroundStyle(Palette.ink)
                Text("Agrega tus suscripciones y pagos fijos para no perder de vista lo que se cobra cada mes.")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xl)
            }

            Button(action: onAdd) {
                HStack(spacing: Space.s) {
                    Image(systemName: "plus")
                    Text("Nueva suscripción").font(Typo.headline)
                }
                .foregroundStyle(Palette.bg)
                .padding(.horizontal, Space.xl)
                .padding(.vertical, Space.m)
                .background(Palette.ink, in: Capsule())
            }
            .pressable()
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Avatar compartido (logo de app o ícono de categoría)

struct RecurrentesAvatar: View {
    @Environment(AppState.self) private var app
    let event: RecurringEvent
    let category: Category?
    var size: CGFloat = 46

    private var tint: Color { RecurrentesVisual.tint(for: event, category: category) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(logo == nil ? tint.opacity(0.16) : Palette.surfaceElevated)
                .frame(width: size, height: size)

            if let logo {
                logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.62, height: size * 0.62)
            } else {
                Image(systemName: RecurrentesVisual.symbol(for: event, category: category))
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .strokeBorder(Palette.stroke.opacity(logo == nil ? 0 : 1), lineWidth: 1)
        )
    }

    private var logo: Image? {
        RecurrentesVisual.logo(for: event)
    }
}

// MARK: - Resolución de logo / ícono / color (compartida en la feature)

enum RecurrentesVisual {
    /// Logo del evento: primero el `logo_id` guardado en la BD (fiable), y si no,
    /// se intenta adivinar por el nombre del servicio.
    static func logo(for event: RecurringEvent) -> Image? {
        if let stored = SubscriptionLogo.imageForStoredId(event.logoId) {
            return stored
        }
        return SubscriptionLogo.image(for: slug(for: event.name))
    }

    /// Normaliza el nombre del servicio a un slug del catálogo (Netflix → netflix).
    static func slug(for name: String) -> String? {
        // Normaliza sin acentos, en minúsculas y con "+" → "plus" (Disney+ → disney+plus)
        // para poder probar la variante con "-plus".
        let normalized = name
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "+", with: " plus ")
            .trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return nil }

        // Compacta: quita guiones, espacios y cualquier separador no alfanumérico.
        func compact(_ value: String) -> String {
            String(value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        }
        let target = compact(normalized)          // "disneyplus", "applemusicfamiliar"
        guard !target.isEmpty else { return nil }

        // Coincidencia exacta por slug (con y sin espacios → guiones).
        let dashed = normalized.replacingOccurrences(of: " ", with: "-")
        if SubscriptionLogo.all.contains(normalized) { return normalized }
        if SubscriptionLogo.all.contains(dashed) { return dashed }

        // Elige el slug MÁS LARGO cuya versión compacta sea prefijo del nombre compacto.
        // Ej.: "applemusic" es prefijo de "applemusicfamiliar" → apple-music.
        //      "disney" es prefijo de "disneyplus" → disney- (slug del catálogo).
        // El slug más largo gana para evitar falsos positivos (apple-, disney-, etc.).
        return SubscriptionLogo.all
            .filter { slug in
                let base = compact(slug)
                return base.count >= 3 && target.hasPrefix(base)
            }
            .max { compact($0).count < compact($1).count }
    }

    static func tint(for event: RecurringEvent, category: Category?) -> Color {
        TransactionVisual.color(for: category)
    }

    static func symbol(for event: RecurringEvent, category: Category?) -> String {
        if let category {
            return TransactionVisual.symbol(for: category, fallbackType: event.type)
        }
        return "arrow.triangle.2.circlepath"
    }
}

// MARK: - Fechas y matemática de frecuencia (compartidas en la feature)

enum RecurrentesDate {
    /// "Hoy", "Mañana", "en 3 días" o la fecha corta para el próximo cobro.
    static func nextLabel(_ isoDate: String) -> String {
        guard let date = parse(isoDate) else { return isoDate }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: start, to: target).day ?? 0
        switch days {
        case ..<0: return "Vencido"
        case 0: return "Hoy"
        case 1: return "Mañana"
        case 2...6: return "en \(days) días"
        default: return shortDate(date)
        }
    }

    static func fullLabel(_ isoDate: String) -> String {
        guard let date = parse(isoDate) else { return isoDate }
        return shortDate(date)
    }

    static func parse(_ isoDate: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(isoDate.prefix(10)))
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.setLocalizedDateFormatFromTemplate("d MMM")
        let s = f.string(from: date)
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

enum RecurrentesMath {
    /// Equivalente mensual aproximado del monto según su frecuencia.
    static func monthlyEquivalent(amount: Double, frequency: Frequency) -> Double {
        switch frequency {
        case .daily: return amount * 30
        case .weekly: return amount * 52 / 12
        case .biweekly: return amount * 26 / 12
        case .monthly: return amount
        case .yearly: return amount / 12
        }
    }
}
