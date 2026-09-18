"""
Cliente de la API de Syncfy (Paybook Sync) — Open Data.

Host: https://opendata-api.syncfy.com/v1/
Auth: la api_key (o el token de sesión) va como parámetro `api_key`/`token`
(query en GET, body en POST), NO como header. Todas las respuestas vienen en un
envelope { code, status, response, ... }; aquí se devuelve ya el `response`.

La api_key vive SOLO en el servidor (env SYNCFY_API_KEY). El token de sesión es
temporal (expira ~5 min de inactividad) y se genera por usuario bajo demanda.

Verificado contra los repos oficiales Paybook/sync-rest, sync-py, sync-js y
probado contra el sandbox.
"""
import os

import httpx

BASE = os.environ.get("SYNCFY_BASE_URL", "https://opendata-api.syncfy.com/v1")


class SyncfyError(Exception):
    def __init__(self, message: str, code: int | None = None):
        super().__init__(message)
        self.message = message
        self.code = code


def _api_key() -> str:
    key = os.environ.get("SYNCFY_API_KEY", "")
    if not key:
        raise SyncfyError("SYNCFY_API_KEY no configurada en el servidor.")
    return key


def _unwrap(resp: httpx.Response) -> object:
    """Extrae `response` del envelope de Syncfy o lanza SyncfyError."""
    try:
        data = resp.json()
    except Exception:
        raise SyncfyError(f"Respuesta no-JSON de Syncfy (HTTP {resp.status_code}).")
    code = data.get("code")
    if not data.get("status") or (code is not None and code >= 400):
        msg = data.get("message") or (data.get("errors") or "Error de Syncfy")
        raise SyncfyError(str(msg), code=code)
    return data.get("response")


async def _get(client: httpx.AsyncClient, path: str, params: dict) -> object:
    r = await client.get(f"{BASE}{path}", params=params)
    return _unwrap(r)


async def _post(client: httpx.AsyncClient, path: str, body: dict) -> object:
    r = await client.post(f"{BASE}{path}", json=body)
    return _unwrap(r)


# ─── Usuarios (api_key) ──────────────────────────────────────────────────────

async def create_user(name: str, id_external: str) -> str:
    """Crea un usuario Syncfy y devuelve su id_user."""
    async with httpx.AsyncClient(timeout=30.0) as c:
        resp = await _post(c, "/users", {
            "api_key": _api_key(), "name": name, "id_external": id_external,
        })
    return resp["id_user"]  # type: ignore[index]


# ─── Sesión (api_key → token temporal para un id_user) ───────────────────────

async def create_session(id_user: str) -> str:
    async with httpx.AsyncClient(timeout=30.0) as c:
        resp = await _post(c, "/sessions", {"api_key": _api_key(), "id_user": id_user})
    return resp["token"]  # type: ignore[index]


# ─── Catálogo (token) ────────────────────────────────────────────────────────

async def countries(token: str) -> list:
    async with httpx.AsyncClient(timeout=30.0) as c:
        return await _get(c, "/catalogues/countries", {"token": token})  # type: ignore[return-value]


async def sites(token: str, id_country: str | None = None, is_test: bool = False) -> list:
    params: dict = {"token": token}
    if id_country:
        params["id_country"] = id_country
    if is_test:
        params["is_test"] = "true"
    async with httpx.AsyncClient(timeout=30.0) as c:
        return await _get(c, "/catalogues/sites", params)  # type: ignore[return-value]


# ─── Credenciales / jobs / accounts / transactions (token) ───────────────────

async def create_credential(token: str, endpoint: str, id_site: str, credentials: dict) -> dict:
    """Crea (o actualiza/re-sync) una credencial. `endpoint` viene del site."""
    async with httpx.AsyncClient(timeout=45.0) as c:
        return await _post(c, endpoint, {  # type: ignore[return-value]
            "token": token, "id_site": id_site, "credentials": credentials,
        })


async def job_status(token: str, id_job: str) -> list:
    async with httpx.AsyncClient(timeout=30.0) as c:
        return await _get(c, f"/jobs/{id_job}/status", {"token": token})  # type: ignore[return-value]


async def answer_twofa(token: str, id_job: str, twofa: dict) -> object:
    async with httpx.AsyncClient(timeout=30.0) as c:
        return await _post(c, f"/jobs/{id_job}/twofa", {"token": token, "twofa": twofa})


async def accounts(token: str, id_credential: str) -> list:
    async with httpx.AsyncClient(timeout=30.0) as c:
        return await _get(c, "/accounts", {"token": token, "id_credential": id_credential})  # type: ignore[return-value]


async def transactions(token: str, id_credential: str, dt_refresh_from: int | None = None) -> list:
    params: dict = {"token": token, "id_credential": id_credential}
    if dt_refresh_from is not None:
        params["dt_refresh_from"] = dt_refresh_from
    async with httpx.AsyncClient(timeout=45.0) as c:
        return await _get(c, "/transactions", params)  # type: ignore[return-value]


async def delete_credential(token: str, id_credential: str) -> None:
    async with httpx.AsyncClient(timeout=30.0) as c:
        r = await c.request("DELETE", f"{BASE}/credentials/{id_credential}", params={"token": token})
        _unwrap(r)
