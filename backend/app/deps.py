"""
Dependencias compartidas de FastAPI.

get_current_user valida el JWT de Supabase que la app envía en la cabecera
Authorization: Bearer <access_token>.

Supabase migró a JWT firmados con claves ASIMÉTRICAS (ES256) — el token ya no se
firma con el JWT Secret (HS256). Por eso se verifica la firma contra el JWKS
público del proyecto (…/auth/v1/.well-known/jwks.json), eligiendo la clave por
`kid`. Se mantiene un fallback HS256 con SUPABASE_JWT_SECRET para tokens legacy.
"""
import os

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient

bearer = HTTPBearer(auto_error=True)

# Secreto HS256 legacy (Project Settings → API → JWT Secret). Opcional ahora.
SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET", "")
# URL del proyecto Supabase, para localizar el JWKS de claves asimétricas.
SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")

# Cliente JWKS con cache interno (descarga las claves una vez y las reutiliza).
_jwk_client: PyJWKClient | None = None
if SUPABASE_URL:
    _jwk_client = PyJWKClient(f"{SUPABASE_URL}/auth/v1/.well-known/jwks.json")


class AuthUser:
    def __init__(self, user_id: str, email: str | None):
        self.id = user_id
        self.email = email


def _decode(token: str) -> dict:
    """
    Decodifica y verifica el token. Intenta ES256 (JWKS) según el `alg` del
    header; si es HS256 usa el secreto. Lanza jwt.InvalidTokenError si no valida.
    """
    header = jwt.get_unverified_header(token)
    alg = header.get("alg", "")

    if alg.startswith("ES") or alg.startswith("RS"):
        if _jwk_client is None:
            raise jwt.InvalidTokenError("JWKS no configurado (falta SUPABASE_URL).")
        signing_key = _jwk_client.get_signing_key_from_jwt(token)
        return jwt.decode(
            token,
            signing_key.key,
            algorithms=["ES256", "RS256"],
            audience="authenticated",
        )

    # Fallback HS256 (tokens legacy).
    if not SUPABASE_JWT_SECRET:
        raise jwt.InvalidTokenError("Sin secreto HS256 configurado.")
    return jwt.decode(
        token,
        SUPABASE_JWT_SECRET,
        algorithms=["HS256"],
        audience="authenticated",
    )


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer),
) -> AuthUser:
    if _jwk_client is None and not SUPABASE_JWT_SECRET:
        # Falla cerrado: sin forma de verificar identidad.
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Autenticación no configurada en el servidor.",
        )

    token = creds.credentials
    try:
        payload = _decode(token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expirado.")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Token inválido.")
    except Exception:
        # Errores al obtener/parsear el JWKS, etc.
        raise HTTPException(status_code=401, detail="No se pudo verificar el token.")

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Token sin identidad.")

    return AuthUser(user_id=user_id, email=payload.get("email"))
