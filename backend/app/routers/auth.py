from fastapi import APIRouter, Depends

from ..dependencies import get_current_user, CurrentUser

router = APIRouter()


@router.get("/me")
async def get_current_user_info(current_user: CurrentUser = Depends(get_current_user)):
    """Get current authenticated user info."""
    return {
        "uid": current_user["uid"],
        "email": current_user.get("email"),
        "name": current_user.get("name"),
        "picture": current_user.get("picture"),
    }


@router.post("/verify")
async def verify_token(current_user: CurrentUser = Depends(get_current_user)):
    """Verify that the provided token is valid."""
    return {
        "valid": True,
        "uid": current_user["uid"],
    }
