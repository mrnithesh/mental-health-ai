# Mental Health AI

An AI-powered mental health companion app with voice chat, text chat, journaling, and mood tracking.

## Tech Stack

- **Frontend**: Flutter (Android)
- **Backend**: FastAPI on Google Cloud Run
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth (Email, Google Sign-in, Phone OTP)
- **AI**: Google Gemini (Live API for voice, Flash for text)

## Project Structure

```
mental-health-ai/
├── .cursor/
│   ├── AGENTS.md           # AI agent instructions
│   └── memory/             # Context preservation files
├── frontend/               # Flutter Android app
│   └── lib/
│       ├── config/         # Theme, routes, constants
│       ├── models/         # Data models
│       ├── providers/      # Riverpod state management
│       ├── screens/        # UI screens
│       ├── services/       # API and Firebase services
│       └── widgets/        # Reusable components
├── backend/                # FastAPI server
│   └── app/
│       ├── routers/        # API endpoints
│       ├── services/       # Business logic
│       └── models/         # Pydantic schemas
├── firebase.json
└── firestore.rules
```

## Getting Started

### Prerequisites

- Flutter SDK 3.2+
- Python 3.11+
- Firebase project with Firestore and Authentication enabled
- Google Cloud project with Gemini API enabled
- gcloud CLI (for Cloud Run deployment)

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Copy the environment file and configure:
   ```bash
   cp .env.example .env
   # Edit .env with your Firebase and Gemini API credentials
   ```

5. Run the development server:
   ```bash
   uvicorn app.main:app --reload
   ```

6. API docs available at: http://localhost:8000/docs

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Configure Firebase:
   ```bash
   flutterfire configure
   ```

3. Update `lib/config/constants.dart` with your Cloud Run URL.

4. Get dependencies:
   ```bash
   flutter pub get
   ```

5. Run the app:
   ```bash
   flutter run
   ```

### Deployment

#### Deploy Backend to Cloud Run

```bash
cd backend
gcloud run deploy mental-health-api \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --min-instances 1 \
  --set-env-vars "GOOGLE_AI_API_KEY=your-key"
```

#### Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

## Features

### Voice Chat
Real-time voice conversation with AI using Gemini Live API. The app connects directly to Google's WebSocket for low-latency interaction.

### Text Chat
AI-powered chat with conversation history. Uses Gemini Flash for fast, cost-effective responses.

### Journaling
Write and save journal entries with optional AI-generated insights and reflections.

### Mood Tracking
Daily mood check-ins with visualizations and AI-powered pattern analysis.

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/auth/me` | GET | Get current user |
| `/api/voice/ephemeral-token` | POST | Get Gemini Live token |
| `/api/chat/message` | POST | Send chat message (streaming) |
| `/api/chat/conversations` | GET | List conversations |
| `/api/chat/history/{id}` | GET | Get conversation history |
| `/api/journal/insight` | POST | Generate journal insight |
| `/api/mood/analysis` | POST | Analyze mood patterns |

## Security

- All API endpoints (except health check) require Firebase authentication
- Firestore rules ensure users can only access their own data
- Sensitive data (API keys, credentials) stored in environment variables

## License

MIT
