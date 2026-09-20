"""
Detección de gastos inusuales o duplicados con IA (Claude).

La app manda los movimientos recientes (texto compacto) y Claude devuelve una
lista de posibles anomalías: duplicados, montos atípicos, cargos repetidos. La
app las muestra como aviso; el usuario decide. No modifica datos.
"""
import asyncio
import json
import os

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.deps import get_current_user

router = APIRouter()

ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-haiku-4-5")

SYSTEM_PROMPT = (
    "Eres un detector de anomalías en gastos para una app de finanzas de pareja "
    "en Colombia. Recibes una lista de movimientos recientes (id, fecha, monto, "
    "categoría, descripción). Devuelve ÚNICAMENTE un JSON con la forma "
    '{"anomalies": [{"id": "<id_transaccion>", "type": "duplicado|inusual|repetido", '
    '"reason": "<motivo corto en español>"}]}. '
    "Marca: posibles DUPLICADOS (mismo monto+descripción muy cercanos en fecha), "
    "montos INUSUALES (muy por encima de lo típico de esa categoría), o cargos "
    "REPETIDOS sospechosos. Sé conservador: si no hay nada claro, devuelve lista "
    "vacía. No inventes ids que no estén en la lista. Máximo 5 anomalías."
)


class Tx(BaseModel):
    id: str
    date: str
    amount: float
    category: str | None = None
    description: str | None = None


class AnomaliesRequest(BaseModel):
    transactions: list[Tx]


class Anomaly(BaseModel):
    id: str
    type: str
    reason: str


class AnomaliesResponse(BaseModel):
    anomalies: list[Anomaly]


@router.post("/scan", response_model=AnomaliesResponse)
async def anomalies_scan(body: AnomaliesRequest, user=Depends(get_current_user)):
    if not body.transactions:
        return AnomaliesResponse(anomalies=[])
    if len(body.transactions) > 200:
        body.transactions = body.transactions[:200]

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="No configurado en el servidor.")

    lines = [
        f"- id={t.id} | {t.date[:10]} | {t.amount} | {t.category or '—'} | {t.description or '—'}"
        for t in body.transactions
    ]
    user_msg = "Movimientos recientes:\n" + "\n".join(lines)

    payload = {
        "model": ANTHROPIC_MODEL,
        "max_tokens": 500,
        "system": [{"type": "text", "text": SYSTEM_PROMPT, "cache_control": {"type": "ephemeral"}}],
        "messages": [{"role": "user", "content": user_msg}],
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
                    await asyncio.sleep(0.8 * (attempt + 1))
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Error contactando el servicio: {e}")
    if resp is None or resp.status_code != 200:
        raise HTTPException(status_code=503, detail="El asistente está ocupado.")

    data = resp.json()
    parts = [b.get("text", "") for b in data.get("content", []) if b.get("type") == "text"]
    raw = "".join(parts).strip()
    if "```" in raw:
        raw = raw.replace("```json", "").replace("```", "").strip()
    try:
        parsed = json.loads(raw)
        valid_ids = {t.id for t in body.transactions}
        out = [
            Anomaly(id=a["id"], type=a.get("type", "inusual"), reason=a.get("reason", ""))
            for a in parsed.get("anomalies", [])
            if a.get("id") in valid_ids
        ]
    except (json.JSONDecodeError, KeyError, TypeError):
        out = []
    return AnomaliesResponse(anomalies=out[:5])
