import SwiftUI

// Calendario mensual de Plata — paridad con app/(tabs)/calendar.tsx de la app RN.
//
// Rediseño FLAT (sin cards): grid de días del mes arriba (sobre fondo plano, no
// card), y debajo tres secciones planas separadas por hairlines —"Pagos
// pendientes", "Próximos pagos" y "Movimientos"— con el mismo lenguaje del
// Dashboard (PlainSection + PlainList + PlainRow + RowLeadingIcon). Al
// seleccionar un día, las tres listas se filtran a ese día.
//
// Los "próximos pagos" son ocurrencias de recurrentes proyectadas dentro del mes
// visible (getOccurrencesInMonth con guard de seguridad, idéntico al original)
// más las deudas con dueDate futuras. Los "pendientes" son recurrentes/deudas
// cuya fecha ya venció (<= hoy). Los movimientos son transacciones cuya date cae
// en el mes/día.
//
// Todo el estado de datos viene de AppState (app.recurringEvents, app.debts,
// app.transactions, app.categories). El creador de cada movimiento se resuelve
// con app.member(for: tx.createdBy) — miembro REAL, sin fallback a "Usuario".

struct CalendarView: View {
    @Environment(AppState.self) private var app

    @State private var currentDate = Date()
    @State private var selectedDay: Int? = nil

    // Long-press en un movimiento → editar (reutiliza la pantalla de alta), igual
    // que el Dashboard.
    @State private var editTarget: Transaction?

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

                        // Grid del mes: vive directamente sobre el fondo (sin card).
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
                }
                .floatingTabBarInset()
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            // Chrome translúcido: el grid se ve pasar por debajo al hacer scroll
            // (Apple §12), en vez de una barra opaca que corta la composición.
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(item: $editTarget) { tx in
                // Edición real: reutiliza la pantalla de alta en modo edición.
                AddTransactionView(editing: tx)
            }
        }
        .tint(Palette.accent)
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

    // MARK: - Sección: pagos pendientes (plana)

    @ViewBuilder
    private var pendingSection: some View {
        if !pendingEventsRaw.isEmpty {
            PlainSection(title: nil) {
                CalendarSectionHeader(
                    title: "Pagos pendientes",
                    count: pendingEvents.count,
                    tint: Palette.amber
                )
                if pendingEvents.isEmpty {
                    CalendarEmptyRow(text: "Sin pagos pendientes en \(scopeWord)")
                } else {
                    PlainList(pendingEvents, dividerInset: 40 + Space.m) { ev in
                        CalendarEventRow(event: ev, currency: app.currency, pending: true)
                    }
                }
            }
        }
    }

    // MARK: - Sección: próximos pagos (plana)

    private var upcomingSection: some View {
        PlainSection(title: nil) {
            CalendarSectionHeader(
                title: "Próximos pagos",
                count: displayedEvents.count,
                tint: Palette.orange
            )
            if displayedEvents.isEmpty {
                CalendarEmptyRow(text: "Sin pagos en \(scopeWord)")
            } else {
                PlainList(displayedEvents, dividerInset: 40 + Space.m) { ev in
                    CalendarEventRow(event: ev, currency: app.currency, pending: false)
                }
            }
        }
    }

    // MARK: - Sección: movimientos (plana)

    private var transactionsSection: some View {
        PlainSection(title: nil) {
            CalendarSectionHeader(
                title: "Movimientos",
                count: displayedTransactions.count,
                tint: Palette.sky
            )
            if displayedTransactions.isEmpty {
                CalendarEmptyRow(text: "Sin movimientos en \(scopeWord)")
            } else {
                PlainList(displayedTransactions, dividerInset: 40 + Space.m) { tx in
                    NavigationLink {
                        TransactionDetailView(transaction: tx)
                    } label: {
                        CalendarTransactionRow(
                            transaction: tx,
                            creatorName: app.member(for: tx.createdBy)?.name,
                            category: app.category(for: tx.categoryId),
                            currency: app.currency
                        )
                    }
                    .buttonStyle(.plain)
                    .pressable()
                    .contextMenu {
                        Button {
                            editTarget = tx
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                    }
                }
            }
        }
    }

    /// Palabra de alcance para los estados vacíos: día vs. mes.
    private var scopeWord: String { selectedDay != nil ? "este día" : "este mes" }

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
            logoSlug: SubscriptionLogo.slug(forStoredId: ev.logoId) ?? CalendarVisual.logoSlug(forName: ev.name),
            isDebt: false,
            targetId: ev.id
        )
    }
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
                .tracking(-0.4)  // título grande: tracking negativo sutil
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            Spacer()
            // Dos botones glass juntos → GlassGroup los fusiona (morphing en iOS 26).
            GlassGroup(spacing: Space.s) {
                HStack(spacing: Space.s) {
                    CalendarNavButton(icon: "chevron.left", action: onPrev)
                    CalendarNavButton(icon: "chevron.right", action: onNext)
                }
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
                // Botón de chrome flotante → Liquid Glass (cápsula cuadrada = círculo)
                // con borde luminoso superior tenue.
                .liquidGlassCapsule(interactive: true)
                .overlay(Circle().strokeBorder(Palette.stroke.opacity(0.5), lineWidth: 0.5))
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
                    // Sobre el glass del día seleccionado, un pelo más de peso
                    // para sostener el contraste (rule: texto sobre glass más fuerte).
                    .font(.system(size: 14, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
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

    private var numberColor: Color {
        // Sobre el glass teñido de acento el número necesita contraste: ink, no
        // accent-sobre-accent. Hoy (sin seleccionar) sí resalta en accent.
        if isSelected { return Palette.ink }
        return isToday ? Palette.accent : Palette.ink
    }

    // El día seleccionado se resalta con glass teñido de acento (sobre el fondo,
    // no dentro de una Card → sin glass sobre glass). Hoy usa una capa de acento
    // muy sutil; el resto, la superficie sólida base.
    @ViewBuilder private var background: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
        if isSelected {
            Color.clear.liquidGlassTinted(Palette.accent, cornerRadius: Radius.s, interactive: false)
        } else {
            shape.fill(isToday ? Palette.accent.opacity(0.12) : Palette.surface)
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
            .strokeBorder(
                isSelected ? Palette.accent.opacity(0.8)
                    : (isToday ? Palette.accent.opacity(0.55) : Palette.stroke),
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

// MARK: - Header de sección plano con contador

/// Header de una sección plana del calendario: overline en mayúsculas (como el
/// resto de la app) + chip contador teñido. Sin card — se apoya en el fondo.
private struct CalendarSectionHeader: View {
    let title: String
    let count: Int
    let tint: Color

    var body: some View {
        HStack(spacing: Space.s) {
            Text(title.uppercased())
                .font(Typo.overline)
                .tracking(0.8)
                .foregroundStyle(Palette.inkTertiary)
            Spacer()
            // Contador como chip sutil teñido (material ligero, sobre el fondo).
            Text("\(count)")
                .font(Typo.caption)
                .monospacedDigit()
                .foregroundStyle(tint)
                .frame(minWidth: 22)
                .padding(.horizontal, Space.s)
                .padding(.vertical, 3)
                .background(tint.opacity(0.14), in: Capsule())
                .overlay(Capsule().strokeBorder(tint.opacity(0.24), lineWidth: 0.5))
        }
        .padding(.bottom, Space.xs)
    }
}

// MARK: - Fila de evento (pendientes / próximos) — plana

private struct CalendarEventRow: View {
    let event: CalendarEvent
    let currency: String
    let pending: Bool

    var body: some View {
        PlainRow(
            leading: {
                RowLeadingIcon(
                    logo: logo,
                    categoryIcon: CategoryIconAsset.image(forSlug: event.category?.icon),
                    systemName: iconName,
                    color: tint,
                    size: 40
                )
            },
            title: event.name,
            subtitle: subtitle,
            trailing: {
                AmountText(
                    amount: event.isIncome ? event.amount : -event.amount,
                    currency: currency,
                    font: Typo.amount,
                    signed: true,
                    tintBySign: true
                )
                .lineLimit(1)
            }
        )
    }

    private var logo: Image? {
        SubscriptionLogo.image(for: event.logoSlug)
    }

    private var tint: Color {
        event.category.map { CalendarVisual.color(for: $0) } ?? (event.isDebt ? Palette.amber : Palette.sky)
    }

    private var iconName: String {
        if let cat = event.category { return CalendarVisual.symbol(for: cat) }
        return event.isDebt ? "banknote.fill" : "calendar"
    }

    private var subtitle: String {
        let dateText = CalendarModel.relativeDateText(event.date)
        var parts = [dateText]
        if let freq = event.frequencyLabel { parts.append(freq) }
        if pending { parts.append("Pendiente") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Fila de movimiento — plana, con miembro real

private struct CalendarTransactionRow: View {
    let transaction: Transaction
    /// Nombre real del creador (app.member(for:)?.name). Nil si no se resuelve.
    let creatorName: String?
    let category: Category?
    let currency: String

    var body: some View {
        PlainRow(
            leading: {
                RowLeadingIcon(
                    logo: logo,
                    categoryIcon: CategoryIconAsset.image(forSlug: category?.icon),
                    systemName: iconName,
                    color: tint,
                    size: 40
                )
            },
            title: title,
            subtitle: subtitle,
            trailing: {
                AmountText(
                    amount: signedAmount,
                    currency: currency,
                    font: Typo.amount,
                    signed: true,
                    tintBySign: true
                )
                .lineLimit(1)
            }
        )
    }

    /// Logo de app si la descripción coincide con una suscripción conocida.
    private var logo: Image? {
        SubscriptionLogo.image(for: CalendarVisual.logoSlug(forName: transaction.description))
    }

    /// Ingreso positivo, gasto/transferencia negativo — coherente con el color por signo.
    private var signedAmount: Double {
        transaction.type == .income ? abs(transaction.amount) : -abs(transaction.amount)
    }

    private var title: String {
        if let desc = transaction.description, !desc.isEmpty { return desc }
        if let name = category?.name, !name.isEmpty { return name }
        return transaction.type.label
    }

    /// Subtítulo: fecha relativa + creador REAL (o categoría si no hay creador).
    private var subtitle: String {
        let dateText = CalendarModel.relativeDateText(CalendarModel.parseLocalDate(transaction.date) ?? Date())
        if let creator = creatorName, !creator.isEmpty {
            return "\(dateText) · \(creator)"
        }
        if let name = category?.name, !name.isEmpty, name != title {
            return "\(dateText) · \(name)"
        }
        return dateText
    }

    private var tint: Color {
        if let category { return CalendarVisual.color(for: category) }
        switch transaction.type {
        case .income: return Palette.green
        case .expense: return Palette.pink
        case .transfer: return Palette.sky
        }
    }

    private var iconName: String {
        if let category { return CalendarVisual.symbol(for: category) }
        switch transaction.type {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Fila de estado vacío (plana, amable)

private struct CalendarEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typo.subhead)
            .foregroundStyle(Palette.inkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.l)
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
