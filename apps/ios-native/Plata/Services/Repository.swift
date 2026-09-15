import Foundation

// Acceso a datos sobre SupabaseClient. Cada método es una operación de dominio.
// Los ajustes de saldo pasan por RPC atómicas (apply_account_delta), igual que
// la app RN tras la auditoría; nunca read-modify-write desde el cliente.

struct Repository {
    private let client = SupabaseClient.shared

    // MARK: Perfil y hogar

    func fetchProfile(userId: String) async throws -> Profile? {
        let rows: [Profile] = try await client.from("profiles", query: [
            "id": "eq.\(userId)",
            "select": "*",
        ])
        return rows.first
    }

    func fetchHousehold(id: String) async throws -> Household? {
        let rows: [Household] = try await client.from("households", query: [
            "id": "eq.\(id)",
            "select": "*",
        ])
        return rows.first
    }

    func createHousehold(name: String) async throws -> Household {
        try await client.rpc("create_household", params: ["p_name": name])
    }

    func joinHousehold(code: String) async throws -> Household {
        try await client.rpc("join_household", params: ["p_code": code])
    }

    // MARK: Colecciones del hogar

    func fetchAccounts(household: String) async throws -> [Account] {
        try await client.from("accounts", query: [
            "household_id": "eq.\(household)", "select": "*", "order": "name",
        ])
    }

    func fetchTransactions(household: String) async throws -> [Transaction] {
        try await client.from("transactions", query: [
            "household_id": "eq.\(household)", "select": "*",
            "order": "date.desc", "limit": "200",
        ])
    }

    func fetchCategories(household: String) async throws -> [Category] {
        try await client.from("categories", query: [
            "household_id": "eq.\(household)", "select": "*",
        ])
    }

    func fetchBudgets(household: String) async throws -> [Budget] {
        try await client.from("budgets", query: [
            "household_id": "eq.\(household)", "select": "*",
        ])
    }

    func fetchDebts(household: String) async throws -> [Debt] {
        try await client.from("debts", query: [
            "household_id": "eq.\(household)", "select": "*", "order": "status",
        ])
    }

    func fetchGoals(household: String) async throws -> [SavingsGoal] {
        try await client.from("savings_goals", query: [
            "household_id": "eq.\(household)", "select": "*",
        ])
    }

    func fetchShoppingLists(household: String) async throws -> [ShoppingList] {
        try await client.from("shopping_lists", query: [
            "household_id": "eq.\(household)", "select": "*", "order": "date.desc",
        ])
    }

    func fetchShoppingItems(list: String) async throws -> [ShoppingItem] {
        try await client.from("shopping_items", query: [
            "list_id": "eq.\(list)", "select": "*",
        ])
    }

    func fetchMembers(household: String) async throws -> [Profile] {
        try await client.from("profiles", query: [
            "household_id": "eq.\(household)", "select": "id,name,avatar_url,currency,household_id",
        ])
    }

    func fetchRecurring(household: String) async throws -> [RecurringEvent] {
        try await client.from("recurring_events", query: [
            "household_id": "eq.\(household)", "select": "*",
            "is_active": "eq.true", "order": "next_date",
        ])
    }

    // MARK: Mutaciones

    /// Crea una transacción y ajusta el saldo de la cuenta atómicamente vía RPC.
    func addTransaction(_ payload: NewTransaction, householdId: String, userId: String) async throws {
        struct Insert: Encodable {
            let account_id: String
            let household_id: String
            let created_by: String
            let amount: Double
            let type: String
            let category_id: String?
            let description: String?
            let date: String
        }
        let insert = Insert(
            account_id: payload.accountId,
            household_id: householdId,
            created_by: userId,
            amount: payload.amount,
            type: payload.type.rawValue,
            category_id: payload.categoryId,
            description: payload.description,
            date: payload.date
        )
        let _: [Transaction] = try await client.insert("transactions", values: insert)

        // Ajuste de saldo atómico (RPC apply_account_delta).
        let delta = payload.type == .income ? payload.amount : -payload.amount
        if payload.type != .transfer {
            let _: EmptyResponse = try await client.rpc("apply_account_delta", params: [
                "p_account_id": payload.accountId,
                "p_delta": delta,
            ])
        }
    }

    func addContribution(goalId: String, accountId: String, amount: Double, userId: String) async throws {
        struct Insert: Encodable {
            let goal_id: String
            let created_by: String
            let amount: Double
            let date: String
        }
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        let _: [EmptyDecodable] = try await client.insert("savings_contributions", values:
            Insert(goal_id: goalId, created_by: userId, amount: amount, date: today))
        let _: EmptyResponse = try await client.rpc("apply_account_delta", params: [
            "p_account_id": accountId, "p_delta": -amount,
        ])
    }
}

struct NewTransaction {
    var accountId: String
    var amount: Double
    var type: TransactionType
    var categoryId: String?
    var description: String?
    var date: String
}

struct EmptyDecodable: Decodable {}
