import Foundation

// Modelos de dominio — equivalentes a packages/core/src/types/database.ts.
// Todos Codable con snake_case (coincide con las columnas de Supabase/Postgres).

// MARK: - Household & Profile

struct Household: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var inviteCode: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
        case createdAt = "created_at"
    }
}

struct Profile: Codable, Identifiable, Hashable {
    let id: String
    var householdId: String?
    var name: String
    var avatarUrl: String?
    var currency: String

    enum CodingKeys: String, CodingKey {
        case id, name, currency
        case householdId = "household_id"
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Category

enum CategoryType: String, Codable, Hashable { case income, expense }

struct Category: Codable, Identifiable, Hashable {
    let id: String
    var householdId: String
    var name: String
    var icon: String
    var color: String
    var type: CategoryType

    enum CodingKeys: String, CodingKey {
        case id, name, icon, color, type
        case householdId = "household_id"
    }
}

// MARK: - Account

enum AccountType: String, Codable, Hashable, CaseIterable {
    case debit, credit, cash, savings

    var label: String {
        switch self {
        case .debit: return "Débito"
        case .credit: return "Crédito"
        case .cash: return "Efectivo"
        case .savings: return "Ahorros"
        }
    }

    var sfSymbol: String {
        switch self {
        case .debit: return "creditcard"
        case .credit: return "creditcard.fill"
        case .cash: return "banknote"
        case .savings: return "building.columns"
        }
    }
}

struct Account: Codable, Identifiable, Hashable {
    let id: String
    var householdId: String
    var ownerId: String
    var name: String
    var type: AccountType
    var balance: Double
    var currency: String
    var color: String
    var icon: String

    enum CodingKeys: String, CodingKey {
        case id, name, type, balance, currency, color, icon
        case householdId = "household_id"
        case ownerId = "owner_id"
    }
}

// MARK: - Transaction

enum TransactionType: String, Codable, Hashable, CaseIterable {
    case income, expense, transfer

    var label: String {
        switch self {
        case .income: return "Ingreso"
        case .expense: return "Gasto"
        case .transfer: return "Transferencia"
        }
    }
}

struct Transaction: Codable, Identifiable, Hashable {
    let id: String
    var accountId: String
    var householdId: String
    var createdBy: String
    var amount: Double
    var type: TransactionType
    var categoryId: String?
    var description: String?
    var date: String
    var isRecurring: Bool

    enum CodingKeys: String, CodingKey {
        case id, amount, type, description, date
        case accountId = "account_id"
        case householdId = "household_id"
        case createdBy = "created_by"
        case categoryId = "category_id"
        case isRecurring = "is_recurring"
    }
}

// MARK: - Recurring

enum Frequency: String, Codable, Hashable, CaseIterable {
    case daily, weekly, biweekly, monthly, yearly

    var label: String {
        switch self {
        case .daily: return "Diario"
        case .weekly: return "Semanal"
        case .biweekly: return "Quincenal"
        case .monthly: return "Mensual"
        case .yearly: return "Anual"
        }
    }
}

struct RecurringEvent: Codable, Identifiable, Hashable {
    let id: String
    var householdId: String
    var name: String
    var amount: Double
    var frequency: Frequency
    var nextDate: String
    var categoryId: String?
    var accountId: String?
    var isActive: Bool
    var logoId: String?   // id del logo de app elegido (netflix, disney, apple-music…)

    enum CodingKeys: String, CodingKey {
        case id, name, amount, frequency
        case householdId = "household_id"
        case nextDate = "next_date"
        case categoryId = "category_id"
        case accountId = "account_id"
        case isActive = "is_active"
        case logoId = "logo_id"
    }
}

// MARK: - Budget

enum BudgetPeriod: String, Codable, Hashable { case weekly, monthly }

struct Budget: Codable, Identifiable, Hashable {
    let id: String
    var householdId: String
    var categoryId: String
    var amount: Double
    var period: BudgetPeriod
    var startDate: String

    enum CodingKeys: String, CodingKey {
        case id, amount, period
        case householdId = "household_id"
        case categoryId = "category_id"
        case startDate = "start_date"
    }
}

// MARK: - Debt

enum DebtDirection: String, Codable, Hashable {
    case owedToUs = "owed_to_us"
    case weOwe = "we_owe"
}

enum DebtStatus: String, Codable, Hashable { case active, paid }

struct Debt: Codable, Identifiable, Hashable {
    let id: String
    var householdId: String
    var createdBy: String
    var direction: DebtDirection
    var personName: String
    var amount: Double
    var amountPaid: Double
    var dueDate: String?
    var description: String?
    var status: DebtStatus

    enum CodingKeys: String, CodingKey {
        case id, direction, amount, description, status
        case householdId = "household_id"
        case createdBy = "created_by"
        case personName = "person_name"
        case amountPaid = "amount_paid"
        case dueDate = "due_date"
    }

    var remaining: Double { max(0, amount - amountPaid) }
    var progress: Double { amount > 0 ? min(1, amountPaid / amount) : 0 }
}

// MARK: - Abono a deuda (historial)

struct DebtPayment: Codable, Identifiable, Hashable {
    let id: String
    var debtId: String
    var amount: Double
    var date: String
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, date, note
        case debtId = "debt_id"
    }
}

// MARK: - Savings goal

enum GoalStatus: String, Codable, Hashable { case active, completed, cancelled }

struct SavingsGoal: Codable, Identifiable, Hashable {
    let id: String
    var householdId: String
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var deadline: String?
    var icon: String
    var color: String
    var accountId: String?
    var status: GoalStatus

    enum CodingKeys: String, CodingKey {
        case id, name, deadline, icon, color, status
        case householdId = "household_id"
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case accountId = "account_id"
    }

    var progress: Double { targetAmount > 0 ? min(1, currentAmount / targetAmount) : 0 }
}

// MARK: - Shopping

enum ListStatus: String, Codable, Hashable { case open, shopping, completed }

struct ShoppingList: Codable, Identifiable, Hashable {
    let id: String
    var householdId: String
    var createdBy: String
    var name: String
    var store: String?
    var estimatedTotal: Double?
    var actualTotal: Double?
    var status: ListStatus
    var date: String

    enum CodingKeys: String, CodingKey {
        case id, name, store, status, date
        case householdId = "household_id"
        case createdBy = "created_by"
        case estimatedTotal = "estimated_total"
        case actualTotal = "actual_total"
    }
}

struct ShoppingItem: Codable, Identifiable, Hashable {
    let id: String
    var listId: String
    var name: String
    var quantity: Double
    var unit: String?
    var estimatedPrice: Double?
    var actualPrice: Double?
    var isChecked: Bool
    var addedBy: String

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit
        case listId = "list_id"
        case estimatedPrice = "estimated_price"
        case actualPrice = "actual_price"
        case isChecked = "is_checked"
        case addedBy = "added_by"
    }
}
