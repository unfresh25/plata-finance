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
