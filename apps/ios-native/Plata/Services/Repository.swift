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

    /// Aporte (amount > 0) o retiro (amount < 0) a una meta. Además de registrar
    /// la contribución y mover el saldo de la cuenta, actualiza el
    /// `current_amount` de la meta y la marca `completed` si alcanza el objetivo
    /// (esto NO lo hacía antes → el anillo de progreso quedaba congelado).
    func addContribution(goal: SavingsGoal, accountId: String, amount: Double, userId: String) async throws {
        struct Insert: Encodable {
            let goal_id: String
            let created_by: String
            let amount: Double
            let date: String
        }
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        let _: [EmptyDecodable] = try await client.insert("savings_contributions", values:
            Insert(goal_id: goal.id, created_by: userId, amount: amount, date: today))

        // Mueve el saldo de la cuenta: aporte resta, retiro suma.
        let _: EmptyResponse = try await client.rpc("apply_account_delta", params: [
            "p_account_id": accountId, "p_delta": -amount,
        ])

        // Actualiza el progreso de la meta (clamp a [0, ∞)) y el estado.
        let newAmount = max(0, goal.currentAmount + amount)
        let isDone = newAmount >= goal.targetAmount
        struct GoalPatch: Encodable {
            let current_amount: Double
            let status: String
        }
        try await client.update("savings_goals", values: GoalPatch(
            current_amount: newAmount,
            status: isDone ? GoalStatus.completed.rawValue : GoalStatus.active.rawValue
        ), match: ["id": goal.id])
    }

    // MARK: - Deudas: abonos

    /// Historial de abonos de una deuda, más reciente primero.
    func fetchDebtPayments(debtId: String) async throws -> [DebtPayment] {
        try await client.from("debt_payments", query: [
            "debt_id": "eq.\(debtId)", "select": "*", "order": "date.desc",
        ])
    }

    /// Registra un abono a una deuda, replicando el flujo de la app RN:
    /// 1) inserta una transacción (income si "nos deben", expense si "debemos"),
    /// 2) ajusta el saldo de la cuenta vía RPC atómica,
    /// 3) inserta la fila en debt_payments (historial),
    /// 4) actualiza amount_paid y el status (paid si se cubre el total).
    func addDebtPayment(debt: Debt, accountId: String, amount: Double, userId: String) async throws {
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        let isIncome = debt.direction == .owedToUs

        // 1) Transacción del abono.
        struct TxInsert: Encodable {
            let household_id: String
            let account_id: String
            let debt_id: String
            let amount: Double
            let type: String
            let description: String
            let date: String
            let created_by: String
        }
        let desc = "Abono: \(debt.description?.isEmpty == false ? debt.description! : debt.personName)"
        let _: [Transaction] = try await client.insert("transactions", values: TxInsert(
            household_id: debt.householdId,
            account_id: accountId,
            debt_id: debt.id,
            amount: amount,
            type: (isIncome ? TransactionType.income : .expense).rawValue,
            description: desc,
            date: today,
            created_by: userId
        ))

        // 2) Ajuste de saldo (income suma, expense resta).
        let delta = isIncome ? amount : -amount
        let _: EmptyResponse = try await client.rpc("apply_account_delta", params: [
            "p_account_id": accountId, "p_delta": delta,
        ])

        // 3) Historial de abonos.
        struct PayInsert: Encodable {
            let debt_id: String
            let amount: Double
            let date: String
        }
        let _: [DebtPayment] = try await client.insert("debt_payments", values:
            PayInsert(debt_id: debt.id, amount: amount, date: today))

        // 4) Actualizar el progreso de la deuda.
        let newPaid = debt.amountPaid + amount
        let isPaid = newPaid >= debt.amount
        struct DebtPatch: Encodable {
            let amount_paid: Double
            let status: String
        }
        try await client.update("debts", values: DebtPatch(
            amount_paid: newPaid,
            status: isPaid ? DebtStatus.paid.rawValue : DebtStatus.active.rawValue
        ), match: ["id": debt.id])
    }

    /// Edita un movimiento existente. Ajusta saldos de forma consistente:
    /// revierte el efecto del movimiento ORIGINAL en su cuenta original y aplica
    /// el efecto del movimiento NUEVO en su cuenta nueva (soporta cambio de
    /// cuenta, monto y tipo). Los transfers no tocan saldo. Luego hace PATCH.
    func updateTransaction(id: String, original: Transaction, payload: NewTransaction) async throws {
        // Efecto que el original tenía sobre su cuenta (income suma, expense resta).
        let oldDelta: Double = original.type == .transfer
            ? 0
            : (original.type == .income ? original.amount : -original.amount)
        // Efecto que tendrá el nuevo.
        let newDelta: Double = payload.type == .transfer
            ? 0
            : (payload.type == .income ? payload.amount : -payload.amount)

        // Revertir el original en su cuenta original.
        if oldDelta != 0 {
            let _: EmptyResponse = try await client.rpc("apply_account_delta", params: [
                "p_account_id": original.accountId, "p_delta": -oldDelta,
            ])
        }
        // Aplicar el nuevo en su cuenta (puede haber cambiado).
        if newDelta != 0 {
            let _: EmptyResponse = try await client.rpc("apply_account_delta", params: [
                "p_account_id": payload.accountId, "p_delta": newDelta,
            ])
        }

        struct Patch: Encodable {
            let account_id: String
            let amount: Double
            let type: String
            let category_id: String?
            let description: String?
            let date: String
        }
        try await client.update("transactions", values: Patch(
            account_id: payload.accountId,
            amount: payload.amount,
            type: payload.type.rawValue,
            category_id: payload.type == .transfer ? nil : payload.categoryId,
            description: payload.description,
            date: payload.date
        ), match: ["id": id])
    }

    // MARK: - Perfil

    /// Actualiza nombre y/o avatar del perfil. Solo envía los campos presentes.
    func updateProfile(userId: String, name: String? = nil, avatarUrl: String? = nil) async throws {
        struct Patch: Encodable {
            let name: String?
            let avatar_url: String?
        }
        try await client.update("profiles",
            values: Patch(name: name, avatar_url: avatarUrl),
            match: ["id": userId])
    }

    /// Guarda las respuestas del cuestionario de onboarding (columna jsonb).
    func saveOnboarding(userId: String, survey: OnboardingSurvey) async throws {
        struct Patch: Encodable { let onboarding: OnboardingSurvey }
        try await client.update("profiles", values: Patch(onboarding: survey), match: ["id": userId])
    }

    /// Sube una imagen de avatar al Storage y devuelve su URL pública.
    func uploadAvatar(userId: String, jpeg: Data) async throws -> String {
        let path = "\(userId)-\(Int(Date().timeIntervalSince1970)).jpg"
        return try await client.uploadToStorage(
            bucket: "avatars", path: path, data: jpeg, contentType: "image/jpeg")
    }

    /// Persiste la moneda preferida del usuario en la BD.
    func updateCurrency(userId: String, currency: String) async throws {
        struct Patch: Encodable { let currency: String }
        try await client.update("profiles", values: Patch(currency: currency), match: ["id": userId])
    }

    // MARK: - Hogar

    /// Actualiza el nombre del hogar.
    func updateHouseholdName(householdId: String, name: String) async throws {
        struct Patch: Encodable { let name: String }
        try await client.update("households", values: Patch(name: name), match: ["id": householdId])
    }

    /// Regenera el código de invitación del hogar y devuelve el nuevo código.
    func regenerateInviteCode(householdId: String) async throws -> String {
        let code = Self.randomInviteCode()
        struct Patch: Encodable { let invite_code: String }
        try await client.update("households", values: Patch(invite_code: code), match: ["id": householdId])
        return code
    }

    /// Código de invitación aleatorio de 6 caracteres (sin ambiguos 0/O, 1/I).
    private static func randomInviteCode(length: Int = 6) -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
    }

    // MARK: - Eliminación de entidades

    /// Elimina una cuenta y, en cascada, sus transacciones (como el legacy).
    func deleteAccount(id: String) async throws {
        try await client.deleteRow("transactions", match: ["account_id": id])
        try await client.deleteRow("accounts", match: ["id": id])
    }

    func deleteDebt(id: String) async throws {
        try await client.deleteRow("debts", match: ["id": id])
    }

    func deleteGoal(id: String) async throws {
        try await client.deleteRow("savings_goals", match: ["id": id])
    }

    func deleteBudget(id: String) async throws {
        try await client.deleteRow("budgets", match: ["id": id])
    }

    // MARK: - Listas de compra (edición / eliminación)

    /// Actualiza nombre y presupuesto de una lista de compra.
    func shoppingListUpdate(id: String, name: String, estimatedTotal: Double?) async throws {
        struct Patch: Encodable {
            let name: String
            let estimated_total: Double?
        }
        try await client.update("shopping_lists", values: Patch(name: name, estimated_total: estimatedTotal), match: ["id": id])
    }

    /// Elimina una lista. `shopping_items.list_id` tiene ON DELETE CASCADE,
    /// por lo que los ítems se borran automáticamente.
    func shoppingListDelete(id: String) async throws {
        try await client.deleteRow("shopping_lists", match: ["id": id])
    }

    // MARK: - Plan automático (recurrente ligado a deuda / meta)

    /// Crea un `recurring_events` ligado a una deuda o meta (plan de cuotas/aporte
    /// periódico). Uno de `debtId`/`savingsGoalId` debe venir. `dayOfMonth` fija el
    /// día de cobro; `nextDate` se calcula a partir de él.
    func createRecurringPlan(
        householdId: String,
        name: String,
        amount: Double,
        type: TransactionType,
        frequency: Frequency,
        categoryId: String?,
        dayOfMonth: Int,
        debtId: String? = nil,
        savingsGoalId: String? = nil
    ) async throws {
        struct Insert: Encodable {
            let household_id: String
            let name: String
            let amount: Double
            let type: String
            let frequency: String
            let category_id: String?
            let day_of_month: Int
            let next_date: String
            let is_active: Bool
            let debt_id: String?
            let savings_goal_id: String?
        }
        let insert = Insert(
            household_id: householdId,
            name: name,
            amount: amount,
            type: type.rawValue,
            frequency: frequency.rawValue,
            category_id: categoryId,
            day_of_month: dayOfMonth,
            next_date: Self.nextDate(forDayOfMonth: dayOfMonth),
            is_active: true,
            debt_id: debtId,
            savings_goal_id: savingsGoalId
        )
        let _: [RecurringEvent] = try await client.insert("recurring_events", values: insert)
    }

    /// Próxima fecha "yyyy-MM-dd" para ese día del mes: este mes si aún no pasó,
    /// si no el mes siguiente (equivale a calcNextDate del legacy).
    static func nextDate(forDayOfMonth day: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let now = Date()
        let clampedDay = min(max(day, 1), 28)
        var comps = cal.dateComponents([.year, .month], from: now)
        comps.day = clampedDay
        let thisMonth = cal.date(from: comps) ?? now
        let target = thisMonth >= cal.startOfDay(for: now)
            ? thisMonth
            : (cal.date(byAdding: .month, value: 1, to: thisMonth) ?? thisMonth)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = cal.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: target)
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
