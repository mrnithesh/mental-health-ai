# Architecture Documentation

Last updated: 2026-01-28

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter Android App                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │   Auth   │ │   Chat   │ │  Voice   │ │ Journal/ │           │
│  │ Screens  │ │  Screen  │ │  Screen  │ │   Mood   │           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
│       │            │            │            │                  │
│  ┌────┴────────────┴────────────┴────────────┴─────┐           │
│  │              Riverpod Providers                  │           │
│  └────┬────────────┬────────────┬────────────┬─────┘           │
│       │            │            │            │                  │
│  ┌────┴────┐  ┌────┴────┐  ┌────┴────┐  ┌────┴────┐           │
│  │Firebase │  │   API   │  │ Gemini  │  │Firestore│           │
│  │Auth Svc │  │ Service │  │Live Svc │  │ Service │           │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘           │
└───────┼────────────┼────────────┼────────────┼──────────────────┘
        │            │            │            │
        ▼            ▼            │            ▼
┌───────────┐  ┌───────────┐     │     ┌───────────┐
│  Firebase │  │ Cloud Run │     │     │ Firestore │
│   Auth    │  │  FastAPI  │     │     │    DB     │
└───────────┘  └─────┬─────┘     │     └───────────┘
                     │           │
                     ▼           ▼
              ┌─────────────────────┐
              │    Gemini APIs      │
              │  ┌───────┐ ┌─────┐  │
              │  │ Flash │ │Live │  │
              │  └───────┘ └─────┘  │
              └─────────────────────┘
```

## Firestore Schema

### /users/{uid}
```json
{
  "email": "string",
  "displayName": "string",
  "photoUrl": "string | null",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### /users/{uid}/conversations/{conversationId}
```json
{
  "title": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "messageCount": "number"
}
```

### /users/{uid}/conversations/{conversationId}/messages/{messageId}
```json
{
  "role": "user | assistant",
  "content": "string",
  "createdAt": "timestamp"
}
```

### /users/{uid}/journals/{journalId}
```json
{
  "content": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "moodId": "string | null",
  "aiInsight": "string | null"
}
```

### /users/{uid}/moods/{moodId}
```json
{
  "date": "timestamp",
  "score": "number (1-5)",
  "emoji": "string",
  "note": "string | null"
}
```

## Authentication Flow

1. User opens app → Check Firebase Auth state
2. If not authenticated → Show auth screens
3. Auth options:
   - Email/Password: Firebase `createUserWithEmailAndPassword` / `signInWithEmailAndPassword`
   - Google Sign-in: `google_sign_in` package → Firebase `signInWithCredential`
   - Phone OTP: Firebase `verifyPhoneNumber` → `signInWithCredential`
4. On successful auth → Create/update user document in Firestore
5. Get Firebase ID token → Include in `Authorization: Bearer <token>` header for API calls
6. FastAPI validates token using `firebase-admin` SDK

## API Authentication

All FastAPI endpoints (except health check) require:
- Header: `Authorization: Bearer <firebase_id_token>`
- Backend validates token and extracts `uid`

## Gemini Integration

### Text Chat (Gemini Flash)
- Model: `gemini-2.0-flash-exp`
- Called via FastAPI backend
- Maintains conversation context from Firestore history

### Voice Chat (Gemini Live)
- Model: `gemini-2.0-flash-exp` with Live API
- Direct WebSocket from Flutter to Gemini
- Backend only provides ephemeral token generation

## Dependencies

### Frontend (pubspec.yaml)
- firebase_core, firebase_auth, cloud_firestore
- google_sign_in
- flutter_riverpod
- dio
- web_socket_channel
- record (audio recording)
- fl_chart

### Backend (requirements.txt)
- fastapi, uvicorn
- firebase-admin
- google-generativeai
- python-dotenv
- pydantic
