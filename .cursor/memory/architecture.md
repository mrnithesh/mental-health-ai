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
│  │Firebase │  │ Gemini  │  │ Gemini  │  │Firestore│           │
│  │Auth Svc │  │Chat Svc │  │Live Svc │  │ Service │           │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘           │
└───────┼────────────┼────────────┼────────────┼──────────────────┘
        │            │            │            │
        ▼            ▼            ▼            ▼
┌───────────┐  ┌─────────────────────┐  ┌───────────┐
│  Firebase │  │  Firebase AI Logic   │  │ Firestore │
│   Auth    │  │  (firebase_ai SDK)   │  │    DB     │
└───────────┘  └─────────┬───────────┘  └───────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │    Gemini Models    │
              │  ┌───────┐ ┌─────┐ │
              │  │Flash  │ │Live │ │
              │  │3-prev │ │2.5  │ │
              │  └───────┘ └─────┘ │
              └─────────────────────┘
```

**Key change**: Chat and voice now connect directly to Gemini via Firebase AI Logic SDK (`firebase_ai` package) -- no backend needed for AI features.

## Gemini Integration (via Firebase AI Logic)

### Text Chat
- Model: `gemini-2.5-flash`
- SDK: `firebase_ai` → `FirebaseAI.googleAI(auth: FirebaseAuth.instance).generativeModel()`
- Multi-turn via `ChatSession.sendMessageStream()`
- System instruction: MindfulAI mental health companion persona
- **Important**: Firebase Auth (anonymous) required before using the SDK

### Voice Chat (Gemini Live API)
- Model: `gemini-2.5-flash-native-audio-preview-12-2025`
- SDK: `firebase_ai` → `FirebaseAI.googleAI().liveGenerativeModel()`
- Bidirectional audio via WebSocket: `LiveSession`
- Mic recording: `record` package (PCM 16-bit, 24kHz, mono, echo cancel, noise suppress)
- Audio MIME type: `audio/pcm` (no rate suffix)
- Speech config: `SpeechConfig(voiceName: 'Fenrir')`
- Transcription: enabled via `AudioTranscriptionConfig`
- Audio playback: TODO (transcript display working)

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

## UI Architecture

### Navigation
- `MainShell` scaffold with persistent bottom nav bar (5 tabs)
- Tabs: Home | Chat | Voice (center FAB) | Journal | Mood
- Splash → MainShell (demo mode, anonymous auth)
- Sub-pages (journal editor, mood history) use fade+slide transitions

### Color Palette (Calm Blue/Green)
- Primary: `#5B7FBA` (calm blue)
- Secondary: `#6ABFA3` (therapeutic sage green)
- Accent: `#F4C065` (warm gold)
- Background: `#F5F7FA` | Surface: `#FFFFFF` | SurfaceVariant: `#EDF1F7`

### Shared Widgets
- `GlassCard` — frosted glass container with blur
- `AnimatedListItem` — staggered fade+slide entrance
- `AppGradient` — standardized gradient backgrounds

## Authentication Flow

Currently in **demo mode** (auth bypassed, splash goes directly to main shell).

Production flow:
1. User opens app → Check Firebase Auth state
2. If not authenticated → Show auth screens
3. Auth options: Email/Password, Google Sign-in, Phone OTP
4. On successful auth → Create/update user document in Firestore

## Dependencies

### Frontend (pubspec.yaml) - FlutterFire BoM 4.9.0
- firebase_core: ^4.4.0
- firebase_auth: ^6.1.4
- cloud_firestore: ^6.1.2
- firebase_ai: ^3.8.0
- google_sign_in: ^6.2.1
- flutter_riverpod: ^2.4.9
- dio: ^5.4.0
- record: ^6.0.0
- permission_handler: ^11.3.0
- fl_chart, intl, uuid, shared_preferences, path_provider

### Backend (requirements.txt)
- fastapi, uvicorn
- firebase-admin
- google-generativeai
- python-dotenv
- pydantic
