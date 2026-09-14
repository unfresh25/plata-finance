# Plata Finance

Aplicación de finanzas personales **para parejas**: dos usuarios comparten un
*household* y llevan seguimiento en tiempo real de ingresos, egresos, cuentas,
presupuestos, metas de ahorro, deudas, suscripciones y listas de compras.

Multiplataforma: **móvil** (iOS + Android, Expo/React Native) y **web** (Next.js),
con lógica compartida en un monorepo TypeScript. Backend de IA/OCR en FastAPI.

---

## Stack

| Capa | Tecnología |
|---|---|
| Móvil | Expo (SDK 54) · React Native 0.81 · expo-router |
| Web | Next.js 14 (App Router) · Tailwind |
| Lógica compartida | TypeScript (`packages/core`) |
| Base de datos / Auth / Realtime / Storage | Supabase (PostgreSQL) |
| Backend IA / OCR | FastAPI (Python) · Gemini |
| Monorepo | Turborepo + Bun workspaces |
| Errores | Sentry (opcional) |

## Estructura

```
apps/
  mobile/        # Expo — iOS + Android
  web/           # Next.js 14
packages/
  core/          # tipos, validaciones zod, i18n, utils de formato (con tests)
  ui/            # (placeholder — pendiente de implementar)
backend/         # FastAPI — OCR de recibos, predicciones e insights
supabase/        # schema.sql + migraciones incrementales
```

El flujo de datos es **Supabase como fuente de verdad** (CRUD directo desde el
cliente, protegido por Row Level Security) y **FastAPI para IA/OCR y lógica que
requiere secretos de servidor**. El aislamiento entre hogares se hace 100% en la
base de datos con RLS por `household_id`.

---

## Requisitos

- [Bun](https://bun.sh) `1.3.11`
- Python `3.12+` (solo para el backend)
- Una cuenta de [Supabase](https://supabase.com)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (para aplicar migraciones)

## Setup

```bash
# 1. Instalar dependencias del monorepo
bun install

# 2. Variables de entorno (copiar los ejemplos y rellenar)
cp apps/mobile/.env.example apps/mobile/.env
cp apps/web/.env.example     apps/web/.env.local
cp backend/.env.example      backend/.env
```

### Base de datos

Aplica el schema y las migraciones en tu proyecto Supabase, **en orden**:

```
supabase/schema.sql
supabase/migration_v2.sql
supabase/migration_v3.sql
supabase/migration_v4.sql
supabase/migration_v5_security.sql   # RLS estricta + RPCs + balances atómicos
```

Con el CLI enlazado a tu proyecto:

```bash
supabase link --project-ref <TU_PROJECT_REF>
supabase db push
```

O pégalos manualmente en el **SQL Editor** de Supabase.

### Correr

```bash
bun run mobile   # Expo (móvil)
bun run web      # Next.js (web)

# Backend
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

---

## Variables de entorno

### Cliente (`apps/mobile/.env`, `apps/web/.env.local`)
Se embeben en el bundle — **nunca poner secretos**. La anon key de Supabase es
pública por diseño; la seguridad la da RLS.

| Variable | Descripción |
|---|---|
| `EXPO_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_URL` | URL del proyecto |
| `EXPO_PUBLIC_SUPABASE_ANON_KEY` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Anon key |
| `EXPO_PUBLIC_API_URL` | URL del backend FastAPI (OCR) |
| `EXPO_PUBLIC_SENTRY_DSN` | DSN de Sentry (opcional) |

### Servidor (`backend/.env`)
Secretos — **solo en el servidor**.

| Variable | Descripción |
|---|---|
| `SUPABASE_URL` | URL del proyecto |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role (bypassa RLS — nunca al cliente) |
| `SUPABASE_JWT_SECRET` | Para verificar el JWT del usuario en endpoints protegidos |
| `GEMINI_API_KEY` | Clave de Gemini para el OCR (solo server-side) |

---

## Seguridad

- **Aislamiento por household**: todas las tablas tienen RLS por `household_id`.
  Crear o unirse a un hogar pasa por las RPC `create_household` / `join_household`
  (SECURITY DEFINER, atómicas); el cliente **no** hace insert/update directo de
  `households` ni de `profiles.household_id`.
- **Balances atómicos**: los ajustes de saldo usan la RPC `apply_account_delta`
  (`balance = balance + delta`), no read-modify-write desde el cliente.
- **Sin secretos en el cliente**: el OCR de recibos corre en el backend; la clave
  de Gemini nunca se embebe en la app.

## Tests y CI

```bash
bun test packages/core      # cálculos financieros (formato, porcentajes, presupuesto)
```

El CI (GitHub Actions, `.github/workflows/ci.yml`) corre en cada push/PR:
type-check de los tres paquetes, tests de `core`, smoke test del backend, y
aplica todas las migraciones SQL sobre un Postgres limpio.
