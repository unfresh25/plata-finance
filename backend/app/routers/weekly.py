"""
Resumen semanal del hogar generado por IA (Claude), cacheado por semana.

La app arma un resumen financiero de la SEMANA (texto) y lo manda; el backend
genera con Claude una vez por hogar/semana y lo guarda en weekly_summaries. Las
siguientes aperturas leen del cache (GET), sin gastar tokens.
"""
import asyncio
import os
from datetime import date, timedelta

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.db import db
from app.deps import get_current_user

router = APIRouter()

ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-haiku-4-5")

SYSTEM_PROMPT = (
    "Eres Plata, el asistente financiero de una app de finanzas para parejas en "
    "Colombia. Con el RESUMEN de la semana del hogar, escribe un resumen breve "
    "(3-4 frases) del gasto de la semana. Reglas: español colombiano, cercano, en "
    "plural (gastaron, tienen); un insight accionable; formatea montos con la "
    "moneda dada; no inventes datos que no estén en el resumen; sin disclaimers. "
    "Si hubo poca actividad, dilo con naturalidad en vez de inventar cifras."
)


def _household_id(user_id: str) -> str:
    supa = db()
    row = supa.table("profiles").select("household_id").eq("id", user_id).limit(1).execute()
    hh = (row.data or [{}])[0].get("household_id")
    if not hh:
        raise HTTPException(status_code=400, detail="El usuario no tiene un hogar.")
    return hh


class WeeklyRequest(BaseModel):
    week_start: str          # YYYY-MM-DD (lunes ISO)
    context: str             # resumen financiero de la semana (texto)
    currency: str = "COP"
    force: bool = False


class WeeklyResponse(BaseModel):
    week_start: str
    week_end: str
    summary_text: str
    cached: bool


def _week_end(week_start: str) -> str:
    d = date.fromisoformat(week_start)
    return (d + timedelta(days=6)).isoformat()


@router.get("/summary", response_model=WeeklyResponse | None)
async def weekly_get(week_start: str, user=Depends(get_current_user)):
    """Lee el resumen cacheado de la semana (sin generar). 200 con null si no hay."""
    hh = _household_id(user.id)
    supa = db()
    row = (
        supa.table("weekly_summaries").select("*")
        .eq("household_id", hh).eq("week_start", week_start).limit(1).execute()
    )
    r = (row.data or [None])[0]
    if not r:
        return None
    return WeeklyResponse(week_start=r["week_start"], week_end=r["week_end"],
                          summary_text=r["summary_text"], cached=True)


@router.post("/summary", response_model=WeeklyResponse)
async def weekly_generate(body: WeeklyRequest, user=Depends(get_current_user)):
    """Genera (o devuelve cacheado) el resumen de la semana."""
    hh = _household_id(user.id)
    supa = db()

    if not body.force:
        row = (
            supa.table("weekly_summaries").select("*")
            .eq("household_id", hh).eq("week_start", body.week_start).limit(1).execute()
        )
        r = (row.data or [None])[0]
        if r:
            return WeeklyResponse(week_start=r["week_start"], week_end=r["week_end"],
                                  summary_text=r["summary_text"], cached=True)

    if len(body.context) > 20000:
        raise HTTPException(status_code=413, detail="El contexto es demasiado grande.")
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="El resumen no está configurado en el servidor.")

    system = SYSTEM_PROMPT + f"\n\nMoneda: {body.currency}\n\nRESUMEN DE LA SEMANA:\n" + body.context
    payload = {
        "model": ANTHROPIC_MODEL,
        "max_tokens": 500,
        "system": [{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
        "messages": [{"role": "user", "content": "Escribe el resumen semanal."}],
    }
    headers = {"x-api-key": api_key, "anthropic-version": "2023-06-01", "content-type": "application/json"}

    resp = None
    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            for attempt in range(3):
                resp = await client.post(ANTHROPIC_URL, headers=headers, json=payload)
                if resp.status_code not in (429, 500, 502, 503, 504):
                    break
                if attempt < 2:
                    await asyncio.sleep(0.8 * (attempt + 1))
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Error contactando el servicio: {e}")
    if resp is None or resp.status_code != 200:
        raise HTTPException(status_code=503, detail="El asistente está ocupado. Inténtalo de nuevo.")

    data = resp.json()
    parts = [b.get("text", "") for b in data.get("content", []) if b.get("type") == "text"]
    text = "".join(parts).strip()
    if not text:
        raise HTTPException(status_code=422, detail="No se pudo generar el resumen.")

    week_end = _week_end(body.week_start)
    supa.table("weekly_summaries").upsert({
        "household_id": hh,
        "week_start": body.week_start,
        "week_end": week_end,
        "summary_text": text,
        "model": ANTHROPIC_MODEL,
        "currency": body.currency,
    }, on_conflict="household_id,week_start").execute()

    return WeeklyResponse(week_start=body.week_start, week_end=week_end,
                          summary_text=text, cached=False)
