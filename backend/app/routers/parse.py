"""
Parseo de un movimiento dictado por voz — ejecutado server-side con Claude.

La app transcribe la voz on-device (Speech framework) y manda el texto plano
junto con las categorías y cuentas del hogar. Claude Haiku interpreta lenguaje
natural ("gasté cincuenta mil en el mercado con la débito", "ayer", etc.) y
devuelve los campos del formulario, haciendo match del category_id / account_id
contra las listas provistas. La app precarga el formulario; el usuario confirma
antes de guardar.

Se usa Claude (no Gemini) porque el nivel gratuito de Gemini se agota rápido
(~20 requests/día). Claude Haiku no tiene ese límite y cuesta ~$0.001 por dictado.
"""
import asyncio
import json
import os
from datetime import date

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.deps import get_current_user

router = APIRouter()

ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-haiku-4-5")


class CategoryRef(BaseModel):
    id: str
    name: str
    type: str  # "income" | "expense"


class AccountRef(BaseModel):
    id: str
    name: str


class ParseRequest(BaseModel):
    text: str
    categories: list[CategoryRef] = []
    accounts: list[AccountRef] = []
    # Fecha "hoy" del cliente (YYYY-MM-DD) para resolver "ayer", "el lunes", etc.
    today: str | None = None


class ParseResponse(BaseModel):
    amount: float | None = None
    type: str | None = None          # income | expense | transfer
    description: str | None = None
    date: str | None = None          # YYYY-MM-DD
    category_id: str | None = None
    account_id: str | None = None


def _build_prompt(body: ParseRequest) -> str:
    today = body.today or date.today().isoformat()
    cats = "\n".join(f'- id={c.id} | "{c.name}" ({c.type})' for c in body.categories) or "(ninguna)"
    accs = "\n".join(f'- id={a.id} | "{a.name}"' for a in body.accounts) or "(ninguna)"
    return (
        "Eres un asistente de finanzas para una app de pareja en Colombia. "
        "El usuario dictó por voz un movimiento. Interpreta el texto y responde "
        "ÚNICAMENTE con un JSON válido (sin markdown, sin explicación) con estos campos:\n"
        '  "amount": número sin signos ni separadores (ej. 50000). Interpreta '
        'lenguaje natural: "cincuenta mil" = 50000, "50 lucas"/"50 mil" = 50000, '
        '"2.5 millones" = 2500000.\n'
        '  "type": "expense" | "income" | "transfer". Por defecto "expense" salvo '
        "que el texto indique un ingreso (me pagaron, sueldo, me llegó) o una "
        "transferencia entre cuentas propias.\n"
        '  "description": resumen corto del gasto/ingreso (ej. "Mercado", "Sueldo").\n'
        f'  "date": fecha en formato YYYY-MM-DD. Hoy es {today}. Resuelve "ayer", '
        '"antier", "el lunes", etc. relativo a hoy. Si no se menciona, usa hoy.\n'
        '  "category_id": el id EXACTO de la categoría que mejor corresponda de la '
        "lista de abajo (respeta el tipo income/expense). null si ninguna encaja.\n"
        '  "account_id": el id EXACTO de la cuenta mencionada de la lista de abajo. '
        "null si no se menciona ninguna.\n\n"
        f"Categorías del hogar:\n{cats}\n\n"
        f"Cuentas del hogar:\n{accs}\n\n"
        f'Texto dictado: "{body.text}"'
    )


async def parse_text_to_fields(body: ParseRequest) -> ParseResponse:
    """Núcleo reutilizable: texto → campos del movimiento (usado por /parse y el
    webhook de WhatsApp). Devuelve ParseResponse; lanza HTTPException en error."""
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="No se recibió texto para interpretar.")
    if len(text) > 2000:
        raise HTTPException(status_code=413, detail="El texto es demasiado largo.")
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="El parseo no está configurado en el servidor.")
    payload = {
        "model": ANTHROPIC_MODEL, "max_tokens": 400,
        "messages": [{"role": "user", "content": _build_prompt(body)}],
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
        raise HTTPException(status_code=503, detail="El asistente está ocupado ahora mismo. Inténtalo de nuevo.")
    data = resp.json()
    try:
        raw = data["content"][0]["text"]
    except (KeyError, IndexError):
        raise HTTPException(status_code=422, detail="No se pudo interpretar el dictado.")
    if "```" in raw:
        raw = raw.replace("```json", "").replace("```", "").strip()
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        raise HTTPException(status_code=422, detail="Respuesta no interpretable.")
    amount = parsed.get("amount")
    try:
        amount = float(amount) if amount is not None else None
    except (TypeError, ValueError):
        amount = None
    if amount is not None and amount <= 0:
        amount = None
    tx_type = parsed.get("type")
    if tx_type not in ("income", "expense", "transfer"):
        tx_type = "expense"
    valid_cat_ids = {c.id for c in body.categories}
    valid_acc_ids = {a.id for a in body.accounts}
    category_id = parsed.get("category_id")
    account_id = parsed.get("account_id")
    if category_id not in valid_cat_ids:
        category_id = None
    if account_id not in valid_acc_ids:
        account_id = None
    return ParseResponse(
        amount=amount, type=tx_type, description=parsed.get("description"),
        date=parsed.get("date"), category_id=category_id, account_id=account_id,
    )


@router.post("/transaction", response_model=ParseResponse)
async def parse_transaction(
    body: ParseRequest,
    user=Depends(get_current_user),
):
    """
    Recibe el texto dictado + categorías/cuentas del hogar y devuelve los campos
    del movimiento. Requiere JWT válido de Supabase.
    """
    return await parse_text_to_fields(body)


async def _parse_transaction_legacy(body: ParseRequest):
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="No se recibió texto para interpretar.")
    if len(text) > 2000:
        raise HTTPException(status_code=413, detail="El texto es demasiado largo.")

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="El parseo no está configurado en el servidor.")

    payload = {
        "model": ANTHROPIC_MODEL,
        "max_tokens": 400,
        "messages": [{"role": "user", "content": _build_prompt(body)}],
    }
    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }

    # Reintento ante 429/5xx transitorios.
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
        raise HTTPException(
            status_code=503,
            detail="El asistente está ocupado ahora mismo. Inténtalo de nuevo.",
        )

    data = resp.json()
    try:
        raw = data["content"][0]["text"]
    except (KeyError, IndexError):
        raise HTTPException(status_code=422, detail="No se pudo interpretar el dictado.")

    # Claude a veces envuelve el JSON en ```json ... ```.
    if "```" in raw:
        raw = raw.replace("```json", "").replace("```", "").strip()

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        raise HTTPException(status_code=422, detail="Respuesta no interpretable.")

    # Normalización + validación defensiva.
    amount = parsed.get("amount")
    try:
        amount = float(amount) if amount is not None else None
    except (TypeError, ValueError):
        amount = None
    if amount is not None and amount <= 0:
        amount = None

    tx_type = parsed.get("type")
    if tx_type not in ("income", "expense", "transfer"):
        tx_type = "expense"

    # Solo devolver ids que existan de verdad en las listas provistas.
    valid_cat_ids = {c.id for c in body.categories}
    valid_acc_ids = {a.id for a in body.accounts}
    category_id = parsed.get("category_id")
    account_id = parsed.get("account_id")
    if category_id not in valid_cat_ids:
        category_id = None
    if account_id not in valid_acc_ids:
        account_id = None

    return ParseResponse(
        amount=amount,
        type=tx_type,
        description=parsed.get("description"),
        date=parsed.get("date"),
        category_id=category_id,
        account_id=account_id,
    )
