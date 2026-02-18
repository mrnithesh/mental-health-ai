from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .routers import auth, chat, voice, journal, mood

app = FastAPI(
    title="Mental Health AI API",
    description="Backend API for Mental Health AI App",
    version="1.0.0",
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(chat.router, prefix="/api/chat", tags=["Chat"])
app.include_router(voice.router, prefix="/api/voice", tags=["Voice"])
app.include_router(journal.router, prefix="/api/journal", tags=["Journal"])
app.include_router(mood.router, prefix="/api/mood", tags=["Mood"])


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "version": "1.0.0"}


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "message": "Mental Health AI API",
        "docs": "/docs",
        "health": "/health",
    }
