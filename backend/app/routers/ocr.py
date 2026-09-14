"""
OCR de recibos con Gemini — ejecutado server-side.

Mueve la clave de Gemini fuera del cliente móvil: la app ya no habla directo
con generativelanguage.googleapis.com (donde la key quedaba embebida en el
bundle y era extraíble). En su lugar llama a este endpoint autenticado, que
usa la key desde el entorno del servidor.
"""
import base64
import json
import os

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.deps import get_current_user

router = APIRouter()

GEMINI_MODEL = "gemini-2.5-flash"
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


@router.post("/receipt", response_model=ReceiptResponse)
async def scan_receipt(
    body: ReceiptRequest,
    user=Depends(get_current_user),
):
    """
    Recibe una imagen de recibo (base64) y devuelve los campos extraídos.
    Requiere un JWT válido de Supabase (cabecera Authorization: Bearer <token>).
    """
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="OCR no configurado en el servidor.")

    # Validar que el payload sea base64 decodificable y de tamaño razonable (<8 MB).
    try:
        raw = base64.b64decode(body.image_base64, validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail="Imagen base64 inválida.")
    if len(raw) > 8 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Imagen demasiado grande (máx 8 MB).")

    payload = {
        "contents": [
            {
                "parts": [
                    {"text": PROMPT},
                    {"inlineData": {"mimeType": body.mime_type, "data": body.image_base64}},
                ]
            }
        ],
        "generationConfig": {"responseMimeType": "application/json"},
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                GEMINI_URL,
                params={"key": api_key},
                json=payload,
            )
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Error contactando el servicio de OCR: {e}")

    if resp.status_code != 200:
        raise HTTPException(status_code=502, detail="El servicio de OCR devolvió un error.")

    data = resp.json()
    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError):
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
