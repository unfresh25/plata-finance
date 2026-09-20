import Foundation
import UserNotifications

// Notificaciones LOCALES (no requieren servidor ni APNs):
//  - Recordatorios de pagos recurrentes y deudas con fecha de vencimiento.
//  - Alertas de presupuesto (al 80% / 100%) evaluadas al refrescar datos.
// Se reprograman cada vez que cambian los datos (borra las previas y reagenda).

@MainActor
enum NotificationService {
    private static let center = UNUserNotificationCenter.current()

    /// Pide permiso una vez (idempotente).
    static func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    private static func authorized() async -> Bool {
        let s = await center.notificationSettings()
        return s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }

    /// Reprograma TODOS los recordatorios de pagos a partir del estado actual.
    /// Se llama tras refreshAll. Cancela los previos para no duplicar.
    static func syncReminders(app: AppState) async {
        guard await authorized() else { return }
        // Quitar solo nuestras notificaciones de pagos (prefijo).
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("pay_") }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let cur = app.currency
        func money(_ v: Double) -> String { CurrencyFormatter.string(v, currency: cur) }

        // Recurrentes activos con próxima fecha.
        for ev in app.recurringEvents where ev.isActive {
            guard let date = Self.parseLocalDate(ev.nextDate) else { continue }
            await schedulePayment(id: "pay_rec_\(ev.id)",
                            title: "Pago próximo",
                            body: "Mañana: \(ev.name) · \(money(ev.amount))",
                            dueDate: date)
        }
        // Deudas activas con vencimiento.
        for d in app.debts where d.status == .active {
            guard let due = d.dueDate, let date = Self.parseLocalDate(due) else { continue }
            let quien = d.direction == .owedToUs ? "Te debe \(d.personName)" : "Le debes a \(d.personName)"
            await schedulePayment(id: "pay_debt_\(d.id)",
                            title: "Deuda por vencer",
                            body: "\(quien): \(money(d.remaining))",
                            dueDate: date)
        }
    }

    /// Notifica a las 9:00 del día ANTERIOR al vencimiento (si es futuro).
    private static func schedulePayment(id: String, title: String, body: String, dueDate: Date) async {
        let cal = Calendar.current
        guard let remindDay = cal.date(byAdding: .day, value: -1, to: dueDate) else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: remindDay)
        comps.hour = 9
        guard let fireDate = cal.date(from: comps), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour], from: fireDate),
            repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Alerta inmediata si algún presupuesto del mes cruzó 80% o 100%. Se llama
    /// tras registrar un gasto / refrescar. Usa una marca para no repetir el mismo
    /// umbral en la misma semana.
    static func checkBudgets(app: AppState) async {
        guard await authorized() else { return }
        let cur = app.currency
        func money(_ v: Double) -> String { CurrencyFormatter.string(v, currency: cur) }
        let monthPrefix = String(Self.todayISO().prefix(7))

        for b in app.budgets {
            var spent = 0.0
            for t in app.transactions where t.type == .expense
                && t.categoryId == b.categoryId && t.date.hasPrefix(monthPrefix) {
                spent += t.amount
            }
            guard b.amount > 0 else { continue }
            let ratio = spent / b.amount
            let catName = app.category(for: b.categoryId)?.name ?? "un presupuesto"
            let threshold: Int? = ratio >= 1 ? 100 : (ratio >= 0.8 ? 80 : nil)
            guard let th = threshold else { continue }

            let markKey = "budgetAlert_\(b.id)_\(monthPrefix)_\(th)"
            if UserDefaults.standard.bool(forKey: markKey) { continue }
            UserDefaults.standard.set(true, forKey: markKey)

            let content = UNMutableNotificationContent()
            content.title = th >= 100 ? "Presupuesto superado" : "Presupuesto al 80%"
            content.body = th >= 100
                ? "Se pasaron del presupuesto de \(catName): \(money(spent)) de \(money(b.amount))."
                : "Van \(money(spent)) de \(money(b.amount)) en \(catName)."
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: markKey, content: content, trigger: nil))
        }
    }

    // MARK: - Helpers de fecha

    private static func parseLocalDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(s.prefix(10)))
    }

    private static func todayISO() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
