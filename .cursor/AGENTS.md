# Mental Health AI App - Agent Instructions

## Project Overview
AI-powered mental health app with voice chat, text chat, journaling, and mood tracking.

## Tech Stack
- **Frontend**: Flutter (Android) in `frontend/`
- **Database**: Firestore
- **Auth**: Firebase Auth (Email, Google Sign-in, Phone OTP)
- **AI**: Firebase AI Logic (`firebase_ai`) with Gemini Live (voice) and Gemini Flash (text)

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
│       ├── services/       # Firebase and Gemini services
│       ├── providers/      # Riverpod state management
│       ├── screens/        # UI screens by feature
│       └── widgets/        # Reusable components
├── firebase.json
└── firestore.rules
```

## CRITICAL: Context Preservation Rules

After making significant changes, you MUST UPDATE the appropriate memory file in `.cursor/memory/`:

### 1. architecture.md - Update when:
- Adding new services or dependencies
- Changing service integrations
- Modifying data models or Firestore schema
- Altering authentication flow
- Adding new packages to pubspec.yaml

### 2. api-contracts.md - Update when:
- Adding/modifying client-side service contracts
- Changing request/response payload shapes used by app services
- Updating error handling behavior
- Modifying authentication requirements

### 3. progress.md - Update when:
- Completing a feature or milestone
- Encountering blockers or issues
- Making important architectural decisions
- Starting work on a new feature

## Code Conventions

### Flutter (frontend/)
- State management: **Riverpod** (use `flutter_riverpod`)
- File naming: `snake_case.dart`
- Class naming: `PascalCase`
- Organize by feature in `screens/` folder

### Firestore
- Always use typed models, never raw dicts
- User data path: `/users/{uid}/...`
- Collections: `conversations`, `journals`, `moods`

## Error Handling
- Frontend: Use Riverpod's AsyncValue for loading/error states

## Environment Variables
- Frontend: Use `--dart-define` for build-time config
- NEVER commit API keys or secrets
