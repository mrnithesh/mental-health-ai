# Mental Health AI

An AI-powered mental wellness companion app with voice chat, text chat, journaling, and mood tracking.

## Tech Stack

- **Frontend**: Flutter
- **AI**: Firebase AI Logic (`firebase_ai`) with Gemini
  - Text: `gemini-2.5-flash`
  - Voice: `gemini-2.5-flash-native-audio-preview-12-2025`
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth (Email, Google Sign-in, Phone OTP)

## Architecture

This project now runs **without a separate custom backend**.

- Text chat and voice chat connect directly through Firebase AI Logic.
- App data (journal, mood, user data) is stored in Firestore.
- Auth is handled by Firebase Auth.

## Project Structure

```text
mental-health-ai/
├── frontend/               # Flutter app
│   └── lib/
│       ├── config/
│       ├── models/
│       ├── providers/
│       ├── screens/
│       ├── services/
│       └── widgets/
├── firebase.json
└── firestore.rules
```

## Getting Started

### Prerequisites

- Flutter SDK 3.2+
- Firebase project with Firestore and Authentication enabled
- Gemini API enabled for Firebase AI Logic

### Setup

1. Go to frontend:
   ```bash
   cd frontend
   ```
2. Configure Firebase:
   ```bash
   flutterfire configure
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Features

- **Voice Chat**: Real-time voice conversation using Gemini Live API.
- **Text Chat**: Streaming chat responses from Gemini Flash.
- **Journaling**: Save entries and view insights.
- **Mood Tracking**: Daily mood logs and trend visualization.

## Security

- Firebase Auth protects user access.
- Firestore security rules enforce user-level data isolation.
- Secrets are managed through Firebase/project configuration.

## License

MIT
