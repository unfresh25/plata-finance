# Jojo's Finance — Documento de Diseño
**Fecha:** 2026-03-22  
**Autor:** Jorge  
**Descripción:** Aplicación multiplataforma (web + Android + iOS) para el manejo de finanzas personales y de pareja.

---

## 1. Visión General

Aplicación de finanzas personales para dos personas (pareja) que permite llevar un seguimiento completo de ingresos, egresos, cuentas, presupuestos, metas, deudas, suscripciones y listas de compras — todo sincronizado en tiempo real entre ambos usuarios. Incluye un módulo de IA con predicciones de gasto y consejos narrativos.

---

## 2. Stack Tecnológico

### Frontend
| Plataforma | Tecnología |
|---|---|
| iOS + Android | React Native (Expo) |
| Web | Next.js 14 |
| Lógica compartida | TypeScript (monorepo) |
| UI compartida | Componentes propios (packages/ui) |

### Backend
| Componente | Tecnología |
|---|---|
| Base de datos | Supabase (PostgreSQL) |
| Auth | Supabase Auth |
| Realtime | Supabase Realtime |
| API / IA | FastAPI (Python) |
| Storage | Supabase Storage |

### IA
| Función | Herramienta |
|---|---|
| Predicciones numéricas | Prophet (series de tiempo) + regresión |
| Consejos narrativos | LLM (Claude API / GPT) |

---

## 3. Arquitectura del Proyecto

```
finanzas-app/
├── apps/
│   ├── mobile/          # React Native (Expo) — iOS + Android
│   └── web/             # Next.js 14
├── packages/
│   ├── core/            # Lógica compartida, tipos, utils, validaciones
│   └── ui/              # Componentes compartidos (web + mobile)
└── backend/             # FastAPI — IA, predicciones, operaciones complejas
```

### Flujo de datos
- **Supabase** es la fuente de verdad — CRUD simple directo desde el cliente
- **FastAPI** expone endpoints para IA, predicciones y lógica compleja
- **Supabase Realtime** sincroniza cambios entre los dos usuarios instantáneamente
- **Auth** basado en el concepto de `household` — un espacio compartido entre dos usuarios

---

## 4. Modelo de Datos

### Infraestructura base
```sql
-- Espacio compartido entre los dos usuarios
households
  id, name, created_at

-- Usuarios vinculados al household
profiles
  id (auth.uid), household_id, name, avatar_url, currency

-- Categorías personalizables (compartidas por el household)
categories
  id, household_id, name, icon, color, type (income/expense)
```

### Cuentas y movimientos
```sql
-- Cuentas (débito, crédito, efectivo, ahorros, etc.)
accounts
  id, household_id, owner_id, name, 
  type (debit/credit/cash/savings),
  balance, currency, color, icon

-- Todas las transacciones (ingresos y egresos)
transactions
  id, account_id, household_id, created_by,
  amount, type (income/expense), category_id,
  description, date, is_recurring, recurring_id
```

### Recurrentes y presupuestos
```sql
-- Suscripciones, facturas, arriendo, servicios
recurring_events
  id, household_id, name, amount, 
  frequency (daily/weekly/monthly/yearly),
  next_date, category_id, account_id, is_active

-- Límite de gasto por categoría
budgets
  id, household_id, category_id, amount,
  period (monthly/weekly), start_date
```

### Deudas
```sql
-- Deudas activas (nos deben / debemos)
debts
  id, household_id, created_by,
  direction (owed_to_us / we_owe),
  person_name, amount, amount_paid,
  due_date, description, status (active/paid)

-- Pagos parciales de deudas
debt_payments
  id, debt_id, amount, date, note
```

### Ahorros y metas
```sql
-- Metas de ahorro (ej: "Viaje a Europa")
savings_goals
  id, household_id, name, target_amount,
  current_amount, deadline, icon, color,
  account_id, status (active/completed/cancelled)

-- Contribuciones individuales a cada meta
savings_contributions
  id, goal_id, created_by, amount, date, note
```

### Planes financieros
```sql
-- Planes de acción sobre deudas, metas o presupuestos
financial_plans
  id, household_id, name,
  type (debt_payoff / savings / budget),
  target_amount, monthly_contribution,
  start_date, end_date, status,
  linked_id (referencia a debt/goal/budget)
```

### Listas de compras
```sql
-- Listas por tienda/ocasión
shopping_lists
  id, household_id, created_by, name,
  store, estimated_total, actual_total,
  status (open / shopping / completed),
  date, category_id

-- Items individuales de la lista
shopping_items
  id, list_id, name, quantity, unit,
  estimated_price, actual_price,
  is_checked, added_by, category_id

-- Plantillas reutilizables (ej: "mercado semanal")
shopping_templates
  id, household_id, name, items (jsonb)
```

**Total: 15 tablas**

---

## 5. Módulos y Pantallas

### 🏠 Dashboard (Inicio)
- Saludo personalizado + balance total del household
- Cards horizontales scrolleables por cuenta
- Resumen del mes: ingresos vs. gastos con barra de progreso
- Últimas 5 transacciones (de ambos)
- Widget de próximos eventos recurrentes
- Alerta de IA si detecta anomalías

### 💸 Transacciones
- Lista completa con filtros por fecha, categoría, cuenta, persona
- Vista por día / semana / mes
- Buscador
- Detalle con opción de editar/eliminar
- Botón FAB para agregar rápidamente

### 📅 Calendario Recurrente
- Vista mensual con iconos de cada evento en su fecha
- Panel inferior: Income total vs. Expenses totales del mes
- Sección "Upcoming" con Próximos pagos ordenados por fecha
- Agregar/editar eventos recurrentes

### 💰 Cuentas
- Lista de cuentas con balance actual
- Detalle: historial de transacciones + gráfica de evolución del saldo
- Agregar/editar cuenta (tipo, color, icono, moneda)
- Transferencias entre cuentas
- Indicador visual de quién es dueño de cada cuenta

### 📊 Presupuestos
- Vista mensual de categorías con barra de progreso
- Semáforo visual: verde / amarillo / rojo según proximidad al límite
- Detalle por categoría con las transacciones que lo componen
- Crear/editar presupuesto por categoría y período

### 🎯 Ahorros y Metas
- Cards por meta: progreso visual, monto alcanzado vs. objetivo, días restantes
- Detalle: contribuciones históricas + proyección de cuándo se alcanza
- Agregar contribución manual o automática desde una cuenta
- Crear/editar metas con deadline y cuenta vinculada

### 💳 Deudas
- Lista separada: "Nos deben" vs. "Debemos"
- Card por deuda: monto pendiente, progreso de pagos, fecha límite
- Detalle: historial de pagos parciales
- Vincular deuda a evento recurrente (pago mensual)

### 🛒 Listas de Compras
- Lista de todas las listas activas y completadas
- Edición colaborativa en tiempo real (Supabase Realtime)
- Barra de progreso: items comprados vs. pendientes + total acumulado
- Al completar → "Convertir en transacción" crea el gasto automáticamente
- Plantillas reutilizables para el mercado semanal/quincenal

### 🤖 IA y Predicciones
**Predicciones (FastAPI + Prophet):**
- Gasto proyectado del mes actual basado en historial
- Proyección por categoría
- Gráfica de tendencia: últimos 6 meses vs. próximo mes

**Consejos narrativos (LLM):**
- Análisis mensual automático en lenguaje natural
- Alertas proactivas cuando una categoría está disparada
- Sugerencias accionables vinculadas a metas y deudas
- Reporte mensual generado automáticamente

### ⚙️ Configuración (desde avatar)
- Perfil personal: nombre, avatar, moneda base
- Gestión del household: invitar pareja, ver miembros
- Categorías personalizadas: crear, editar, reordenar
- Notificaciones: recordatorios de facturas, alertas de presupuesto
- Exportar datos (CSV / PDF)
- Tema: claro / oscuro
- Cerrar sesión

---

## 6. Navegación

### Header global
```
[Logo app]                              [Avatar → perfil / config / logout]
```

### Bottom Tab Bar (5 tabs)
```
🏠 Inicio  |  💸 Movimientos  |  📅 Calendario  |  🏦 Finanzas  |  📊 Reportes
```

### FAB flotante (+)
Siempre visible sobre el tab bar. Abre bottom sheet con:
- Gasto
- Ingreso  
- Transferencia
- Lista de compras

### Segmented controls internos por pantalla
```
🏠 Inicio       →  Resumen | Predicciones IA
💸 Movimientos  →  Transacciones | Presupuestos
📅 Calendario   →  Mensual | Semanal | Todos
🏦 Finanzas     →  Cuentas | Ahorros | Deudas | Listas
📊 Reportes     →  Mensual | Por Categoría | Por Persona
```

**Principio:** máximo 2 taps para llegar a cualquier pantalla.

---

## 7. Sincronización en Tiempo Real

- Supabase Realtime para listas de compras (edición colaborativa simultánea)
- Supabase Realtime para transacciones (ambos ven los cambios al instante)
- Optimistic updates en cliente para sensación de velocidad
- Resolución de conflictos: last-write-wins para la mayoría de entidades

---