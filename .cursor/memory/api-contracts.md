# API Contracts

Last updated: 2026-01-28

This file previously documented a custom backend API.
The app now uses Firebase AI Logic directly from Flutter, so there are no project-owned REST endpoints here.

Authentication and data access are handled by Firebase Auth + Firestore rules.

---

## Current Service Contracts

### Text chat
- Service: `frontend/lib/services/gemini_service.dart`
- Model: `gemini-2.5-flash`
- Interaction: `ChatSession.sendMessageStream(Content.text(...))`

### Voice chat
- Service: `frontend/lib/services/gemini_service.dart`
- Model: `gemini-2.5-flash-native-audio-preview-12-2025`
- Interaction: `LiveSession.sendAudioRealtime(...)` + `LiveSession.receive()`

### Persistence
- Firestore operations are handled by `frontend/lib/services/firestore_service.dart`.
- Auth state and identity are handled by Firebase Auth in `frontend/lib/services/auth_service.dart`.
