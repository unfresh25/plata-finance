"""
Conexión bancaria vía Syncfy (Open Data).

La api_key de Syncfy vive solo aquí (server-side). La app pide un token temporal
(/bank/session) y consulta catálogo (/bank/countries, /bank/sites). Cada usuario
Plata se asocia a un id_user de Syncfy, guardado en profiles.syncfy_user_id.

Fase 1: catálogo. Fase 2: crear conexión + estado del job + TWOFA.
(accounts/transactions, sync y webhook llegan en fases siguientes.)
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app import syncfy
from app.db import db
from app.deps import get_current_user

router = APIRouter()


def _household_id(user_id: str) -> str:
    """household_id del usuario (para asociar la conexión). 400 si no tiene."""
    supa = db()
    row = supa.table("profiles").select("household_id").eq("id", user_id).limit(1).execute()
    hh = (row.data or [{}])[0].get("household_id")
    if not hh:
        raise HTTPException(status_code=400, detail="El usuario no tiene un hogar.")
    return hh


class SessionResponse(BaseModel):
    token: str
    syncfy_user_id: str


async def _ensure_syncfy_user(user_id: str, email: str | None) -> str:
    """Devuelve el id_user de Syncfy del usuario, creándolo la primera vez y
    guardándolo en profiles.syncfy_user_id."""
    supa = db()
    row = (
        supa.table("profiles")
        .select("syncfy_user_id")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )
    existing = (row.data or [{}])[0].get("syncfy_user_id")
    if existing:
        return existing

    id_user = await syncfy.create_user(
        name=email or f"plata-{user_id[:8]}",
        id_external=user_id,
    )
    supa.table("profiles").update({"syncfy_user_id": id_user}).eq("id", user_id).execute()
    return id_user


@router.post("/session", response_model=SessionResponse)
async def bank_session(user=Depends(get_current_user)):
    """Crea/reutiliza el usuario Syncfy y devuelve un token temporal para el cliente."""
    try:
        id_user = await _ensure_syncfy_user(user.id, user.email)
        token = await syncfy.create_session(id_user)
    except syncfy.SyncfyError as e:
        raise HTTPException(status_code=502, detail=f"Syncfy: {e.message}")
    return SessionResponse(token=token, syncfy_user_id=id_user)


@router.get("/countries")
async def bank_countries(token: str, user=Depends(get_current_user)):
    """Catálogo de países. El token se genera en /bank/session."""
    try:
        return {"countries": await syncfy.countries(token)}
    except syncfy.SyncfyError as e:
        raise HTTPException(status_code=502, detail=f"Syncfy: {e.message}")


@router.get("/sites")
async def bank_sites(
    token: str,
    id_country: str | None = None,
    is_test: bool = False,
    user=Depends(get_current_user),
):
    """Catálogo de instituciones/sites (con su array de credentials dinámico)."""
    try:
        return {"sites": await syncfy.sites(token, id_country=id_country, is_test=is_test)}
    except syncfy.SyncfyError as e:
        raise HTTPException(status_code=502, detail=f"Syncfy: {e.message}")


# ─── Fase 2: crear conexión + estado del job + TWOFA ─────────────────────────

class ConnectRequest(BaseModel):
    token: str
    endpoint: str          # viene del site (ej. /v1/credentials/pulls)
    id_site: str
    institution: str       # nombre del banco/site para mostrar
    credentials: dict      # {name: valor} según credentials[] del site


class ConnectResponse(BaseModel):
    id_credential: str
    id_job: str
    connection_id: str


@router.post("/connect", response_model=ConnectResponse)
async def bank_connect(body: ConnectRequest, user=Depends(get_current_user)):
    """Crea la credencial en Syncfy y registra la conexión (status 'syncing').
    Las credenciales bancarias NO se guardan: solo se reenvían a Syncfy."""
    hh = _household_id(user.id)
    try:
        result = await syncfy.create_credential(
            body.token, body.endpoint, body.id_site, body.credentials
        )
    except syncfy.SyncfyError as e:
        raise HTTPException(status_code=502, detail=f"Syncfy: {e.message}")

    id_credential = result.get("id_credential")
    id_job = result.get("id_job")
    if not id_credential or not id_job:
        raise HTTPException(status_code=502, detail="Syncfy no devolvió la credencial.")

    supa = db()
    # Upsert de la conexión (idempotente por household+provider+credential).
    row = supa.table("bank_connections").upsert({
        "household_id": hh,
        "owner_id": user.id,
        "provider": "syncfy",
        "provider_credential_id": id_credential,
        "provider_site_id": body.id_site,
        "institution": body.institution,
        "status": "syncing",
    }, on_conflict="household_id,provider,provider_credential_id").execute()
    connection_id = (row.data or [{}])[0].get("id", "")

    return ConnectResponse(
        id_credential=id_credential, id_job=id_job, connection_id=connection_id
    )


@router.get("/job")
async def bank_job(token: str, id_job: str, user=Depends(get_current_user)):
    """Último estado del job: {code, twofa?}. La app hace poll suave de esto.
    Códigos Syncfy: 200 éxito, 401 credenciales inválidas, 410 requiere TWOFA."""
    try:
        history = await syncfy.job_status(token, id_job)
    except syncfy.SyncfyError as e:
        raise HTTPException(status_code=502, detail=f"Syncfy: {e.message}")

    last = history[-1] if isinstance(history, list) and history else {}
    code = last.get("code")
    out: dict = {"code": code}
    if code == 410:
        out["twofa"] = last.get("twofa", [])   # campos del reto (name/type/label)
    return out


class TwofaRequest(BaseModel):
    token: str
    id_job: str
    answers: dict          # {name: valor} según los campos del reto


@router.post("/twofa")
async def bank_twofa(body: TwofaRequest, user=Depends(get_current_user)):
    """Responde el challenge TWOFA/MFA del banco y sigue el poll del job."""
    try:
        await syncfy.answer_twofa(body.token, body.id_job, body.answers)
    except syncfy.SyncfyError as e:
        raise HTTPException(status_code=502, detail=f"Syncfy: {e.message}")
    return {"ok": True}


# ─── Fase 3: sync (accounts + transactions) + listar desde la BD ─────────────

def _iso(ts) -> str | None:
    """UNIX (segundos) → ISO8601, o None."""
    from datetime import datetime, timezone
    if not ts:
        return None
    try:
        return datetime.fromtimestamp(int(ts), tz=timezone.utc).isoformat()
    except (TypeError, ValueError, OSError):
        return None


async def _sync_credential(token: str, household_id: str, connection_id: str, id_credential: str) -> dict:
    """Trae accounts + transactions de una credencial y hace upsert en la BD.
    Devuelve conteos. Sync incremental por dt_refresh_from si ya había datos."""
    supa = db()
    accs = await syncfy.accounts(token, id_credential)
    acc_id_map: dict[str, str] = {}   # provider_account_id -> nuestro id

    for a in accs or []:
        prov_id = a.get("id_account")
        if not prov_id:
            continue
        row = supa.table("bank_accounts").upsert({
            "connection_id": connection_id,
            "household_id": household_id,
            "provider_account_id": prov_id,
            "name": a.get("name") or "Cuenta",
            "type": (a.get("site") or {}).get("name"),
            "balance": a.get("balance") or 0,
            "currency": a.get("currency"),
            "last_synced_at": _iso(a.get("dt_refresh")),
        }, on_conflict="connection_id,provider_account_id").execute()
        acc_id_map[prov_id] = (row.data or [{}])[0].get("id", "")

    # Sync incremental: solo transacciones refrescadas después del último sync.
    conn = supa.table("bank_connections").select("last_successful_sync_at").eq("id", connection_id).limit(1).execute()
    dt_from = None
    prev = (conn.data or [{}])[0].get("last_successful_sync_at")
    if prev:
        from datetime import datetime
        try:
            dt_from = int(datetime.fromisoformat(prev).timestamp())
        except (TypeError, ValueError):
            dt_from = None

    txs = await syncfy.transactions(token, id_credential, dt_refresh_from=dt_from)
    tx_count = 0
    for t in txs or []:
        prov_acc = t.get("id_account")
        our_acc = acc_id_map.get(prov_acc)
        prov_tx = t.get("id_transaction")
        if not our_acc or not prov_tx:
            continue
        supa.table("bank_transactions").upsert({
            "account_id": our_acc,
            "household_id": household_id,
            "provider_transaction_id": prov_tx,
            "amount": t.get("amount") or 0,
            "description": t.get("description"),
            "currency": t.get("currency"),
            "transaction_date": _iso(t.get("dt_transaction")),
            "pending": bool(t.get("is_pending")),
            "provider_refresh_at": _iso(t.get("dt_refresh")),
        }, on_conflict="account_id,provider_transaction_id").execute()
        tx_count += 1

    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).isoformat()
    supa.table("bank_connections").update({
        "status": "active", "last_sync_at": now, "last_successful_sync_at": now,
    }).eq("id", connection_id).execute()

    return {"accounts": len(accs or []), "transactions": tx_count}


class SyncRequest(BaseModel):
    token: str
    id_credential: str


@router.post("/sync")
async def bank_sync(body: SyncRequest, user=Depends(get_current_user)):
    """Trae y persiste accounts + transactions de una credencial ya conectada."""
    hh = _household_id(user.id)
    supa = db()
    conn = (
        supa.table("bank_connections")
        .select("id")
        .eq("household_id", hh)
        .eq("provider_credential_id", body.id_credential)
        .limit(1)
        .execute()
    )
    connection_id = (conn.data or [{}])[0].get("id")
    if not connection_id:
        raise HTTPException(status_code=404, detail="Conexión no encontrada.")
    try:
        result = await _sync_credential(body.token, hh, connection_id, body.id_credential)
    except syncfy.SyncfyError as e:
        supa.table("bank_connections").update({"status": "error"}).eq("id", connection_id).execute()
        raise HTTPException(status_code=502, detail=f"Syncfy: {e.message}")
    return result


@router.get("/connections")
async def bank_connections(user=Depends(get_current_user)):
    """Conexiones + sus cuentas del hogar, desde NUESTRA BD (no llama a Syncfy)."""
    hh = _household_id(user.id)
    supa = db()
    conns = (
        supa.table("bank_connections")
        .select("*")
        .eq("household_id", hh)
        .order("connected_at", desc=True)
        .execute()
    ).data or []
    accts = (
        supa.table("bank_accounts").select("*").eq("household_id", hh).execute()
    ).data or []
    by_conn: dict = {}
    for a in accts:
        by_conn.setdefault(a["connection_id"], []).append(a)
    for c in conns:
        c["accounts"] = by_conn.get(c["id"], [])
    return {"connections": conns}
