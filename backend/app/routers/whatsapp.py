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

router = APIRouter()

KAPSO_API = "https://api.kapso.ai/meta/whatsapp/v24.0"


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

    # ¿Es un código de vinculación? (formato PLATA-XXXX o solo el código).
    code = _extract_code(text)
    link = supa.table("whatsapp_links").select("*").eq("phone", sender).limit(1).execute()
    linked = (link.data or [None])[0]

    if not linked:
        if code:
            row = supa.table("whatsapp_link_codes").select("*").eq("code", code).limit(1).execute()
            c = (row.data or [None])[0]
            if not c:
                await _send_whatsapp(phone_number_id, sender, "Ese código no es válido o expiró. Genera uno nuevo en Plata.")
                return {"ok": True}
            supa.table("whatsapp_links").upsert({
                "phone": sender, "user_id": c["user_id"], "household_id": c["household_id"],
            }, on_conflict="phone").execute()
            supa.table("whatsapp_link_codes").delete().eq("code", code).execute()
            await _send_whatsapp(phone_number_id, sender,
                "¡Listo! Tu WhatsApp quedó conectado a Plata. Escríbeme un gasto como “almuerzo 25 mil” y lo registro.")
            return {"ok": True}
        await _send_whatsapp(phone_number_id, sender,
            "Hola 👋 Para conectar tu WhatsApp con Plata, abre la app → Ajustes → Conectar WhatsApp y envíame el código que aparece.")
        return {"ok": True}

    if not text:
        await _send_whatsapp(phone_number_id, sender, "Mándame el gasto por texto o nota de voz, ej: “taxi 12 mil”.")
        return {"ok": True}

    # Cargar categorías y cuentas del hogar para el parseo.
    hh = linked["household_id"]
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

    account_id = parsed.account_id or accs[0]["id"]
    supa.table("transactions").insert({
        "account_id": account_id, "household_id": hh, "created_by": linked["user_id"],
        "amount": parsed.amount, "type": parsed.type or "expense",
        "category_id": parsed.category_id, "description": parsed.description,
        "date": parsed.date, "split_mode": "shared",
    }).execute()
    # Ajuste de saldo con UPDATE directo (service_role): el RPC apply_account_delta
    # depende de auth.uid() y no aplica desde el backend.
    if (parsed.type or "expense") != "transfer":
        delta = parsed.amount if parsed.type == "income" else -parsed.amount
        acc = supa.table("accounts").select("balance").eq("id", account_id).limit(1).execute()
        current = float((acc.data or [{}])[0].get("balance") or 0)
        supa.table("accounts").update({"balance": current + delta}).eq("id", account_id).execute()

    signo = "+" if parsed.type == "income" else "-"
    await _send_whatsapp(phone_number_id, sender,
        f"✅ Registrado: {parsed.description or 'movimiento'} {signo}${int(parsed.amount):,}".replace(",", "."))
    return {"ok": True}


def _extract_code(text: str) -> str | None:
    if not text:
        return None
    m = re.search(r"PLATA[-\s]?([A-Z0-9]{4,8})", text.upper())
    if m:
        return "PLATA-" + m.group(1)
    return None
