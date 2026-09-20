import SwiftUI
import Observation

// Estado global de la app. @Observable (no ObservableObject) y aislado al main
// actor por defecto — la UI reacciona a sus cambios. La lógica de red vive en
// Repository; aquí solo se guarda estado y se orquesta.

enum AuthPhase: Equatable {
    case loading          // comprobando sesión guardada
    case onboarding       // primer uso, sin sesión
    case unauthenticated  // sin sesión, ya vio onboarding
    case noHousehold      // autenticado pero sin hogar
    case ready            // autenticado con hogar
}

@Observable
@MainActor
final class AppState {
    var phase: AuthPhase = .loading
    var user: AuthUser?
    var profile: Profile?
    var household: Household?

    // Datos del hogar (cache en memoria; se refrescan bajo demanda).
    var accounts: [Account] = []
    var transactions: [Transaction] = []
    var categories: [Category] = []
    var budgets: [Budget] = []
    var debts: [Debt] = []
    var goals: [SavingsGoal] = []
    var shoppingLists: [ShoppingList] = []
    var recurringEvents: [RecurringEvent] = []
    var members: [Profile] = []   // miembros del hogar (para resolver created_by)
    var settlements: [Settlement] = []   // liquidaciones ya hechas entre la pareja

    var errorMessage: String?

    private let repo = Repository()
    private let realtime = RealtimeService()
    private var realtimeStarted = false

    /// Suscribe a cambios en tiempo real del hogar → refresca solo. Idempotente.
    func startRealtime() {
        guard !realtimeStarted, let hh = household?.id,
              let token = SupabaseClient.shared.accessToken else { return }
        realtimeStarted = true
        realtime.start(householdId: hh, accessToken: token) { [weak self] in
            Task { await self?.refreshAll() }
        }
    }

    // MARK: Arranque

    func bootstrap() async {
        guard let session = TokenStore.load() else {
            phase = OnboardingFlag.hasSeen ? .unauthenticated : .onboarding
            return
        }
        SupabaseClient.shared.accessToken = session.accessToken
        user = session.user
        await loadProfileAndData()
    }

    func loadProfileAndData() async {
        do {
            guard let uid = user?.id ?? SupabaseClient.shared.currentUserId else {
                phase = .unauthenticated
                return
            }
            let profile = try await repo.fetchProfile(userId: uid)
            self.profile = profile
            guard let hh = profile?.householdId else {
                phase = .noHousehold
                return
            }
            self.household = try await repo.fetchHousehold(id: hh)
            // Mostrar la app ya (las vistas manejan listas vacías); los datos del
            // hogar se cargan en segundo plano para que el arranque no se congele.
            phase = .ready
            Task {
                await refreshAll()
                await uploadPendingOnboarding(userId: uid)
            }
        } catch is SessionExpiredError {
            // El token caducó y no se pudo refrescar: limpiar sesión y volver a
            // login con un mensaje claro (no el JSON crudo de PostgREST).
            SupabaseClient.shared.signOut()
            profile = nil; household = nil
            errorMessage = "Tu sesión expiró. Vuelve a iniciar sesión."
            phase = .unauthenticated
        } catch {
            errorMessage = "No pudimos cargar tus datos. Revisa tu conexión e inténtalo de nuevo."
            phase = .unauthenticated
        }
    }

    // MARK: Auth

    func signIn(email: String, password: String) async {
        do {
            let session = try await SupabaseClient.shared.signIn(email: email, password: password)
            user = session.user
            await loadProfileAndData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String, name: String) async {
        do {
            let session = try await SupabaseClient.shared.signUp(email: email, password: password, name: name)
            user = session.user
            await loadProfileAndData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        SupabaseClient.shared.signOut()
        OfflineCache.clear()   // no dejar datos del usuario anterior en disco
        profile = nil; household = nil
        accounts = []; transactions = []; categories = []
        phase = .unauthenticated
    }

    // MARK: Hogar (RPC seguras)

    func createHousehold(name: String) async {
        do {
            household = try await repo.createHousehold(name: name)
            await loadProfileAndData()
        } catch { errorMessage = error.localizedDescription }
    }

    func joinHousehold(code: String) async {
        do {
            household = try await repo.joinHousehold(code: code)
            await loadProfileAndData()
        } catch { errorMessage = error.localizedDescription }
    }

    /// Cambia el nombre del hogar: estado al instante + persiste en la BD.
    func setHouseholdName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let hh = household?.id else { return }
        household?.name = trimmed
        do {
            try await repo.updateHouseholdName(householdId: hh, name: trimmed)
        } catch { errorMessage = error.localizedDescription }
    }

    /// Regenera el código de invitación del hogar y actualiza el estado.
    func regenerateInviteCode() async {
        guard let hh = household?.id else { return }
        do {
            let newCode = try await repo.regenerateInviteCode(householdId: hh)
            household?.inviteCode = newCode
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Eliminación de entidades

    func deleteAccount(id: String) async {
        do { try await repo.deleteAccount(id: id); await refreshAll() }
        catch { errorMessage = error.localizedDescription }
    }
    func deleteDebt(id: String) async {
        do { try await repo.deleteDebt(id: id); await refreshAll() }
        catch { errorMessage = error.localizedDescription }
    }
    func deleteGoal(id: String) async {
        do { try await repo.deleteGoal(id: id); await refreshAll() }
        catch { errorMessage = error.localizedDescription }
    }
    func deleteBudget(id: String) async {
        do { try await repo.deleteBudget(id: id); await refreshAll() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: Listas de compra

    /// Edita nombre + presupuesto de una lista y refresca el estado.
    func shoppingListUpdate(id: String, name: String, estimatedTotal: Double?) async {
        do {
            try await repo.shoppingListUpdate(id: id, name: name, estimatedTotal: estimatedTotal)
            await refreshAll()
        } catch { errorMessage = error.localizedDescription }
    }

    /// Elimina una lista (los ítems caen por cascade) y refresca.
    func shoppingListDelete(id: String) async {
        do { try await repo.shoppingListDelete(id: id); await refreshAll() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: Onboarding

    /// Sube al perfil las respuestas del cuestionario guardadas localmente antes
    /// de crear la cuenta (si las hay) y limpia el pendiente.
    private func uploadPendingOnboarding(userId: String) async {
        guard let survey = OnboardingSurveyStore.loadPending() else { return }
        do {
            try await repo.saveOnboarding(userId: userId, survey: survey)
            OnboardingSurveyStore.clearPending()
        } catch {
            // Si falla, se reintenta en el próximo arranque (no se limpia).
        }
    }

    // MARK: Preferencias

    /// Cambia la moneda: actualiza el estado al instante y persiste en la BD.
    func setCurrency(_ code: String) async {
        profile?.currency = code
        guard let uid = profile?.id else { return }
        try? await repo.updateCurrency(userId: uid, currency: code)
    }

    // MARK: Datos

    /// Guarda la última foto buena en disco (para arranque offline).
    private func persistCache() {
        OfflineCache.save(accounts, as: "accounts")
        OfflineCache.save(transactions, as: "transactions")
        OfflineCache.save(categories, as: "categories")
        OfflineCache.save(budgets, as: "budgets")
        OfflineCache.save(debts, as: "debts")
        OfflineCache.save(goals, as: "goals")
        OfflineCache.save(shoppingLists, as: "shoppingLists")
        OfflineCache.save(recurringEvents, as: "recurring")
        OfflineCache.save(members, as: "members")
        OfflineCache.save(settlements, as: "settlements")
    }

    /// Carga el cache en memoria (arranque offline / mientras llega la red).
    func loadCache() {
        accounts = OfflineCache.load([Account].self, from: "accounts") ?? accounts
        transactions = OfflineCache.load([Transaction].self, from: "transactions") ?? transactions
        categories = OfflineCache.load([Category].self, from: "categories") ?? categories
        budgets = OfflineCache.load([Budget].self, from: "budgets") ?? budgets
        debts = OfflineCache.load([Debt].self, from: "debts") ?? debts
        goals = OfflineCache.load([SavingsGoal].self, from: "goals") ?? goals
        shoppingLists = OfflineCache.load([ShoppingList].self, from: "shoppingLists") ?? shoppingLists
        recurringEvents = OfflineCache.load([RecurringEvent].self, from: "recurring") ?? recurringEvents
        members = OfflineCache.load([Profile].self, from: "members") ?? members
        settlements = OfflineCache.load([Settlement].self, from: "settlements") ?? settlements
    }

    func refreshAll() async {
        guard let hh = household?.id else { return }
        // Antes de leer, intenta subir lo que quedó encolado sin señal.
        await OfflineQueue.flush(repo: repo)
        async let accounts = repo.fetchAccounts(household: hh)
        async let transactions = repo.fetchTransactions(household: hh)
        async let categories = repo.fetchCategories(household: hh)
        async let budgets = repo.fetchBudgets(household: hh)
        async let debts = repo.fetchDebts(household: hh)
        async let goals = repo.fetchGoals(household: hh)
        async let lists = repo.fetchShoppingLists(household: hh)
        async let recurring = repo.fetchRecurring(household: hh)
        async let members = repo.fetchMembers(household: hh)
        async let settlements = repo.fetchSettlements(household: hh)
        self.accounts = (try? await accounts) ?? []
        self.transactions = (try? await transactions) ?? []
        // NOTA: la integración de banca (Syncfy) quedó deshabilitada — ver
        // BankService/ConnectBankView (código conservado para el futuro).
        self.categories = (try? await categories) ?? []
        self.budgets = (try? await budgets) ?? []
        self.debts = (try? await debts) ?? []
        self.goals = (try? await goals) ?? []
        self.shoppingLists = (try? await lists) ?? []
        self.recurringEvents = (try? await recurring) ?? []
        self.members = (try? await members) ?? []
        self.settlements = (try? await settlements) ?? []
        persistCache()
        // Reprograma recordatorios de pagos y revisa alertas de presupuesto.
        await NotificationService.syncReminders(app: self)
        await NotificationService.checkBudgets(app: self)
        // Suscripción en tiempo real (una vez): cambios del hogar → refresca solo.
        startRealtime()
    }

    // MARK: Derivados para la UI

    var totalBalance: Double { accounts.reduce(0) { $0 + $1.balance } }

    var currency: String { profile?.currency ?? "COP" }

    func category(for id: String?) -> Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    /// Perfil de un miembro del hogar por su id (para resolver created_by).
    func member(for id: String?) -> Profile? {
        guard let id else { return nil }
        if let p = members.first(where: { $0.id == id }) { return p }
        return profile?.id == id ? profile : nil
    }

    func account(for id: String?) -> Account? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }
    }

    /// Gasto e ingreso del mes en curso.
    var monthIncome: Double { monthSum(.income) }
    var monthExpense: Double { monthSum(.expense) }

    private func monthSum(_ type: TransactionType) -> Double {
        let prefix = String(ISO8601DateFormatter().string(from: Date()).prefix(7)) // YYYY-MM
        return transactions
            .filter { $0.type == type && $0.date.hasPrefix(prefix) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Proyección de gasto a fin de mes según el ritmo actual (gasto/día × días
    /// del mes). Devuelve nil los primeros días (muestra poco fiable).
    var projectedMonthExpense: Double? {
        let cal = Calendar.current
        let now = Date()
        let day = cal.component(.day, from: now)
        guard day >= 4 else { return nil }   // con <4 días la proyección es ruido
        guard let range = cal.range(of: .day, in: .month, for: now) else { return nil }
        let daysInMonth = range.count
        let perDay = monthExpense / Double(day)
        return perDay * Double(daysInMonth)
    }

    /// Liquidación de gastos COMPARTIDOS entre los 2 miembros del hogar.
    /// Cada gasto compartido lo paga quien lo registró; el otro le debe la mitad.
    /// Devuelve (nombre de quien debe, nombre de a quién, monto) o nil si están
    /// a mano, si no hay 2 miembros, o si no hay gastos compartidos.
    var settlement: (debtor: String, creditor: String, amount: Double)? {
        let two = members
        guard two.count == 2 else { return nil }
        let a = two[0].id, b = two[1].id
        // "aPagoDeMas" = cuánto puso A de más en gastos compartidos vs B.
        var netA = 0.0   // a favor de A (B le debe) si positivo
        for t in transactions where t.type == .expense && t.splitMode == .shared {
            let half = t.amount / 2
            if t.createdBy == a { netA += half }        // A pagó, B debe su mitad
            else if t.createdBy == b { netA -= half }   // B pagó, A debe su mitad
        }
        // Restar liquidaciones ya hechas: si B le pagó a A, baja lo que B debe.
        for s in settlements {
            if s.fromUser == b && s.toUser == a { netA -= s.amount }
            else if s.fromUser == a && s.toUser == b { netA += s.amount }
        }
        let amount = abs(netA)
        guard amount >= 1 else { return nil }
        let name: (String) -> String = { id in self.members.first { $0.id == id }?.name ?? "Tu pareja" }
        if netA > 0 { return (debtor: name(b), creditor: name(a), amount: amount) }
        else { return (debtor: name(a), creditor: name(b), amount: amount) }
    }

    /// Salda el saldo pendiente actual entre la pareja: registra una liquidación
    /// del deudor al acreedor por el monto pendiente y refresca.
    func settleUp() async {
        guard let hh = household?.id, let s = settlement, s.amount >= 1 else { return }
        let from = members.first { $0.name == s.debtor }?.id
        let to = members.first { $0.name == s.creditor }?.id
        guard let from, let to else { return }
        try? await repo.addSettlement(householdId: hh, from: from, to: to, amount: s.amount)
        await refreshAll()
    }

    /// Racha de días consecutivos (terminando hoy o ayer) con al menos un
    /// movimiento registrado. 0 si no hay racha activa.
    var registerStreak: Int {
        let cal = Calendar.current
        // Set de días (inicio de día) con movimientos.
        var days = Set<Date>()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        for t in transactions {
            if let d = f.date(from: String(t.date.prefix(10))) {
                days.insert(cal.startOfDay(for: d))
            }
        }
        guard !days.isEmpty else { return 0 }
        let today = cal.startOfDay(for: Date())
        // La racha cuenta si hubo registro hoy o ayer (no se rompe por el día en curso).
        var cursor = days.contains(today) ? today : cal.date(byAdding: .day, value: -1, to: today)!
        guard days.contains(cursor) else { return 0 }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }
}

// Flag de onboarding en UserDefaults (no es sensible).
enum OnboardingFlag {
    private static let key = "has_seen_onboarding"
    static var hasSeen: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

extension SupabaseClient {
    /// Extrae el user id del JWT actual (claim `sub`) sin llamar a la red.
    var currentUserId: String? {
        guard let token = accessToken else { return nil }
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        // base64url → base64
        payload = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        return sub
    }
}
