"""
Insight contextual del Dashboard: una frase corta y accionable que liga el gasto
reciente con las metas/presupuestos del usuario (la frontera 2026 de IA financiera:
no solo categorizar, sino conectar un gasto con los objetivos).

Se cachea en memoria por request; la app decide cada cuánto pedirlo.
"""
import asyncio
import os

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.deps import get_current_user

router = APIRouter()

ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-haiku-4-5")

SYSTEM_PROMPT = (
    "Eres Plata, un coach financiero cercano (Colombia, español). Con el resumen "
    "de finanzas del hogar, escribe UNA sola frase (máx 20 palabras) accionable y "
    "concreta que conecte el gasto reciente con una meta, un presupuesto o el ahorro. "
    "Ej: 'Vas bien: si mantienes este ritmo, llegas a tu meta de viaje un mes antes.' "
    "o 'Los domicilios ya son el 18% del mes; bajarlos acelera tu fondo de emergencia.' "
    "Tono motivador, nunca regañón. Sin emojis excesivos (máx 1). No inventes cifras "
    "que no estén en el resumen. Si no hay datos suficientes, devuelve frase vacía."
)


class CoachRequest(BaseModel):
    context: str
    currency: str = "COP"


class CoachResponse(BaseModel):
    insight: str


@router.post("/insight", response_model=CoachResponse)
async def coach_insight(body: CoachRequest, user=Depends(get_current_user)):
    if len(body.context) > 20000:
        raise HTTPException(status_code=413, detail="Contexto demasiado grande.")
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="No configurado.")

    system = SYSTEM_PROMPT + f"\n\nMoneda: {body.currency}\n\nRESUMEN:\n" + body.context
    payload = {
        "model": ANTHROPIC_MODEL,
        "max_tokens": 80,
        "system": [{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
        "messages": [{"role": "user", "content": "Dame el insight."}],
    }
    headers = {"x-api-key": api_key, "anthropic-version": "2023-06-01", "content-type": "application/json"}

    resp = None
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            for attempt in range(3):
                resp = await client.post(ANTHROPIC_URL, headers=headers, json=payload)
                if resp.status_code not in (429, 500, 502, 503, 504):
                    break
                if attempt < 2:
                    await asyncio.sleep(0.7 * (attempt + 1))
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Error contactando el servicio: {e}")
    if resp is None or resp.status_code != 200:
        raise HTTPException(status_code=503, detail="El asistente está ocupado.")

    data = resp.json()
    text = "".join(b.get("text", "") for b in data.get("content", []) if b.get("type") == "text").strip()
    return CoachResponse(insight=text)
