"""
Dependencias compartidas de FastAPI.

get_current_user valida el JWT de Supabase que la app envía en la cabecera
Authorization: Bearer <access_token>. Con esto los endpoints dejan de aceptar
un household_id arbitrario sin identidad (IDOR); el usuario queda autenticado
y el household debe derivarse de su identidad, no de un parámetro libre.
"""
import os

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

bearer = HTTPBearer(auto_error=True)

# Secreto de firma del JWT de Supabase (Project Settings → API → JWT Secret).
SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET", "")


class AuthUser:
    def __init__(self, user_id: str, email: str | None):
        self.id = user_id
        self.email = email


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer),
) -> AuthUser:
    if not SUPABASE_JWT_SECRET:
        # Falla cerrado: sin secreto configurado no se puede verificar identidad.
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Autenticación no configurada en el servidor.",
        )

    token = creds.credentials
    try:
        payload = jwt.decode(
            token,
            SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expirado.")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Token inválido.")

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Token sin identidad.")

    return AuthUser(user_id=user_id, email=payload.get("email"))
