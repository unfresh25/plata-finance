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

    var errorMessage: String?

    private let repo = Repository()

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
            await refreshAll()
            phase = .ready
        } catch {
            errorMessage = error.localizedDescription
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

    // MARK: Preferencias

    /// Cambia la moneda: actualiza el estado al instante y persiste en la BD.
    func setCurrency(_ code: String) async {
        profile?.currency = code
        guard let uid = profile?.id else { return }
        try? await repo.updateCurrency(userId: uid, currency: code)
    }

    // MARK: Datos

    func refreshAll() async {
        guard let hh = household?.id else { return }
        async let accounts = repo.fetchAccounts(household: hh)
        async let transactions = repo.fetchTransactions(household: hh)
        async let categories = repo.fetchCategories(household: hh)
        async let budgets = repo.fetchBudgets(household: hh)
        async let debts = repo.fetchDebts(household: hh)
        async let goals = repo.fetchGoals(household: hh)
        async let lists = repo.fetchShoppingLists(household: hh)
        async let recurring = repo.fetchRecurring(household: hh)
        async let members = repo.fetchMembers(household: hh)
        self.accounts = (try? await accounts) ?? []
        self.transactions = (try? await transactions) ?? []
        self.categories = (try? await categories) ?? []
        self.budgets = (try? await budgets) ?? []
        self.debts = (try? await debts) ?? []
        self.goals = (try? await goals) ?? []
        self.shoppingLists = (try? await lists) ?? []
        self.recurringEvents = (try? await recurring) ?? []
        self.members = (try? await members) ?? []
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
