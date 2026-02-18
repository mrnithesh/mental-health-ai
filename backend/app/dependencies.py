from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import firebase_admin
from firebase_admin import auth, credentials, firestore
import google.generativeai as genai
from functools import lru_cache

from .config import settings

# Initialize Firebase Admin SDK
_firebase_app = None
_db = None

def get_firebase_app():
    """Initialize and return Firebase Admin app."""
    global _firebase_app
    if _firebase_app is None:
        try:
            if settings.google_application_credentials:
                cred = credentials.Certificate(settings.google_application_credentials)
                _firebase_app = firebase_admin.initialize_app(cred)
            else:
                # Use Application Default Credentials
                _firebase_app = firebase_admin.initialize_app()
        except ValueError:
            # App already initialized
            _firebase_app = firebase_admin.get_app()
    return _firebase_app


def get_firestore_client():
    """Get Firestore client."""
    global _db
    if _db is None:
        get_firebase_app()
        _db = firestore.client()
    return _db


@lru_cache()
def get_gemini_client():
    """Initialize and return Gemini client."""
    genai.configure(api_key=settings.google_ai_api_key)
    return genai


# Security
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """
    Validate Firebase ID token and return user info.
    
    Returns:
        dict with 'uid', 'email', and other claims from the token
    """
    try:
        get_firebase_app()
        token = credentials.credentials
        decoded_token = auth.verify_id_token(token)
        return {
            "uid": decoded_token["uid"],
            "email": decoded_token.get("email"),
            "name": decoded_token.get("name"),
            "picture": decoded_token.get("picture"),
        }
    except auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Authentication failed: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


# Type alias for dependency injection
CurrentUser = dict
