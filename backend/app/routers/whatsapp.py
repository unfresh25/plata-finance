"""
Webhook de WhatsApp (Kapso) para registrar gastos por texto, voz o foto.

Flujo:
  1. El usuario genera un código en la app y lo manda por WhatsApp una vez →
     se canjea contra whatsapp_link_codes y se guarda el vínculo phone→cuenta.
  2. Los siguientes mensajes (texto / nota de voz transcrita / foto con caption)
     se interpretan con la IA de /parse y crean la transacción en el hogar.
  3. Se responde por WhatsApp confirmando.

Seguridad: se verifica la firma HMAC-SHA256 (X-Webhook-Signature) contra
KAPSO_WEBHOOK_SECRET sobre el cuerpo crudo.
"""
import hashlib
import hmac
import os
import re

import httpx
from fastapi import APIRouter, HTTPException, Request

from app.db import db
from app.routers.parse import ParseRequest, CategoryRef, AccountRef, parse_text_to_fields
from app.routers.chat import ChatMessage, chat_reply
from app.routers.ocr import scan_receipt_b64

router = APIRouter()

KAPSO_API = "https://api.kapso.ai/meta/whatsapp/v24.0"
ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-haiku-4-5")


def _verify_signature(raw: bytes, signature: str | None) -> bool:
    secret = os.environ.get("KAPSO_WEBHOOK_SECRET", "")
    if not secret:
        print("[whatsapp] WARNING: KAPSO_WEBHOOK_SECRET no configurado; se omite verificación")
        return True
    if not signature:
        print("[whatsapp] sin header de firma")
        return False
    sig = signature.split("=", 1)[-1].strip()   # tolera prefijo 'sha256='
    expected = hmac.new(secret.encode(), raw, hashlib.sha256).hexdigest()
    ok = hmac.compare_digest(expected, sig)
    if not ok:
        print(f"[whatsapp] firma no coincide (recibida {sig[:12]}…, esperada {expected[:12]}…)")
    return ok


async def _send_whatsapp(phone_number_id: str, to: str, text: str) -> None:
    api_key = os.environ.get("KAPSO_API_KEY", "")
    if not api_key:
        print("[whatsapp] KAPSO_API_KEY no configurado; no se puede responder")
        return
    if not phone_number_id:
        print("[whatsapp] phone_number_id vacío; no se puede responder")
        return
    # WhatsApp usa *negrita* (un asterisco) y _cursiva_, no el markdown de la app.
    text = _to_whatsapp_markdown(text)
    url = f"{KAPSO_API}/{phone_number_id}/messages"
    body = {"messaging_product": "whatsapp", "type": "text", "text": {"body": text}}
    # Identidad business-scoped (CO./US.) va en 'recipient'; un teléfono en 'to'.
    if to.startswith(("CO.", "US.")) or not to.isdigit():
        body["recipient"] = to
    else:
        body["to"] = to
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.post(url, headers={"X-API-Key": api_key, "Content-Type": "application/json"}, json=body)
            if r.status_code >= 300:
                print(f"[whatsapp] envío falló {r.status_code}: {r.text[:200]}")
            else:
                print(f"[whatsapp] respondido a {to} ok")
    except httpx.RequestError as e:
        print(f"[whatsapp] error de red al responder: {e}")


def _digits(phone: str) -> str:
    return re.sub(r"\D", "", phone or "")


def _to_whatsapp_markdown(text: str) -> str:
    """Convierte el markdown estándar al formato de WhatsApp: **negrita** → *negrita*,
    quita encabezados '#'. WhatsApp usa un solo asterisco para negrita."""
    if not text:
        return text
    text = re.sub(r"\*\*(.+?)\*\*", r"*\1*", text)   # **x** → *x*
    text = re.sub(r"^#{1,6}\s*", "", text, flags=re.MULTILINE)  # quita '# ' de headers
    return text


@router.post("/webhook")
async def whatsapp_webhook(request: Request):
    raw = await request.body()
    if not _verify_signature(raw, request.headers.get("X-Webhook-Signature")):
        raise HTTPException(status_code=401, detail="Firma inválida.")

    payload = await request.json()
    msg = payload.get("message") or {}
    conv = payload.get("conversation") or {}
    # Identidad estable del remitente: Kapso usa business-scoped user id (CO./US.)
    # cuando message.from viene vacío. Se usa como clave de vínculo y como
    # destinatario al responder.
    sender = (msg.get("from") or msg.get("from_user_id")
              or conv.get("phone_number") or "").strip()
    phone_number_id = payload.get("phone_number_id") or conv.get("phone_number_id", "")
    print(f"[whatsapp] evento type={msg.get('type')} sender={sender} pnid={phone_number_id}")
    if not sender:
        return {"ok": True}

    supa = db()

    # Idempotencia: si ya procesamos este message.id, no repetir (evita duplicados
    # por reintentos del webhook).
    msg_id = msg.get("id")
    if msg_id:
        dup = supa.table("whatsapp_processed").select("message_id").eq("message_id", msg_id).limit(1).execute()
        if dup.data:
            print(f"[whatsapp] mensaje {msg_id} ya procesado; se ignora")
            return {"ok": True}
        supa.table("whatsapp_processed").insert({"message_id": msg_id}).execute()

    # Texto efectivo del mensaje: cuerpo, transcript de voz o caption de imagen.
    kapso = msg.get("kapso") or {}
    mtype = msg.get("type")
    text = ""
    if mtype == "text":
        text = (msg.get("text") or {}).get("body", "")
    elif mtype == "audio":
        text = (kapso.get("transcript") or {}).get("text", "")
    elif mtype == "image":
        text = (msg.get("image") or {}).get("caption", "")
    text = (text or "").strip()

    code = _extract_code(text)
    link = supa.table("whatsapp_links").select("*").eq("phone", sender).limit(1).execute()
    linked = (link.data or [None])[0]

    # Si el mensaje ES un código de vinculación, procesarlo SIEMPRE (esté o no
    # vinculado ya), así nunca se interpreta un PLATA-XXXX como gasto.
    if code:
        row = supa.table("whatsapp_link_codes").select("*").eq("code", code).limit(1).execute()
        c = (row.data or [None])[0]
        if not c:
            if linked:
                await _send_whatsapp(phone_number_id, sender, "Tu WhatsApp ya está conectado a Plata ✅ Escríbeme un gasto o una pregunta.")
            else:
                await _send_whatsapp(phone_number_id, sender, "Ese código no es válido o expiró. Genera uno nuevo en Plata.")
            return {"ok": True}
        supa.table("whatsapp_links").upsert({
            "phone": sender, "user_id": c["user_id"], "household_id": c["household_id"],
        }, on_conflict="phone").execute()
        supa.table("whatsapp_link_codes").delete().eq("code", code).execute()
        await _send_whatsapp(phone_number_id, sender,
            "¡Listo! Tu WhatsApp quedó conectado a Plata 🎉\n\n"
            "• Registra: “almuerzo 25 mil” o mándame una nota de voz.\n"
            "• Pregunta: “¿cuánto llevo gastado este mes?”, “¿en qué gasto más?”, “¿me alcanza para X?”")
        return {"ok": True}

    if not linked:
        await _send_whatsapp(phone_number_id, sender,
            "Hola 👋 Para conectar tu WhatsApp con Plata, abre la app → Ajustes → Conectar WhatsApp y envíame el código que aparece.")
        return {"ok": True}

    # El hogar ACTUAL del usuario (por si se cambió a otro hogar en la app); el
    # vínculo guarda el hogar del momento de vincular, que puede estar desfasado.
    prof = supa.table("profiles").select("household_id").eq("id", linked["user_id"]).limit(1).execute()
    hh = (prof.data or [{}])[0].get("household_id") or linked["household_id"]
    # Mantén el vínculo al día si cambió de hogar.
    if hh != linked.get("household_id"):
        supa.table("whatsapp_links").update({"household_id": hh}).eq("phone", sender).execute()

    # Foto de recibo: descarga la imagen de Kapso y la pasa por OCR.
    if mtype == "image":
        media_url = kapso.get("media_url") or (kapso.get("media_data") or {}).get("url")
        if media_url:
            ocr = await _ocr_from_url(media_url)
            if ocr and ocr.amount:
                await _register_expense(supa, hh, linked["user_id"], phone_number_id, sender,
                                        amount=ocr.amount, description=ocr.description or "Recibo",
                                        date=ocr.date, category_id=None)
                return {"ok": True}
        await _send_whatsapp(phone_number_id, sender,
            "No pude leer el recibo 🧾 Prueba con más luz, o escríbeme el gasto (ej: “mercado 80 mil”).")
        return {"ok": True}

    if not text:
        await _send_whatsapp(phone_number_id, sender, "Mándame el gasto por texto o nota de voz, ej: “taxi 12 mil”.")
        return {"ok": True}

    # ¿Es una consulta/pregunta o un registro de gasto? Si es pregunta, responde
    # con el asistente (mismo cerebro que el chat de la app).
    if await _is_question(text):
        summary = _finance_summary(supa, hh)
        try:
            reply = await chat_reply(summary, [ChatMessage(role="user", content=text)])
        except Exception:
            reply = "No pude consultar eso ahora. Inténtalo de nuevo en un momento."
        await _send_whatsapp(phone_number_id, sender, reply)
        return {"ok": True}

    # Cargar categorías y cuentas del hogar para el parseo.
    cats = supa.table("categories").select("id,name,type").eq("household_id", hh).execute().data or []
    accs = supa.table("accounts").select("id,name").eq("household_id", hh).execute().data or []
    if not accs:
        await _send_whatsapp(phone_number_id, sender, "No tienes cuentas en Plata todavía. Crea una en la app primero.")
        return {"ok": True}

    parsed = await parse_text_to_fields(ParseRequest(
        text=text,
        categories=[CategoryRef(id=c["id"], name=c["name"], type=c["type"]) for c in cats],
        accounts=[AccountRef(id=a["id"], name=a["name"]) for a in accs],
    ))
    if not parsed.amount:
        await _send_whatsapp(phone_number_id, sender, "No entendí el monto 🤔 Prueba con algo como “mercado 80 mil”.")
        return {"ok": True}

    await _register_expense(supa, hh, linked["user_id"], phone_number_id, sender,
                            amount=parsed.amount, description=parsed.description,
                            date=parsed.date, category_id=parsed.category_id,
                            account_id=parsed.account_id, tx_type=parsed.type or "expense")
    return {"ok": True}


async def _register_expense(supa, hh, user_id, phone_number_id, sender, *,
                            amount, description, date, category_id,
                            account_id=None, tx_type="expense") -> None:
    """Inserta la transacción, ajusta el saldo y confirma por WhatsApp."""
    accs = supa.table("accounts").select("id,balance").eq("household_id", hh).execute().data or []
    if not accs:
        await _send_whatsapp(phone_number_id, sender, "No tienes cuentas en Plata todavía. Crea una en la app primero.")
        return
    acct = account_id or accs[0]["id"]
    supa.table("transactions").insert({
        "account_id": acct, "household_id": hh, "created_by": user_id,
        "amount": amount, "type": tx_type, "category_id": category_id,
        "description": description, "date": date, "split_mode": "shared",
    }).execute()
    if tx_type != "transfer":
        delta = amount if tx_type == "income" else -amount
        current = float(next((float(a.get("balance") or 0) for a in accs if a["id"] == acct), 0))
        supa.table("accounts").update({"balance": current + delta}).eq("id", acct).execute()
    signo = "+" if tx_type == "income" else "-"
    await _send_whatsapp(phone_number_id, sender,
        f"✅ Registrado: {description or 'movimiento'} {signo}${int(amount):,}".replace(",", "."))


async def _ocr_from_url(media_url: str):
    """Descarga la imagen de Kapso y la pasa por OCR. Devuelve ReceiptResponse o None."""
    import base64 as _b64
    api_key = os.environ.get("KAPSO_API_KEY", "")
    headers = {"X-API-Key": api_key} if api_key else {}
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            r = await client.get(media_url, headers=headers)
        if r.status_code != 200:
            print(f"[whatsapp] descarga de media falló {r.status_code}")
            return None
        b64 = _b64.b64encode(r.content).decode()
        ctype = r.headers.get("content-type", "image/jpeg").split(";")[0]
        return await scan_receipt_b64(b64, ctype)
    except Exception as e:
        print(f"[whatsapp] OCR falló: {e}")
        return None


async def _is_question(text: str) -> bool:
    """Clasifica si el mensaje es una CONSULTA (pregunta sobre finanzas) o un
    REGISTRO de gasto/ingreso. Llamada corta a Claude; ante duda, asume registro
    (lo más frecuente) salvo señales claras de pregunta."""
    low = text.lower().strip()
    if "?" in text or low.startswith((
        "cuanto", "cuánto", "que ", "qué ", "como ", "cómo", "cuando", "cuándo",
        "en que", "en qué", "me alcanza", "puedo", "cuales", "cuáles", "muestra",
        "dime", "resumen", "hay ", "tengo", "saldo", "balance",
    )):
        return True
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return False
    payload = {
        "model": ANTHROPIC_MODEL, "max_tokens": 5,
        "messages": [{"role": "user", "content":
            "Clasifica este mensaje de una app de finanzas. Responde SOLO una "
            "palabra: PREGUNTA (si es una consulta sobre sus finanzas) o REGISTRO "
            f"(si describe un gasto o ingreso para anotar).\nMensaje: {text}"}],
    }
    headers = {"x-api-key": api_key, "anthropic-version": "2023-06-01", "content-type": "application/json"}
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.post(ANTHROPIC_URL, headers=headers, json=payload)
        if r.status_code == 200:
            out = "".join(b.get("text", "") for b in r.json().get("content", [])).upper()
            return "PREGUNTA" in out
    except httpx.RequestError:
        pass
    return False


def _co(v) -> str:
    """Formatea un monto en pesos colombianos: $1.234.567 (punto de miles)."""
    return "$" + f"{float(v or 0):,.0f}".replace(",", ".")


def _finance_summary(supa, household_id: str) -> str:
    """Arma un resumen financiero del hogar en texto para el asistente (equivalente
    server-side de financeSummaryForChat de la app)."""
    accs = supa.table("accounts").select("name,type,balance").eq("household_id", household_id).execute().data or []
    from datetime import date
    month = date.today().strftime("%Y-%m")
    txs = (supa.table("transactions").select("amount,type,category_id,date,description")
           .eq("household_id", household_id).gte("date", month + "-01").execute().data or [])
    cats = supa.table("categories").select("id,name").eq("household_id", household_id).execute().data or []
    cat_name = {c["id"]: c["name"] for c in cats}
    budgets = supa.table("budgets").select("category_id,amount").eq("household_id", household_id).execute().data or []
    goals = supa.table("savings_goals").select("name,target_amount,current_amount,status").eq("household_id", household_id).execute().data or []

    total = sum(float(a.get("balance") or 0) for a in accs)
    income = sum(float(t["amount"]) for t in txs if t.get("type") == "income")
    expense = sum(float(t["amount"]) for t in txs if t.get("type") == "expense")
    lines = [f"BALANCE TOTAL: {_co(total)}",
             f"Este mes — ingresos: {_co(income)}, gastos: {_co(expense)}", "", "CUENTAS:"]
    for a in accs:
        lines.append(f"- {a['name']} ({a.get('type','')}): {_co(a.get('balance'))}")
    by_cat: dict[str, float] = {}
    for t in txs:
        if t.get("type") == "expense":
            by_cat[cat_name.get(t.get("category_id"), "Sin categoría")] = by_cat.get(cat_name.get(t.get("category_id"), "Sin categoría"), 0) + float(t["amount"])
    if by_cat:
        lines.append("")
        lines.append("GASTO DEL MES POR CATEGORÍA:")
        for n, v in sorted(by_cat.items(), key=lambda x: -x[1])[:12]:
            lines.append(f"- {n}: {_co(v)}")
    if budgets:
        lines.append("")
        lines.append("PRESUPUESTOS:")
        for b in budgets:
            lines.append(f"- {cat_name.get(b['category_id'],'General')}: límite {_co(b['amount'])}")
    if goals:
        lines.append("")
        lines.append("METAS DE AHORRO:")
        for g in goals:
            lines.append(f"- {g['name']}: {_co(g.get('current_amount'))} de {_co(g.get('target_amount'))} ({g.get('status','')})")
    return "\n".join(lines)


def _extract_code(text: str) -> str | None:
    if not text:
        return None
    m = re.search(r"PLATA[-\s]?([A-Z0-9]{4,8})", text.upper())
    if m:
        return "PLATA-" + m.group(1)
    return None
