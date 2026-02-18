import google.generativeai as genai
from datetime import datetime, timedelta
import httpx
from typing import AsyncGenerator, Optional, List

from ..config import settings
from ..dependencies import get_gemini_client


class GeminiService:
    """Service for interacting with Google Gemini API."""
    
    def __init__(self):
        self._client = get_gemini_client()
        self._model = genai.GenerativeModel(settings.gemini_model)
    
    async def generate_chat_response(
        self,
        message: str,
        history: Optional[List[dict]] = None,
    ) -> AsyncGenerator[str, None]:
        """
        Generate a streaming chat response.
        
        Args:
            message: The user's message
            history: Previous conversation history
            
        Yields:
            Chunks of the response text
        """
        # Build conversation context
        contents = []
        
        # Add system prompt as initial context
        contents.append({
            "role": "user",
            "parts": [{"text": f"System: {settings.chat_system_prompt}"}]
        })
        contents.append({
            "role": "model",
            "parts": [{"text": "I understand. I'm here to listen and support you with compassion and empathy."}]
        })
        
        # Add conversation history
        if history:
            for msg in history:
                role = "user" if msg["role"] == "user" else "model"
                contents.append({
                    "role": role,
                    "parts": [{"text": msg["content"]}]
                })
        
        # Add current message
        contents.append({
            "role": "user",
            "parts": [{"text": message}]
        })
        
        # Generate streaming response
        response = await self._model.generate_content_async(
            contents,
            stream=True,
            generation_config=genai.GenerationConfig(
                temperature=0.7,
                top_p=0.9,
                max_output_tokens=1024,
            ),
        )
        
        async for chunk in response:
            if chunk.text:
                yield chunk.text
    
    async def generate_journal_insight(self, content: str) -> str:
        """
        Generate an AI insight for a journal entry.
        
        Args:
            content: The journal entry content
            
        Returns:
            AI-generated insight
        """
        prompt = f"""{settings.journal_insight_prompt}

Journal Entry:
{content}

Provide a brief, supportive reflection:"""
        
        response = await self._model.generate_content_async(
            prompt,
            generation_config=genai.GenerationConfig(
                temperature=0.7,
                max_output_tokens=256,
            ),
        )
        
        return response.text
    
    async def generate_mood_analysis(
        self,
        average_score: float,
        total_entries: int,
        trend: str,
        mood_data: List[dict],
    ) -> str:
        """
        Generate AI analysis of mood patterns.
        
        Args:
            average_score: Average mood score for the period
            total_entries: Number of mood entries
            trend: Overall trend (improving, declining, stable)
            mood_data: List of mood entries with scores and dates
            
        Returns:
            AI-generated analysis
        """
        # Format mood data for the prompt
        mood_summary = "\n".join([
            f"- {m['date']}: Score {m['score']}/5 ({m.get('note', 'no note')})"
            for m in mood_data[:10]  # Limit to last 10 entries
        ])
        
        prompt = f"""{settings.mood_analysis_prompt}

Mood Data Summary:
- Period: {len(mood_data)} days
- Average Score: {average_score:.1f}/5
- Total Entries: {total_entries}
- Trend: {trend}

Recent Entries:
{mood_summary}

Provide a supportive analysis:"""
        
        response = await self._model.generate_content_async(
            prompt,
            generation_config=genai.GenerationConfig(
                temperature=0.7,
                max_output_tokens=256,
            ),
        )
        
        return response.text
    
    async def get_ephemeral_token(self) -> dict:
        """
        Generate an ephemeral token for Gemini Live API.
        
        Note: This is a placeholder implementation.
        The actual implementation depends on Google's API for generating
        ephemeral tokens, which may require specific authentication flow.
        
        Returns:
            dict with token, expiry, and websocket URL
        """
        # In a real implementation, you would call Google's API to generate
        # an ephemeral token for the Gemini Live API.
        # For now, we return a placeholder that would need to be replaced
        # with actual implementation based on Google's documentation.
        
        # The actual flow would be:
        # 1. Use service account credentials to request ephemeral token
        # 2. Token is short-lived (usually 10-15 minutes)
        # 3. Client uses token to establish WebSocket connection
        
        expires_at = datetime.utcnow() + timedelta(minutes=10)
        
        return {
            "token": settings.google_ai_api_key,  # Placeholder - replace with actual ephemeral token
            "expires_at": expires_at.isoformat() + "Z",
            "websocket_url": f"wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?model={settings.gemini_live_model}",
        }


# Singleton instance
_gemini_service = None


def get_gemini_service() -> GeminiService:
    """Get or create GeminiService instance."""
    global _gemini_service
    if _gemini_service is None:
        _gemini_service = GeminiService()
    return _gemini_service
