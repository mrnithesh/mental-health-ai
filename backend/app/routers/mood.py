from fastapi import APIRouter, Depends, HTTPException
from datetime import datetime

from ..dependencies import get_current_user, CurrentUser
from ..models.schemas import (
    MoodAnalysisRequest,
    MoodAnalysisResponse,
    MoodSummary,
    MoodPeriod,
    MoodTrend,
)
from ..services.gemini_service import get_gemini_service
from ..services.firestore_service import get_firestore_service

router = APIRouter()


def calculate_trend(moods: list) -> MoodTrend:
    """Calculate mood trend based on score progression."""
    if len(moods) < 2:
        return MoodTrend.stable
    
    # Compare first half average to second half average
    mid = len(moods) // 2
    first_half = moods[:mid]
    second_half = moods[mid:]
    
    first_avg = sum(m["score"] for m in first_half) / len(first_half)
    second_avg = sum(m["score"] for m in second_half) / len(second_half)
    
    diff = second_avg - first_avg
    
    if diff > 0.3:
        return MoodTrend.improving
    elif diff < -0.3:
        return MoodTrend.declining
    else:
        return MoodTrend.stable


@router.post("/analysis", response_model=MoodAnalysisResponse)
async def analyze_mood_patterns(
    request: MoodAnalysisRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """
    Analyze mood patterns over a specified date range.
    
    Returns statistical summary and AI-generated insights about
    mood patterns and trends.
    """
    # Parse dates
    try:
        start_date = datetime.fromisoformat(request.start_date)
        end_date = datetime.fromisoformat(request.end_date)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Invalid date format. Use YYYY-MM-DD.",
        )
    
    if start_date > end_date:
        raise HTTPException(
            status_code=400,
            detail="Start date must be before end date.",
        )
    
    # Get mood data
    firestore_service = get_firestore_service()
    moods = await firestore_service.get_moods_in_range(
        current_user["uid"],
        start_date,
        end_date,
    )
    
    if not moods:
        return MoodAnalysisResponse(
            period=MoodPeriod(start=request.start_date, end=request.end_date),
            summary=MoodSummary(
                average_score=0.0,
                total_entries=0,
                trend=MoodTrend.stable,
            ),
            ai_insight="No mood entries found for this period. Start tracking your mood to see insights!",
        )
    
    # Calculate statistics
    scores = [m["score"] for m in moods]
    average_score = sum(scores) / len(scores)
    trend = calculate_trend(moods)
    
    # Format mood data for AI analysis
    mood_data = [
        {
            "date": m["date"].strftime("%Y-%m-%d") if hasattr(m["date"], "strftime") else str(m["date"]),
            "score": m["score"],
            "note": m.get("note", ""),
        }
        for m in moods
    ]
    
    # Generate AI insight
    gemini_service = get_gemini_service()
    ai_insight = await gemini_service.generate_mood_analysis(
        average_score=average_score,
        total_entries=len(moods),
        trend=trend.value,
        mood_data=mood_data,
    )
    
    return MoodAnalysisResponse(
        period=MoodPeriod(start=request.start_date, end=request.end_date),
        summary=MoodSummary(
            average_score=round(average_score, 2),
            total_entries=len(moods),
            trend=trend,
        ),
        ai_insight=ai_insight,
    )
