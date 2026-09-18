"""
Chat con IA sobre las finanzas del hogar — ejecutado server-side con Claude.

La app arma un resumen precomputado de las finanzas del hogar (balances, gastos
del mes por categoría, deudas, metas, últimos movimientos) y lo manda como
`context` junto con el historial de la conversación (`messages`). Claude responde
como asistente financiero de pareja, en español colombiano, conciso y útil.

Se usa Claude (no Gemini) por el mismo motivo que /parse: sin el límite del free
tier de Gemini. Reutiliza el mismo patrón httpx + reintento.
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
    "Eres Plata, el asistente financiero de una app de finanzas para parejas en "
    "Colombia. Respondes sobre las finanzas del hogar del usuario usando el "
    "RESUMEN que se te da como única fuente de datos. Reglas:\n"
    "- Español colombiano, cercano y claro. Trata al usuario de tú.\n"
    "- Conciso: respuestas cortas, directas, accionables. Nada de párrafos largos.\n"
    "- Usa cifras del resumen; formatea montos con separador de miles y el símbolo "
    "de la moneda indicada. No inventes datos que no estén en el resumen.\n"
    "- Si te preguntan algo que no está en el resumen, dilo y sugiere qué registrar.\n"
    "- Puedes dar consejos simples de ahorro/presupuesto, pero sin lenguaje de "
    "asesor financiero formal ni disclaimers largos.\n"
    "- Habla en plural cuando aplique (es un hogar de pareja): 'gastaron', 'tienen'."
)


class ChatMessage(BaseModel):
    role: str   # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    context: str                      # resumen financiero del hogar (texto)
    messages: list[ChatMessage]       # historial de la conversación (incluye la última)


class ChatResponse(BaseModel):
    reply: str


@router.post("/ask", response_model=ChatResponse)
async def chat_ask(
    body: ChatRequest,
    user=Depends(get_current_user),
):
    """
    Recibe el resumen del hogar + el historial de la conversación y devuelve la
    respuesta del asistente. Requiere JWT válido de Supabase.
    """
    if not body.messages:
        raise HTTPException(status_code=400, detail="No hay mensajes en la conversación.")
    if len(body.context) > 20000:
        raise HTTPException(status_code=413, detail="El contexto es demasiado grande.")

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="El chat no está configurado en el servidor.")

    # El resumen va como primer turno de contexto (system + un bloque de datos).
    system = SYSTEM_PROMPT + "\n\nRESUMEN DE LAS FINANZAS DEL HOGAR:\n" + body.context

    # Solo se envían roles válidos y se limita el historial para acotar tokens.
    history = [
        {"role": m.role, "content": m.content}
        for m in body.messages[-20:]
        if m.role in ("user", "assistant") and m.content.strip()
    ]
    if not history:
        raise HTTPException(status_code=400, detail="Conversación vacía.")

    # Prompt caching: el system (prompt + resumen del hogar) se repite en cada
    # turno del hilo. Marcándolo con cache_control se cachea (~5 min) y los turnos
    # siguientes de la conversación pagan ~10% por esos tokens de entrada.
    payload = {
        "model": ANTHROPIC_MODEL,
        "max_tokens": 700,
        "system": [
            {"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}
        ],
        "messages": history,
    }
    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }

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
        raise HTTPException(
            status_code=503,
            detail="El asistente está ocupado ahora mismo. Inténtalo de nuevo.",
        )

    data = resp.json()
    try:
        # Concatena todos los bloques de texto de la respuesta.
        parts = [b.get("text", "") for b in data.get("content", []) if b.get("type") == "text"]
        reply = "".join(parts).strip()
    except (KeyError, IndexError, AttributeError):
        raise HTTPException(status_code=422, detail="Respuesta no interpretable.")

    if not reply:
        raise HTTPException(status_code=422, detail="El asistente no devolvió respuesta.")

    return ChatResponse(reply=reply)
