"""
Cliente Supabase server-side (service_role) para el backend.

Se usa SOLO en el servidor, con la SERVICE_ROLE_KEY, para leer/escribir las tablas
de Syncfy (bank_connections, bank_accounts, bank_transactions) saltando RLS. La
app cliente sigue leyendo bajo RLS con la anon key; el backend nunca expone esta
clave.
"""
import os
from functools import lru_cache

from supabase import Client, create_client


@lru_cache(maxsize=1)
def db() -> Client:
    url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        raise RuntimeError("Falta SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY.")
    return create_client(url, key)
