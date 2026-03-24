from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import Optional
import os

router = APIRouter()

# ─── Schemas ─────────────────────────────────────────────────────────────────

class NarrativeRequest(BaseModel):
    household_id: str
    data_summary: dict  # Structured financial data to rewrite in natural language
    language: str = "es"  # 'es' | 'en'


class NarrativeResponse(BaseModel):
    text: str
    model: str = "gemma"


class MonthlyReportRequest(BaseModel):
    household_id: str
    month: str  # YYYY-MM
    language: str = "es"


class AnomalyAlert(BaseModel):
    category_id: str
    category_name: str
    usual_spend: float
    current_spend: float
    percentage_over: float
    message: str


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/narrative", response_model=NarrativeResponse)
async def generate_narrative(request: NarrativeRequest):
    """
    Use Gemma (Google) to rewrite a structured financial summary
    into natural language. Used sparingly for monthly reports and alerts.
    """
    # TODO: integrate with Gemma API (google-generativeai SDK)
    # Prompt: "Reescribe este resumen financiero en lenguaje natural amigable: {data_summary}"
    return NarrativeResponse(
        text="El análisis del mes estará disponible cuando tengas más transacciones.",
        model="gemma-placeholder",
    )


@router.post("/monthly-report", response_model=NarrativeResponse)
async def generate_monthly_report(request: MonthlyReportRequest):
    """
    Auto-generate a monthly financial report using Gemma.
    Called by a cron job on the 1st of each month.
    """
    # TODO: fetch month data from Supabase, build prompt, call Gemma
    return NarrativeResponse(
        text="Reporte mensual no disponible todavía.",
        model="gemma-placeholder",
    )


@router.get("/anomalies", response_model=list[AnomalyAlert])
async def get_anomalies(
    household_id: str = Query(...),
    threshold: float = Query(0.8, description="Fraction of budget that triggers alert"),
):
    """
    Detect categories where current month spend exceeds `threshold * budget`.
    No LLM required — pure numerical detection.
    """
    # TODO: fetch budgets + current month spend from Supabase and compare
    return []
