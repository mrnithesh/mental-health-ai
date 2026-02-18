# API Contracts

Last updated: 2026-01-28

Base URL: `https://<cloud-run-url>/api`

All endpoints require `Authorization: Bearer <firebase_id_token>` header unless noted.

---

## Health Check

### GET /health
No auth required.

**Response 200:**
```json
{
  "status": "healthy",
  "version": "1.0.0"
}
```

---

## Voice Endpoints

### POST /api/voice/ephemeral-token
Generate ephemeral token for Gemini Live WebSocket connection.

**Request:**
```json
{
  "model": "gemini-2.0-flash-exp"  // optional, defaults to this
}
```

**Response 200:**
```json
{
  "token": "ephemeral_token_string",
  "expires_at": "2026-01-28T12:00:00Z",
  "websocket_url": "wss://generativelanguage.googleapis.com/..."
}
```

**Errors:**
- 401: Invalid or missing auth token
- 500: Failed to generate ephemeral token

---

## Chat Endpoints

### POST /api/chat/message
Send a message and get AI response (streaming SSE).

**Request:**
```json
{
  "conversation_id": "string | null",  // null to start new conversation
  "message": "string"
}
```

**Response 200 (SSE stream):**
```
data: {"type": "conversation_id", "value": "conv_123"}

data: {"type": "chunk", "value": "Hello"}

data: {"type": "chunk", "value": ", how"}

data: {"type": "chunk", "value": " are you?"}

data: {"type": "done", "message_id": "msg_456"}
```

**Errors:**
- 401: Invalid or missing auth token
- 400: Missing message content

### GET /api/chat/conversations
List user's conversations.

**Response 200:**
```json
{
  "conversations": [
    {
      "id": "conv_123",
      "title": "Feeling anxious today",
      "message_count": 5,
      "updated_at": "2026-01-28T10:00:00Z"
    }
  ]
}
```

### GET /api/chat/history/{conversation_id}
Get conversation history.

**Response 200:**
```json
{
  "conversation_id": "conv_123",
  "messages": [
    {
      "id": "msg_1",
      "role": "user",
      "content": "I'm feeling anxious",
      "created_at": "2026-01-28T09:00:00Z"
    },
    {
      "id": "msg_2", 
      "role": "assistant",
      "content": "I understand...",
      "created_at": "2026-01-28T09:00:05Z"
    }
  ]
}
```

**Errors:**
- 401: Invalid auth
- 404: Conversation not found

---

## Journal Endpoints

### POST /api/journal/insight
Generate AI insight for a journal entry.

**Request:**
```json
{
  "journal_id": "string",
  "content": "string"  // journal content to analyze
}
```

**Response 200:**
```json
{
  "insight": "string",  // AI-generated reflection
  "journal_id": "string"
}
```

**Errors:**
- 401: Invalid auth
- 400: Missing content

---

## Mood Endpoints

### POST /api/mood/analysis
Analyze mood patterns over a time period.

**Request:**
```json
{
  "start_date": "2026-01-01",  // ISO date
  "end_date": "2026-01-28"     // ISO date
}
```

**Response 200:**
```json
{
  "period": {
    "start": "2026-01-01",
    "end": "2026-01-28"
  },
  "summary": {
    "average_score": 3.5,
    "total_entries": 20,
    "trend": "improving"  // improving, declining, stable
  },
  "ai_insight": "string"  // AI-generated analysis
}
```

**Errors:**
- 401: Invalid auth
- 400: Invalid date range

---

## Error Response Format

All errors follow this format:

```json
{
  "error": "Human-readable error message",
  "code": "ERROR_CODE"
}
```

### Error Codes
- `UNAUTHORIZED`: Missing or invalid auth token
- `NOT_FOUND`: Resource not found
- `VALIDATION_ERROR`: Invalid request data
- `INTERNAL_ERROR`: Server error
- `RATE_LIMITED`: Too many requests
