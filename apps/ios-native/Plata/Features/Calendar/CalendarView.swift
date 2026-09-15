import SwiftUI

// Calendario mensual de Plata — paridad con app/(tabs)/calendar.tsx de la app RN.
//
// Grid de días del mes con badges de logos por día. Al seleccionar un día, las
// tres listas de abajo (Pagos pendientes, Próximos pagos, Movimientos) se
// filtran a ese día. Los "próximos pagos" son ocurrencias de recurrentes
// proyectadas dentro del mes visible (getOccurrencesInMonth con guard de
// seguridad, idéntico al original) más las deudas con dueDate futuras. Los
// "pendientes" son recurrentes/deudas cuya fecha ya venció (<= hoy). Los
// movimientos son transacciones cuya date cae en el mes/día.
//
// Todo el estado de datos viene de AppState (app.recurringEvents, app.debts,
// app.transactions, app.categories). Los nombres de los miembros se cargan una
// vez vía Repository para mostrar la inicial del creador de cada movimiento,
// tal como en el original.

struct CalendarView: View {
    @Environment(AppState.self) private var app

    @State private var currentDate = Date()
    @State private var selectedDay: Int? = nil
    @State private var memberNames: [String: String] = [:]  // profileId → name

    private let cal = CalendarModel.calendar

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Space.xxl) {
                        CalendarMonthHeader(
                            title: monthTitle,
                            onPrev: { changeMonth(-1) },
                            onNext: { changeMonth(1) }
                        )
                        .padding(.horizontal, Space.l)

                        calendarGrid
                            .padding(.horizontal, Space.l)

                        VStack(alignment: .leading, spacing: Space.xl) {
                            pendingSection
                            upcomingSection
                            transactionsSection
                        }
                        .padding(.horizontal, Space.l)
                    }
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.xxxl)
                }
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
        .task { await loadMembers() }
    }

    // MARK: - Grid del mes

    private var calendarGrid: some View {
        VStack(spacing: Space.s) {
            // Cabecera de días de la semana.
            HStack(spacing: 0) {
                ForEach(CalendarModel.weekdays, id: \.self) { d in
                    Text(d)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, cell in
                    if let day = cell {
                        CalendarDayCell(
                            day: day,
                            isToday: isToday(day),
                            isSelected: selectedDay == day,
                            badges: badges(forDay: day)
                        ) {
                            withAnimation(Motion.ui) {
                                selectedDay = selectedDay == day ? nil : day
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: CalendarModel.cellHeight)
                    }
                }
            }
        }
    }

    // MARK: - Sección: pagos pendientes

    private var pendingSection: some View {
        Group {
            if !pendingEventsRaw.isEmpty {
                VStack(alignment: .leading, spacing: Space.m) {
                    CalendarSectionHeader(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: Palette.amber,
                        title: "Pagos pendientes",
                        count: pendingEvents.count
                    )
                    CalendarEventList(
                        events: pendingEvents,
                        emptyText: "Sin pagos pendientes en \(selectedDay != nil ? "este día" : "este mes")",
                        currency: app.currency,
                        pending: true
                    )
                }
            }
        }
    }

    // MARK: - Sección: próximos pagos

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            CalendarSectionHeader(
                icon: "calendar",
                iconColor: Palette.orange,
                title: "Próximos pagos",
                count: displayedEvents.count
            )
            CalendarEventList(
                events: displayedEvents,
                emptyText: "Sin pagos en \(selectedDay != nil ? "este día" : "este mes")",
                currency: app.currency,
                pending: false
            )
        }
    }

    // MARK: - Sección: movimientos

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            CalendarSectionHeader(
                icon: "calendar",
                iconColor: Palette.sky,
                title: "Movimientos",
                count: displayedTransactions.count
            )
            CalendarTransactionList(
                transactions: displayedTransactions,
                memberNames: memberNames,
                emptyText: "Sin movimientos en \(selectedDay != nil ? "este día" : "este mes")",
                currency: app.currency
            )
        }
    }

    // MARK: - Navegación de mes

    private func changeMonth(_ offset: Int) {
        selectedDay = nil
        if let nd = cal.date(byAdding: .month, value: offset, to: currentDate) {
            withAnimation(Motion.value) { currentDate = nd }
        }
    }

    private var monthTitle: String {
        let raw = CalendarModel.monthFormatter.string(from: currentDate)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    // Celdas del mes: nils de relleno al inicio + los números de día.
    private var monthCells: [Int?] {
        let comps = cal.dateComponents([.year, .month], from: currentDate)
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: currentDate) else { return [] }
        // weekday: 1 = domingo (con locale es_CO Calendar); alineamos a Dom..Sáb.
        let firstWeekday = cal.component(.weekday, from: first) - 1
        var cells: [Int?] = Array(repeating: nil, count: firstWeekday)
        cells.append(contentsOf: range.map { Optional($0) })
        return cells
    }

    private func isToday(_ day: Int) -> Bool {
        let now = Date()
        return cal.component(.day, from: now) == day
            && cal.component(.month, from: now) == cal.component(.month, from: currentDate)
            && cal.component(.year, from: now) == cal.component(.year, from: currentDate)
    }

    // MARK: - Proyección de recurrentes (paridad getOccurrencesInMonth)

    private var visibleYear: Int { cal.component(.year, from: currentDate) }
    private var visibleMonth: Int { cal.component(.month, from: currentDate) }  // 1...12

    private var todayStart: Date { cal.startOfDay(for: Date()) }

    private var monthStart: Date {
        cal.date(from: DateComponents(year: visibleYear, month: visibleMonth, day: 1)) ?? currentDate
    }

    private var monthEnd: Date {
        // Fin del mes a las 23:59:59.
        let startNext = cal.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        return cal.date(byAdding: .second, value: -1, to: startNext) ?? startNext
    }

    /// Ocurrencias de un recurrente dentro del mes visible. Réplica exacta del
    /// original: itera desde nextDate sumando por frecuencia, con guard de 50.
    private func occurrences(of ev: RecurringEvent) -> [Date] {
        guard var current = CalendarModel.parseLocalDate(ev.nextDate) else { return [] }
        let end = monthEnd
        let start = monthStart
        if current > end { return [] }
        var out: [Date] = []
        var safety = 0
        while current <= end && safety < 50 {
            safety += 1
            if current >= start { out.append(current) }
            switch ev.frequency {
            case .monthly: current = cal.date(byAdding: .month, value: 1, to: current) ?? end.addingTimeInterval(1)
            case .yearly:  current = cal.date(byAdding: .year, value: 1, to: current) ?? end.addingTimeInterval(1)
            case .weekly:  current = cal.date(byAdding: .day, value: 7, to: current) ?? end.addingTimeInterval(1)
            case .biweekly: current = cal.date(byAdding: .day, value: 14, to: current) ?? end.addingTimeInterval(1)
            case .daily:   current = cal.date(byAdding: .day, value: 1, to: current) ?? end.addingTimeInterval(1)
            }
        }
        return out
    }

    // MARK: - Deudas con dueDate como eventos

    private var formattedDebts: [CalendarEvent] {
        app.debts.compactMap { d -> CalendarEvent? in
            guard d.status == .active, let due = d.dueDate, !due.isEmpty else { return nil }
            // due_date + T12:00:00 (mediodía) igual que el original.
            guard let date = CalendarModel.parseLocalDate(due) else { return nil }
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
            let name = "Deuda: \(d.description?.isEmpty == false ? d.description! : d.personName)"
            let category = app.category(for: nil)  // deudas no traen categoría en AppState
            return CalendarEvent(
                id: d.id,
                name: name,
                amount: d.remaining,
                isIncome: d.direction == .owedToUs,
                date: noon,
                frequencyLabel: nil,
                category: category,
                logoSlug: nil,
                isDebt: true,
                targetId: d.id
            )
        }
    }

    // MARK: - Listas derivadas

    /// Recurrentes + deudas cuya fecha ya venció (<= hoy) → pendientes.
    private var pendingEventsRaw: [CalendarEvent] {
        let rec = app.recurringEvents.compactMap { ev -> CalendarEvent? in
            guard let d = CalendarModel.parseLocalDate(ev.nextDate) else { return nil }
            guard d <= todayStart else { return nil }
            return event(from: ev, on: d)
        }
        let debtsPending = formattedDebts.filter { $0.date <= todayStart }
        return rec + debtsPending
    }

    private var pendingEvents: [CalendarEvent] {
        guard let sel = selectedDay else { return pendingEventsRaw }
        return pendingEventsRaw.filter { cal.component(.day, from: $0.date) == sel }
    }

    /// Ocurrencias futuras (> hoy) de recurrentes en el mes + deudas futuras.
    private var allMonthEvents: [CalendarEvent] {
        var out: [CalendarEvent] = []
        for ev in app.recurringEvents {
            for occ in occurrences(of: ev) where occ > todayStart {
                out.append(event(from: ev, on: occ))
            }
        }
        for debt in formattedDebts {
            if debt.date > todayStart
                && cal.component(.month, from: debt.date) == visibleMonth
                && cal.component(.year, from: debt.date) == visibleYear {
                out.append(debt)
            }
        }
        return out.sorted { $0.date < $1.date }
    }

    private var displayedEvents: [CalendarEvent] {
        guard let sel = selectedDay else { return allMonthEvents }
        return allMonthEvents.filter { cal.component(.day, from: $0.date) == sel }
    }

    /// Transacciones cuyo date cae en el mes visible.
    private var currentMonthTransactions: [Transaction] {
        app.transactions.filter { tx in
            guard let d = CalendarModel.parseLocalDate(tx.date) else { return false }
            return cal.component(.month, from: d) == visibleMonth
                && cal.component(.year, from: d) == visibleYear
        }
    }

    private var displayedTransactions: [Transaction] {
        guard let sel = selectedDay else { return currentMonthTransactions }
        return currentMonthTransactions.filter { tx in
            guard let d = CalendarModel.parseLocalDate(tx.date) else { return false }
            return cal.component(.day, from: d) == sel
        }
    }

    // MARK: - Badges por día del grid

    /// Devuelve hasta 5 badges combinando eventos proyectados + transacciones
    /// que caen ese día (paridad con renderLogos del original).
    private func badges(forDay day: Int) -> [CalendarBadge] {
        var items: [CalendarBadge] = []
        for ev in displayedEvents where cal.component(.day, from: ev.date) == day {
            items.append(CalendarBadge(
                id: "e-\(ev.id)-\(day)",
                logoSlug: ev.logoSlug,
                categoryColor: ev.category.map { CalendarVisual.color(for: $0) },
                categoryIcon: ev.category.map { CalendarVisual.symbol(for: $0) }
            ))
        }
        for tx in currentMonthTransactions {
            guard let d = CalendarModel.parseLocalDate(tx.date),
                  cal.component(.day, from: d) == day else { continue }
            let category = app.category(for: tx.categoryId)
            items.append(CalendarBadge(
                id: "t-\(tx.id)",
                logoSlug: CalendarVisual.logoSlug(forName: tx.description) ?? CalendarVisual.logoSlug(forName: category?.name),
                categoryColor: category.map { CalendarVisual.color(for: $0) },
                categoryIcon: category.map { CalendarVisual.symbol(for: $0) }
            ))
        }
        return items
    }

    // MARK: - Construcción de CalendarEvent desde RecurringEvent

    private func event(from ev: RecurringEvent, on date: Date) -> CalendarEvent {
        let category = app.category(for: ev.categoryId)
        return CalendarEvent(
            id: ev.id,
            name: ev.name,
            amount: ev.amount,
            isIncome: false,  // recurrentes son gastos en el original
            date: date,
            frequencyLabel: ev.frequency.label,
            category: category,
            logoSlug: CalendarVisual.logoSlug(forName: ev.name),
            isDebt: false,
            targetId: ev.id
        )
    }

    // MARK: - Miembros (para inicial del creador)

    private func loadMembers() async {
        guard memberNames.isEmpty, let hh = app.household?.id else { return }
        do {
            let rows: [CalendarMemberRow] = try await SupabaseClient.shared.from(
                "profiles",
                query: ["household_id": "eq.\(hh)", "select": "id,name"]
            )
            var map: [String: String] = [:]
            for r in rows { map[r.id] = r.name }
            memberNames = map
        } catch {
            // Silencioso: si falla, se usa "Usuario" como fallback.
        }
    }
}

// MARK: - Fila de datos de miembro

private struct CalendarMemberRow: Decodable {
    let id: String
    let name: String
}

// MARK: - Modelo de evento del calendario (privado del feature)

private struct CalendarEvent: Identifiable {
    let id: String
    let name: String
    let amount: Double
    let isIncome: Bool
    let date: Date
    let frequencyLabel: String?
    let category: Category?
    let logoSlug: String?
    let isDebt: Bool
    let targetId: String
}

private struct CalendarBadge: Identifiable {
    let id: String
    let logoSlug: String?
    let categoryColor: Color?
    let categoryIcon: String?
}

// MARK: - Header de mes con navegación

private struct CalendarMonthHeader: View {
    let title: String
    let onPrev: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(Typo.title)
                .foregroundStyle(Palette.ink)
            Spacer()
            HStack(spacing: Space.s) {
                CalendarNavButton(icon: "chevron.left", action: onPrev)
                CalendarNavButton(icon: "chevron.right", action: onNext)
            }
        }
    }
}

private struct CalendarNavButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 36, height: 36)
                .background(Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))
        }
        .pressable()
    }
}

// MARK: - Celda de día

private struct CalendarDayCell: View {
    let day: Int
    let isToday: Bool
    let isSelected: Bool
    let badges: [CalendarBadge]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Space.xs) {
                Text("\(day)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? Palette.accent : Palette.ink)
                    .padding(.top, Space.s)

                CalendarBadgeStack(badges: badges)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: CalendarModel.cellHeight)
            .background(background)
            .overlay(border)
            .contentShape(RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
        }
        .pressable(scale: 0.95)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
            .fill(isToday ? Palette.accent.opacity(0.18) : Palette.surface)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
            .strokeBorder(
                isToday ? Palette.accent : (isSelected ? Palette.ink : Palette.stroke),
                lineWidth: (isToday || isSelected) ? 1.5 : 1
            )
    }
}

// MARK: - Stack de badges (logos/íconos) dentro de una celda

private struct CalendarBadgeStack: View {
    let badges: [CalendarBadge]

    var body: some View {
        if badges.isEmpty {
            Color.clear.frame(height: 0)
        } else if badges.count <= 2 {
            VStack(spacing: 2) {
                ForEach(badges.prefix(2)) { CalendarBadgeView(badge: $0) }
            }
        } else {
            let showPlus = badges.count > 4
            let shown = Array(badges.prefix(showPlus ? 3 : 4))
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    ForEach(shown.prefix(2)) { CalendarBadgeView(badge: $0) }
                }
                HStack(spacing: 2) {
                    ForEach(shown.dropFirst(2)) { CalendarBadgeView(badge: $0) }
                    if showPlus {
                        CalendarPlusBadge(count: badges.count - 3)
                    }
                }
            }
        }
    }
}

private struct CalendarBadgeView: View {
    let badge: CalendarBadge
    private let size: CGFloat = 18

    var body: some View {
        ZStack {
            if let logo = SubscriptionLogo.image(for: badge.logoSlug) {
                Circle().fill(Color.white)
                logo
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.7, height: size * 0.7)
                    .clipShape(Circle())
            } else if let icon = badge.categoryIcon {
                Circle().fill(badge.categoryColor ?? Palette.surfaceElevated)
                Image(systemName: icon)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(Palette.bg)
            } else {
                Circle().fill(Palette.inkTertiary)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct CalendarPlusBadge: View {
    let count: Int
    private let size: CGFloat = 18

    var body: some View {
        Text("+\(count)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(Palette.ink)
            .frame(width: size, height: size)
            .background(Palette.surfaceElevated, in: Circle())
    }
}

// MARK: - Header de sección con contador

private struct CalendarSectionHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(title)
                .font(Typo.headline)
                .foregroundStyle(Palette.ink)
            Spacer()
            Text("\(count)")
                .font(Typo.callout)
                .monospacedDigit()
                .foregroundStyle(Palette.inkSecondary)
        }
    }
}

// MARK: - Lista de eventos (pendientes / próximos)

private struct CalendarEventList: View {
    let events: [CalendarEvent]
    let emptyText: String
    let currency: String
    let pending: Bool

    var body: some View {
        if events.isEmpty {
            CalendarEmptyRow(text: emptyText)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, ev in
                    CalendarEventRow(event: ev, currency: currency, pending: pending)
                    if index < events.count - 1 {
                        Divider().overlay(Palette.stroke)
                            .padding(.leading, 40 + Space.m + Space.l)
                    }
                }
            }
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
        }
    }
}

private struct CalendarEventRow: View {
    let event: CalendarEvent
    let currency: String
    let pending: Bool

    var body: some View {
        HStack(spacing: Space.m) {
            iconBox

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Typo.subhead)
                    .foregroundStyle(pending ? Palette.amber : Palette.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s)

            AmountText(
                amount: event.isIncome ? event.amount : -event.amount,
                currency: currency,
                font: Typo.amount,
                signed: true,
                tintBySign: true
            )
        }
        .padding(Space.l)
    }

    @ViewBuilder private var iconBox: some View {
        let bg = event.category.map { CalendarVisual.color(for: $0) } ?? Palette.surfaceElevated
        ZStack {
            if let logo = SubscriptionLogo.image(for: event.logoSlug) {
                Circle().fill(Color.white)
                logo
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
            } else if let cat = event.category {
                Circle().fill(bg)
                Image(systemName: CalendarVisual.symbol(for: cat))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.bg)
            } else {
                Circle().fill(Palette.surfaceElevated)
                Image(systemName: "calendar")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .frame(width: 40, height: 40)
    }

    private var subtitle: String {
        let dateText = CalendarModel.relativeDateText(event.date)
        var parts = [dateText]
        if let freq = event.frequencyLabel { parts.append(freq) }
        if pending { parts.append("Pendiente") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Lista de movimientos

private struct CalendarTransactionList: View {
    @Environment(AppState.self) private var app
    let transactions: [Transaction]
    let memberNames: [String: String]
    let emptyText: String
    let currency: String

    var body: some View {
        if transactions.isEmpty {
            CalendarEmptyRow(text: emptyText)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(transactions.enumerated()), id: \.element.id) { index, tx in
                    CalendarTransactionRow(
                        transaction: tx,
                        creatorName: memberNames[tx.createdBy] ?? "Usuario",
                        category: app.category(for: tx.categoryId),
                        currency: currency
                    )
                    if index < transactions.count - 1 {
                        Divider().overlay(Palette.stroke)
                            .padding(.leading, 40 + Space.m + Space.l)
                    }
                }
            }
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
        }
    }
}

private struct CalendarTransactionRow: View {
    let transaction: Transaction
    let creatorName: String
    let category: Category?
    let currency: String

    var body: some View {
        HStack(spacing: Space.m) {
            Text(initial)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .frame(width: 40, height: 40)
                .background(Palette.surfaceElevated, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.s)

            AmountText(
                amount: transaction.type == .income ? transaction.amount : -transaction.amount,
                currency: currency,
                font: Typo.amount,
                signed: true,
                tintBySign: true
            )
        }
        .padding(Space.l)
    }

    private var initial: String {
        String(creatorName.prefix(1)).uppercased()
    }

    private var title: String {
        if let desc = transaction.description, !desc.isEmpty { return desc }
        if let name = category?.name { return name }
        return "Movimiento"
    }

    private var subtitle: String {
        let dateText = CalendarModel.relativeDateText(CalendarModel.parseLocalDate(transaction.date) ?? Date())
        return "\(dateText) · \(creatorName)"
    }
}

// MARK: - Fila de estado vacío

private struct CalendarEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typo.subhead)
            .foregroundStyle(Palette.inkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.xl)
    }
}

// MARK: - Modelo/helpers de fecha del calendario (privado del feature)

private enum CalendarModel {
    static let cellHeight: CGFloat = 72

    static let weekdays = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]

    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_CO")
        c.timeZone = TimeZone.current
        c.firstWeekday = 1  // domingo, para alinear con weekdays Dom..Sáb
        return c
    }()

    static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.dateFormat = "d MMM"
        return f
    }()

    /// Parsea "yyyy-MM-dd" (o ISO con tiempo) como fecha local a medianoche,
    /// tomando solo la parte de fecha — igual que parseLocalDate del original.
    static func parseLocalDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let datePart = String(string.split(separator: "T").first ?? "")
        let comps = datePart.split(separator: "-")
        guard comps.count == 3,
              let y = Int(comps[0]), let m = Int(comps[1]), let d = Int(comps[2]) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: d))
    }

    /// "Hoy" / "Mañana" / "Ayer" / "12 sep" — paridad con getRelativeDateText.
    static func relativeDateText(_ date: Date) -> String {
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        switch days {
        case 0: return "Hoy"
        case 1: return "Mañana"
        case -1: return "Ayer"
        default:
            let text = shortDateFormatter.string(from: date)
            return text.prefix(1).uppercased() + text.dropFirst()
        }
    }
}

// MARK: - Resolución de color/ícono/logo (privado del feature)

private enum CalendarVisual {
    /// Color de la categoría desde su hex, o la rueda de acentos.
    static func color(for category: Category) -> Color {
        if let parsed = Color(hexString: category.color) { return parsed }
        return Palette.categoryColor(for: abs(category.id.hashValue))
    }

    /// SF Symbol de la categoría: usa su icon si ya es SF, si no lo mapea.
    static func symbol(for category: Category) -> String {
        if isLikelySFSymbol(category.icon) { return category.icon }
        return IconMapping.sfSymbol(for: category.icon.isEmpty ? category.name : category.icon)
    }

    /// Busca un logo de suscripción por nombre (match exacto contra los slugs).
    static func logoSlug(forName name: String?) -> String? {
        guard let raw = name?.folding(options: .diacriticInsensitive, locale: .current).lowercased(),
              !raw.isEmpty else { return nil }
        // Normaliza a slug con guiones para comparar contra SubscriptionLogo.all.
        let slug = raw.replacingOccurrences(of: " ", with: "-")
        if SubscriptionLogo.all.contains(slug) { return slug }
        // Match parcial: algún slug cuyo nombre base coincida con el título.
        for candidate in SubscriptionLogo.all {
            let base = candidate.replacingOccurrences(of: "-", with: "")
            let cleaned = raw.replacingOccurrences(of: " ", with: "")
            if base == cleaned { return candidate }
        }
        return nil
    }

    private static func isLikelySFSymbol(_ raw: String) -> Bool {
        guard !raw.isEmpty else { return false }
        return raw.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == ".") }
            && raw.contains(where: { $0.isLetter })
    }
}
