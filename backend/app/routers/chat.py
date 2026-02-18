from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from typing import AsyncGenerator
import json

from ..dependencies import get_current_user, CurrentUser
from ..models.schemas import (
    ChatMessageRequest,
    ConversationListResponse,
    ConversationHistoryResponse,
    ConversationSummary,
    Message,
    MessageRole,
)
from ..services.gemini_service import get_gemini_service
from ..services.firestore_service import get_firestore_service

router = APIRouter()


async def generate_sse_stream(
    uid: str,
    conversation_id: str,
    message: str,
) -> AsyncGenerator[str, None]:
    """Generate Server-Sent Events stream for chat response."""
    gemini_service = get_gemini_service()
    firestore_service = get_firestore_service()
    
    # Get conversation history
    history = []
    if conversation_id:
        messages = await firestore_service.get_messages(uid, conversation_id)
        history = [
            {"role": m["role"], "content": m["content"]}
            for m in messages
        ]
    else:
        # Create new conversation
        conversation = await firestore_service.create_conversation(uid)
        conversation_id = conversation["id"]
        yield f"data: {json.dumps({'type': 'conversation_id', 'value': conversation_id})}\n\n"
    
    # Save user message
    await firestore_service.add_message(uid, conversation_id, "user", message)
    
    # Generate and stream AI response
    full_response = ""
    async for chunk in gemini_service.generate_chat_response(message, history):
        full_response += chunk
        yield f"data: {json.dumps({'type': 'chunk', 'value': chunk})}\n\n"
    
    # Save AI response
    ai_message = await firestore_service.add_message(
        uid, conversation_id, "assistant", full_response
    )
    
    # Update conversation title if it's a new conversation
    if len(history) == 0:
        # Use first few words of user message as title
        title = message[:50] + "..." if len(message) > 50 else message
        await firestore_service.update_conversation(uid, conversation_id, title=title)
    
    yield f"data: {json.dumps({'type': 'done', 'message_id': ai_message['id']})}\n\n"


@router.post("/message")
async def send_message(
    request: ChatMessageRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """
    Send a chat message and receive streaming AI response.
    
    Returns Server-Sent Events stream with:
    - conversation_id: ID of the conversation (for new conversations)
    - chunk: Text chunks of the AI response
    - done: Final message with message_id
    """
    return StreamingResponse(
        generate_sse_stream(
            current_user["uid"],
            request.conversation_id,
            request.message,
        ),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )


@router.get("/conversations", response_model=ConversationListResponse)
async def list_conversations(
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get list of user's conversations."""
    firestore_service = get_firestore_service()
    conversations = await firestore_service.get_conversations(current_user["uid"])
    
    return ConversationListResponse(
        conversations=[
            ConversationSummary(
                id=c["id"],
                title=c.get("title", "Untitled"),
                message_count=c.get("messageCount", 0),
                updated_at=c.get("updatedAt"),
            )
            for c in conversations
        ]
    )


@router.get("/history/{conversation_id}", response_model=ConversationHistoryResponse)
async def get_conversation_history(
    conversation_id: str,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get message history for a conversation."""
    firestore_service = get_firestore_service()
    
    # Verify conversation exists and belongs to user
    conversation = await firestore_service.get_conversation(
        current_user["uid"], conversation_id
    )
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    messages = await firestore_service.get_messages(current_user["uid"], conversation_id)
    
    return ConversationHistoryResponse(
        conversation_id=conversation_id,
        messages=[
            Message(
                id=m["id"],
                role=MessageRole(m["role"]),
                content=m["content"],
                created_at=m["createdAt"],
            )
            for m in messages
        ],
    )
