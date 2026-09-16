import SwiftUI

// Datos de ejemplo para previsualizar la UI sin backend. Activado por el
// argumento de lanzamiento "-uiPreview". No afecta el arranque normal.

extension AppState {
    static var previewMocked: AppState {
        let app = AppState()
        app.profile = Profile(id: "u1", householdId: "h1", name: "Jorge", avatarUrl: nil, currency: "COP")
        app.household = Household(id: "h1", name: "Hogar Plata", inviteCode: "PLATA7", createdAt: nil)
        app.categories = [
            // Íconos con slugs Hugeicons (como siembra la BD real) para que el
            // preview refleje los assets de CategoryIcons, no SF Symbols.
            Category(id: "c1", householdId: "h1", name: "Alimentación", icon: "hamburger-01", color: "#34D399", type: .expense),
            Category(id: "c2", householdId: "h1", name: "Transporte", icon: "taxi", color: "#38BDF8", type: .expense),
            Category(id: "c3", householdId: "h1", name: "Vivienda", icon: "home-01", color: "#818CF8", type: .expense),
            Category(id: "c4", householdId: "h1", name: "Entretenimiento", icon: "tv-01", color: "#C084FC", type: .expense),
            Category(id: "c5", householdId: "h1", name: "Salario", icon: "coins-01", color: "#34D399", type: .income),
        ]
        app.accounts = [
            Account(id: "a1", householdId: "h1", ownerId: "u1", name: "Efectivo", type: .cash, balance: 850_000, currency: "COP", color: "#34D399", icon: "banknote"),
            Account(id: "a2", householdId: "h1", ownerId: "u1", name: "Bancolombia", type: .debit, balance: 3_240_000, currency: "COP", color: "#818CF8", icon: "creditcard"),
            Account(id: "a3", householdId: "h1", ownerId: "u1", name: "Ahorros", type: .savings, balance: 5_600_000, currency: "COP", color: "#38BDF8", icon: "building.columns"),
        ]
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        app.transactions = [
            Transaction(id: "t1", accountId: "a2", householdId: "h1", createdBy: "u1", amount: 45_000, type: .expense, categoryId: "c1", description: "Almuerzo Andrés", date: today, isRecurring: false),
            Transaction(id: "t2", accountId: "a2", householdId: "h1", createdBy: "u1", amount: 2_500_000, type: .income, categoryId: "c5", description: "Salario", date: today, isRecurring: false),
            Transaction(id: "t3", accountId: "a1", householdId: "h1", createdBy: "u1", amount: 12_000, type: .expense, categoryId: "c2", description: "Taxi", date: today, isRecurring: false),
            Transaction(id: "t4", accountId: "a2", householdId: "h1", createdBy: "u1", amount: 89_000, type: .expense, categoryId: "c4", description: "Cine", date: today, isRecurring: false),
            Transaction(id: "t5", accountId: "a2", householdId: "h1", createdBy: "u1", amount: 1_800_000, type: .expense, categoryId: "c3", description: "Arriendo", date: today, isRecurring: false),
        ]
        app.budgets = [
            Budget(id: "b1", householdId: "h1", categoryId: "c1", amount: 600_000, period: .monthly, startDate: today),
            Budget(id: "b2", householdId: "h1", categoryId: "c4", amount: 200_000, period: .monthly, startDate: today),
        ]
        app.goals = [
            SavingsGoal(id: "g1", householdId: "h1", name: "Viaje a Cartagena", targetAmount: 3_000_000, currentAmount: 1_950_000, deadline: nil, icon: "airplane", color: "#38BDF8", accountId: "a3", status: .active),
            SavingsGoal(id: "g2", householdId: "h1", name: "Fondo de emergencia", targetAmount: 6_000_000, currentAmount: 5_600_000, deadline: nil, icon: "shield.fill", color: "#34D399", accountId: "a3", status: .active),
        ]
        app.debts = [
            Debt(id: "d1", householdId: "h1", createdBy: "u1", direction: .owedToUs, personName: "Camila", amount: 300_000, amountPaid: 100_000, dueDate: nil, description: "Préstamo", status: .active),
            Debt(id: "d2", householdId: "h1", createdBy: "u1", direction: .weOwe, personName: "David", amount: 150_000, amountPaid: 0, dueDate: nil, description: "Cena", status: .active),
        ]
        app.shoppingLists = [
            ShoppingList(id: "s1", householdId: "h1", createdBy: "u1", name: "Mercado semanal", store: "Éxito", estimatedTotal: 250_000, actualTotal: nil, status: .open, date: today),
        ]
        app.recurringEvents = [
            RecurringEvent(id: "r1", householdId: "h1", name: "Spotify", amount: 16_900, frequency: .monthly, nextDate: today, categoryId: "c4", accountId: "a2", isActive: true),
            RecurringEvent(id: "r2", householdId: "h1", name: "Netflix", amount: 38_900, frequency: .monthly, nextDate: today, categoryId: "c4", accountId: "a2", isActive: true),
            RecurringEvent(id: "r3", householdId: "h1", name: "Arriendo", amount: 1_800_000, frequency: .monthly, nextDate: today, categoryId: "c3", accountId: "a2", isActive: true),
        ]
        app.phase = .ready
        return app
    }
}
