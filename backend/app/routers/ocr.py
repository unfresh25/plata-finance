"""
OCR de recibos con Gemini — ejecutado server-side.

Mueve la clave de Gemini fuera del cliente móvil: la app ya no habla directo
con generativelanguage.googleapis.com (donde la key quedaba embebida en el
bundle y era extraíble). En su lugar llama a este endpoint autenticado, que
usa la key desde el entorno del servidor.
"""
import asyncio
import base64
import json
import os

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.deps import get_current_user

router = APIRouter()

# gemini-2.5-flash dejó de estar disponible para nuevas keys (404). Se usa 3.6;
# configurable por GEMINI_MODEL para cambiarlo sin tocar código.
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.6-flash")
GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"
)

PROMPT = (
    "Eres un asistente de finanzas. Extrae la información clave del siguiente "
    "recibo o factura. Responde ÚNICAMENTE con un JSON válido que contenga: "
    '"amount": el total a pagar (número, sin signos), '
    '"description": nombre del local o un resumen corto de qué fue el gasto, '
    '"date": fecha en formato YYYY-MM-DD si es legible.'
)


class ReceiptRequest(BaseModel):
    image_base64: str
    mime_type: str = "image/jpeg"


class ReceiptResponse(BaseModel):
    amount: float | None = None
    description: str | None = None
    date: str | None = None


async def scan_receipt_b64(image_base64: str, mime_type: str = "image/jpeg") -> ReceiptResponse:
    """Núcleo reutilizable del OCR (usado por /ocr/receipt y el webhook de WhatsApp).
    image_base64: imagen en base64. Devuelve ReceiptResponse; lanza HTTPException."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="OCR no configurado en el servidor.")
    try:
        raw = base64.b64decode(image_base64, validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail="Imagen base64 inválida.")
    if len(raw) > 8 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Imagen demasiado grande (máx 8 MB).")

    payload = {
        "contents": [
            {"parts": [
                {"text": PROMPT},
                {"inlineData": {"mimeType": mime_type, "data": image_base64}},
            ]}
        ],
        "generationConfig": {"responseMimeType": "application/json"},
    }

    # Gemini flash da 503/429 transitorios bajo demanda: reintentar con backoff.
    resp = None
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            for attempt in range(3):
                resp = await client.post(GEMINI_URL, params={"key": api_key}, json=payload)
                if resp.status_code not in (429, 500, 502, 503, 504):
                    break
                if attempt < 2:
                    await asyncio.sleep(0.8 * (attempt + 1))
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Error contactando el servicio de OCR: {e}")

    if resp is None or resp.status_code != 200:
        raise HTTPException(
            status_code=503,
            detail="El servicio está ocupado ahora mismo. Inténtalo de nuevo.",
        )

    data = resp.json()
    # Gemini 3.x puede anteponer un part de "thoughtSignature" sin texto; buscar
    # el primer part con "text" en lugar de asumir el índice 0.
    try:
        parts = data["candidates"][0]["content"]["parts"]
        text = next(p["text"] for p in parts if "text" in p)
    except (KeyError, IndexError, StopIteration):
        raise HTTPException(status_code=422, detail="No se pudo extraer la información visual.")

    # Gemini a veces envuelve el JSON en ```json ... ```.
    if "```" in text:
        text = text.replace("```json", "").replace("```", "").strip()

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        raise HTTPException(status_code=422, detail="Respuesta de OCR no interpretable.")

    amount = parsed.get("amount")
    try:
        amount = float(amount) if amount is not None else None
    except (TypeError, ValueError):
        amount = None

    return ReceiptResponse(
        amount=amount,
        description=parsed.get("description"),
        date=parsed.get("date"),
    )


@router.post("/receipt", response_model=ReceiptResponse)
async def scan_receipt(body: ReceiptRequest, user=Depends(get_current_user)):
    """Recibe una imagen de recibo (base64) y devuelve los campos extraídos.
    Requiere JWT válido de Supabase."""
    return await scan_receipt_b64(body.image_base64, body.mime_type)
