# Mental Health AI App - Agent Instructions

## Project Overview
AI-powered mental health app with voice chat, text chat, journaling, and mood tracking.

## Tech Stack
- **Frontend**: Flutter (Android) in `frontend/`
- **Backend**: FastAPI on Cloud Run in `backend/`
- **Database**: Firestore
- **Auth**: Firebase Auth (Email, Google Sign-in, Phone OTP)
- **AI**: Gemini Live (voice), Gemini Flash (text)

## Project Structure
```
mental-health-ai/
├── .cursor/
│   ├── AGENTS.md           # This file
│   └── memory/             # Context preservation
├── frontend/               # Flutter Android app
│   └── lib/
│       ├── config/         # App configuration
│       ├── models/         # Data models
│       ├── services/       # API, Firebase, Gemini services
│       ├── providers/      # Riverpod state management
│       ├── screens/        # UI screens by feature
│       └── widgets/        # Reusable components
├── backend/                # FastAPI application
│   └── app/
│       ├── routers/        # API route handlers
│       ├── services/       # Business logic
│       └── models/         # Pydantic schemas
├── firebase.json
└── firestore.rules
```

## CRITICAL: Context Preservation Rules

After making significant changes, you MUST UPDATE the appropriate memory file in `.cursor/memory/`:

### 1. architecture.md - Update when:
- Adding new services or dependencies
- Changing API structure or endpoints
- Modifying data models or Firestore schema
- Altering authentication flow
- Adding new packages to pubspec.yaml or requirements.txt

### 2. api-contracts.md - Update when:
- Adding/modifying API endpoints
- Changing request/response schemas
- Updating error codes or responses
- Modifying authentication requirements

### 3. progress.md - Update when:
- Completing a feature or milestone
- Encountering blockers or issues
- Making important architectural decisions
- Starting work on a new feature

## Code Conventions

### Flutter (frontend/)
- State management: **Riverpod** (use `flutter_riverpod`)
- HTTP client: **Dio** for FastAPI calls
- File naming: `snake_case.dart`
- Class naming: `PascalCase`
- Organize by feature in `screens/` folder

### Python (backend/)
- Framework: **FastAPI** with async/await
- Use `firebase-admin` for auth token validation
- Use `google-generativeai` for Gemini API
- Always return structured JSON responses
- Use Pydantic models for request/response validation
- File naming: `snake_case.py`

### Firestore
- Always use typed models, never raw dicts
- User data path: `/users/{uid}/...`
- Collections: `conversations`, `journals`, `moods`

## Error Handling
- Backend: Return `{"error": "message", "code": "ERROR_CODE"}` with appropriate HTTP status
- Frontend: Use Riverpod's AsyncValue for loading/error states

## Environment Variables
- Backend: Use `.env` file with `python-dotenv`
- Frontend: Use `--dart-define` for build-time config
- NEVER commit API keys or secrets
