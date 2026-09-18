"""
Conexión bancaria vía Syncfy (Open Data).

La api_key de Syncfy vive solo aquí (server-side). La app pide un token temporal
(/bank/session) y consulta catálogo (/bank/countries, /bank/sites). Cada usuario
Plata se asocia a un id_user de Syncfy, guardado en profiles.syncfy_user_id.

Fase 1: infraestructura + catálogo. (Crear conexión, MFA, accounts/transactions,
sync y webhook llegan en fases siguientes.)
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app import syncfy
from app.db import db
from app.deps import get_current_user

router = APIRouter()


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
