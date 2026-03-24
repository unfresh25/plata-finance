from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import predictions, insights

app = FastAPI(
    title="Jojo's Finance API",
    description="AI predictions and insights for Jojo's Finance",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://jojos-finance.vercel.app"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(predictions.router, prefix="/predictions", tags=["predictions"])
app.include_router(insights.router, prefix="/insights", tags=["insights"])


@app.get("/health")
async def health():
    return {"status": "ok", "service": "jojos-finance-ai"}
