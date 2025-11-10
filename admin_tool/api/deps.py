import os
from fastapi import Header, HTTPException, status, Depends


def get_bearer_token_from_env() -> str:
    return os.getenv("ADMIN_BEARER_TOKEN", "devtoken")


async def bearer_auth(authorization: str | None = Header(default=None)) -> None:
    expected = f"Bearer {get_bearer_token_from_env()}"
    if authorization != expected:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unauthorized")


