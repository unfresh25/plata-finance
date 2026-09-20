import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import predictions, insights, ocr, parse, chat, bank, weekly

app = FastAPI(
    title="Plata Finance API",
    description="OCR, predicciones e insights para Plata Finance",
    version="1.0.0",
)

# La app móvil (React Native) no aplica CORS; esto solo afecta llamadas desde
# la web. Orígenes configurables por ALLOWED_ORIGINS (separados por coma).
_default_origins = "http://localhost:3000"
_allowed = [o.strip() for o in os.environ.get("ALLOWED_ORIGINS", _default_origins).split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(predictions.router, prefix="/predictions", tags=["predictions"])
app.include_router(insights.router, prefix="/insights", tags=["insights"])
app.include_router(ocr.router, prefix="/ocr", tags=["ocr"])
app.include_router(parse.router, prefix="/parse", tags=["parse"])
app.include_router(chat.router, prefix="/chat", tags=["chat"])
app.include_router(bank.router, prefix="/bank", tags=["bank"])
app.include_router(weekly.router, prefix="/weekly", tags=["weekly"])


@app.get("/health")
async def health():
    return {"status": "ok", "service": "plata-finance-api"}
