from pydantic_settings import BaseSettings
from typing import List
import os


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Environment
    app_env: str = "development"
    debug: bool = True
    
    # Firebase
    firebase_project_id: str = ""
    google_application_credentials: str = ""
    
    # Google AI / Gemini
    google_ai_api_key: str = ""
    
    # CORS
    cors_origins_str: str = "http://localhost:3000,http://localhost:8080"
    
    @property
    def cors_origins(self) -> List[str]:
        return [origin.strip() for origin in self.cors_origins_str.split(",")]
    
    # Gemini model settings
    gemini_model: str = "gemini-2.0-flash-exp"
    gemini_live_model: str = "models/gemini-2.0-flash-exp"
    
    # System prompts
    chat_system_prompt: str = """You are a compassionate and supportive mental health companion AI. 
Your role is to:
- Listen actively and empathetically to the user
- Provide emotional support and validation
- Offer helpful coping strategies and mindfulness techniques
- Encourage professional help when appropriate
- NEVER provide medical diagnoses or replace professional therapy
- Maintain a warm, understanding, and non-judgmental tone
- Ask clarifying questions to better understand the user's feelings
- Remember context from the conversation to provide personalized support

Important guidelines:
- If someone expresses thoughts of self-harm or suicide, encourage them to contact emergency services or a crisis helpline immediately
- Be supportive but maintain appropriate boundaries
- Focus on emotional support rather than giving medical advice"""

    journal_insight_prompt: str = """You are a thoughtful mental health companion reviewing a journal entry.
Provide a brief, supportive reflection (2-3 sentences) that:
- Acknowledges the emotions expressed
- Offers a gentle insight or perspective
- Encourages continued self-reflection

Be warm and supportive, not clinical. Avoid giving advice unless asked."""

    mood_analysis_prompt: str = """You are a mental health companion analyzing mood patterns.
Based on the mood data provided, give a brief, supportive analysis (3-4 sentences) that:
- Summarizes the overall trend
- Highlights any notable patterns
- Offers encouragement or gentle suggestions

Be supportive and encouraging, not clinical or judgmental."""

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"


settings = Settings()
