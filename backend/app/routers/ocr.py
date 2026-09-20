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

# OCR con Claude (visión), igual que el resto del backend — evita el límite bajo
# del nivel gratuito de Gemini y unifica en un solo proveedor.
ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-haiku-4-5")

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
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="OCR no configurado en el servidor.")
    try:
        raw = base64.b64decode(image_base64, validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail="Imagen base64 inválida.")
    if len(raw) > 8 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Imagen demasiado grande (máx 8 MB).")

    media_type = mime_type if mime_type in (
        "image/jpeg", "image/png", "image/gif", "image/webp") else "image/jpeg"
    payload = {
        "model": ANTHROPIC_MODEL,
        "max_tokens": 300,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "image", "source": {
                    "type": "base64", "media_type": media_type, "data": image_base64}},
                {"type": "text", "text": PROMPT},
            ],
        }],
    }
    headers = {"x-api-key": api_key, "anthropic-version": "2023-06-01", "content-type": "application/json"}

    resp = None
    try:
        async with httpx.AsyncClient(timeout=40.0) as client:
            for attempt in range(3):
                resp = await client.post(ANTHROPIC_URL, headers=headers, json=payload)
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
    try:
        text = "".join(b.get("text", "") for b in data.get("content", []) if b.get("type") == "text").strip()
    except (KeyError, AttributeError):
        raise HTTPException(status_code=422, detail="No se pudo extraer la información visual.")

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
