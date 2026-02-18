from datetime import datetime
from typing import List, Optional
from google.cloud.firestore_v1 import FieldFilter
import uuid

from ..dependencies import get_firestore_client


class FirestoreService:
    """Service for Firestore operations."""
    
    def __init__(self):
        self._db = get_firestore_client()
    
    def _user_ref(self, uid: str):
        """Get reference to user document."""
        return self._db.collection("users").document(uid)
    
    # ============ Conversations ============
    
    async def get_conversations(self, uid: str) -> List[dict]:
        """Get all conversations for a user."""
        conversations_ref = self._user_ref(uid).collection("conversations")
        docs = conversations_ref.order_by("updatedAt", direction="DESCENDING").stream()
        
        return [
            {
                "id": doc.id,
                **doc.to_dict(),
            }
            for doc in docs
        ]
    
    async def get_conversation(self, uid: str, conversation_id: str) -> Optional[dict]:
        """Get a single conversation."""
        doc = self._user_ref(uid).collection("conversations").document(conversation_id).get()
        if not doc.exists:
            return None
        return {"id": doc.id, **doc.to_dict()}
    
    async def create_conversation(self, uid: str, title: str = "New Conversation") -> dict:
        """Create a new conversation."""
        conversations_ref = self._user_ref(uid).collection("conversations")
        doc_ref = conversations_ref.document()
        
        now = datetime.utcnow()
        data = {
            "title": title,
            "messageCount": 0,
            "createdAt": now,
            "updatedAt": now,
        }
        
        doc_ref.set(data)
        return {"id": doc_ref.id, **data}
    
    async def update_conversation(
        self,
        uid: str,
        conversation_id: str,
        title: Optional[str] = None,
        increment_messages: bool = False,
    ):
        """Update a conversation."""
        doc_ref = self._user_ref(uid).collection("conversations").document(conversation_id)
        
        updates = {"updatedAt": datetime.utcnow()}
        
        if title:
            updates["title"] = title
        
        doc_ref.update(updates)
        
        if increment_messages:
            from google.cloud.firestore_v1 import Increment
            doc_ref.update({"messageCount": Increment(1)})
    
    # ============ Messages ============
    
    async def get_messages(
        self,
        uid: str,
        conversation_id: str,
        limit: int = 50,
    ) -> List[dict]:
        """Get messages for a conversation."""
        messages_ref = (
            self._user_ref(uid)
            .collection("conversations")
            .document(conversation_id)
            .collection("messages")
        )
        
        docs = messages_ref.order_by("createdAt").limit(limit).stream()
        
        return [
            {
                "id": doc.id,
                **doc.to_dict(),
            }
            for doc in docs
        ]
    
    async def add_message(
        self,
        uid: str,
        conversation_id: str,
        role: str,
        content: str,
    ) -> dict:
        """Add a message to a conversation."""
        messages_ref = (
            self._user_ref(uid)
            .collection("conversations")
            .document(conversation_id)
            .collection("messages")
        )
        
        doc_ref = messages_ref.document()
        now = datetime.utcnow()
        
        data = {
            "role": role,
            "content": content,
            "createdAt": now,
        }
        
        doc_ref.set(data)
        
        # Update conversation
        await self.update_conversation(uid, conversation_id, increment_messages=True)
        
        return {"id": doc_ref.id, **data}
    
    # ============ Moods ============
    
    async def get_moods_in_range(
        self,
        uid: str,
        start_date: datetime,
        end_date: datetime,
    ) -> List[dict]:
        """Get mood entries within a date range."""
        moods_ref = self._user_ref(uid).collection("moods")
        
        docs = (
            moods_ref
            .where(filter=FieldFilter("date", ">=", start_date))
            .where(filter=FieldFilter("date", "<=", end_date))
            .order_by("date")
            .stream()
        )
        
        return [
            {
                "id": doc.id,
                **doc.to_dict(),
            }
            for doc in docs
        ]


# Singleton instance
_firestore_service = None


def get_firestore_service() -> FirestoreService:
    """Get or create FirestoreService instance."""
    global _firestore_service
    if _firestore_service is None:
        _firestore_service = FirestoreService()
    return _firestore_service
