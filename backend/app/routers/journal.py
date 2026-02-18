from fastapi import APIRouter, Depends

from ..dependencies import get_current_user, CurrentUser
from ..models.schemas import JournalInsightRequest, JournalInsightResponse
from ..services.gemini_service import get_gemini_service

router = APIRouter()


@router.post("/insight", response_model=JournalInsightResponse)
async def generate_journal_insight(
    request: JournalInsightRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """
    Generate an AI insight/reflection for a journal entry.
    
    The AI provides a brief, supportive reflection on the journal content,
    acknowledging emotions and offering gentle perspectives.
    """
    gemini_service = get_gemini_service()
    insight = await gemini_service.generate_journal_insight(request.content)
    
    return JournalInsightResponse(
        insight=insight,
        journal_id=request.journal_id,
    )
