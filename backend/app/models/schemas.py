from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


# ============ Common ============

class ErrorResponse(BaseModel):
    error: str
    code: str


# ============ Chat ============

class ChatMessageRequest(BaseModel):
    conversation_id: Optional[str] = None
    message: str = Field(..., min_length=1, max_length=2000)


class MessageRole(str, Enum):
    user = "user"
    assistant = "assistant"


class Message(BaseModel):
    id: str
    role: MessageRole
    content: str
    created_at: datetime


class ConversationSummary(BaseModel):
    id: str
    title: str
    message_count: int
    updated_at: datetime


class ConversationListResponse(BaseModel):
    conversations: List[ConversationSummary]


class ConversationHistoryResponse(BaseModel):
    conversation_id: str
    messages: List[Message]


# ============ Voice ============

class EphemeralTokenRequest(BaseModel):
    model: str = "gemini-2.0-flash-exp"


class EphemeralTokenResponse(BaseModel):
    token: str
    expires_at: datetime
    websocket_url: str


# ============ Journal ============

class JournalInsightRequest(BaseModel):
    journal_id: str
    content: str = Field(..., min_length=1, max_length=10000)


class JournalInsightResponse(BaseModel):
    insight: str
    journal_id: str


# ============ Mood ============

class MoodAnalysisRequest(BaseModel):
    start_date: str  # ISO date format: YYYY-MM-DD
    end_date: str    # ISO date format: YYYY-MM-DD


class MoodTrend(str, Enum):
    improving = "improving"
    declining = "declining"
    stable = "stable"


class MoodSummary(BaseModel):
    average_score: float
    total_entries: int
    trend: MoodTrend


class MoodPeriod(BaseModel):
    start: str
    end: str


class MoodAnalysisResponse(BaseModel):
    period: MoodPeriod
    summary: MoodSummary
    ai_insight: str
