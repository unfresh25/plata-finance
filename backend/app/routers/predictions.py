from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import Optional
import os

router = APIRouter()

# ─── Schemas ─────────────────────────────────────────────────────────────────

class MonthlySpendPrediction(BaseModel):
    household_id: str
    month: str
    predicted_spend: float
    confidence: float
    trend: str  # 'up' | 'down' | 'stable'


class CategoryPrediction(BaseModel):
    category_id: str
    category_name: str
    predicted_spend: float
    trend: str


class TrendResponse(BaseModel):
    months: list[str]
    actual: list[float]
    predicted: list[float]


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.get("/monthly-spend", response_model=MonthlySpendPrediction)
async def get_monthly_spend_prediction(
    household_id: str = Query(..., description="Household UUID"),
    month: Optional[str] = Query(None, description="YYYY-MM, defaults to current month"),
):
    """
    Predict total spend for the current month using Prophet.
    Requires at least 3 months of transaction history.
    """
    from datetime import datetime
    if not month:
        month = datetime.now().strftime("%Y-%m")

    # TODO: pull transaction history from Supabase, train Prophet model
    # For now returns a placeholder until sufficient data is available
    return MonthlySpendPrediction(
        household_id=household_id,
        month=month,
        predicted_spend=0.0,
        confidence=0.0,
        trend="stable",
    )


@router.get("/by-category", response_model=list[CategoryPrediction])
async def get_category_predictions(
    household_id: str = Query(..., description="Household UUID"),
):
    """
    Predict spend per category using linear regression for categories
    with < 6 months of data, or Prophet for categories with 6+ months.
    """
    # TODO: implement per-category prediction
    return []


@router.get("/trend", response_model=TrendResponse)
async def get_trend(
    household_id: str = Query(..., description="Household UUID"),
    months_back: int = Query(6, ge=1, le=24),
):
    """
    Return last N months of actual spend + 1 month projection.
    """
    # TODO: implement trend calculation
    return TrendResponse(months=[], actual=[], predicted=[])
