from fastapi import APIRouter, Depends
from datetime import datetime

from ..dependencies import get_current_user, CurrentUser
from ..models.schemas import EphemeralTokenRequest, EphemeralTokenResponse
from ..services.gemini_service import get_gemini_service

router = APIRouter()


@router.post("/ephemeral-token", response_model=EphemeralTokenResponse)
async def get_ephemeral_token(
    request: EphemeralTokenRequest = EphemeralTokenRequest(),
    current_user: CurrentUser = Depends(get_current_user),
):
    """
    Generate an ephemeral token for Gemini Live API WebSocket connection.
    
    The client uses this token to establish a direct WebSocket connection
    to Google's Gemini Live API for real-time voice interaction.
    
    Note: The token is short-lived (typically 10-15 minutes).
    """
    gemini_service = get_gemini_service()
    token_data = await gemini_service.get_ephemeral_token()
    
    return EphemeralTokenResponse(
        token=token_data["token"],
        expires_at=datetime.fromisoformat(token_data["expires_at"].replace("Z", "+00:00")),
        websocket_url=token_data["websocket_url"],
    )
