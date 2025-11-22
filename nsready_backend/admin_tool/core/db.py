import os
from typing import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy import text


def _database_url_from_env() -> str:
    user = os.getenv("POSTGRES_USER", "nsready_user")
    password = os.getenv("POSTGRES_PASSWORD", "nsready_password")
    host = os.getenv("POSTGRES_HOST", "db")
    port = int(os.getenv("POSTGRES_PORT", "5432"))
    db = os.getenv("POSTGRES_DB", "nsready_db")
    return f"postgresql+asyncpg://{user}:{password}@{host}:{port}/{db}"


def create_engine() -> AsyncEngine:
    return create_async_engine(_database_url_from_env(), pool_pre_ping=True)


def create_sessionmaker(engine: AsyncEngine) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(engine, expire_on_commit=False)


async def healthcheck(engine: AsyncEngine) -> None:
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))


async def get_session() -> AsyncIterator[AsyncSession]:
    engine = create_engine()
    SessionLocal = create_sessionmaker(engine)
    async with SessionLocal() as session:
        yield session
    await engine.dispose()


