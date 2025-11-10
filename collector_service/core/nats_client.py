import os
import json
import logging
import asyncio
from typing import Optional
from nats.aio.client import Client as NATS
from nats.aio.errors import ErrConnectionClosed, ErrTimeout

logger = logging.getLogger(__name__)


class NATSClient:
    """NATS client wrapper for publishing events"""
    
    def __init__(self):
        self.nc: Optional[NATS] = None
        self.host = os.getenv("NATS_HOST", "nats")
        self.port = int(os.getenv("NATS_PORT", "4222"))
        self.subject = os.getenv("QUEUE_SUBJECT", "ingress.events")
        self._connected = False
    
    async def connect(self, max_retries: int = 10, retry_delay: int = 2) -> None:
        """Connect to NATS with retry logic"""
        self.nc = NATS()
        
        for attempt in range(max_retries):
            try:
                await self.nc.connect(f"nats://{self.host}:{self.port}")
                self._connected = True
                logger.info(f"Connected to NATS at {self.host}:{self.port}")
                return
            except Exception as e:
                logger.warning(f"NATS connection attempt {attempt + 1}/{max_retries} failed: {e}")
                if attempt < max_retries - 1:
                    await asyncio.sleep(retry_delay)
                else:
                    raise
    
    async def disconnect(self) -> None:
        """Disconnect from NATS"""
        if self.nc and self._connected:
            await self.nc.close()
            self._connected = False
            logger.info("Disconnected from NATS")
    
    async def publish_event(self, data: dict) -> None:
        """Publish event to NATS subject"""
        if not self._connected or not self.nc:
            raise RuntimeError("NATS client not connected")
        
        try:
            message = json.dumps(data).encode()
            await self.nc.publish(self.subject, message)
            logger.debug(f"Published event to {self.subject}: trace_id={data.get('trace_id')}")
        except ErrConnectionClosed:
            logger.error("NATS connection closed")
            raise
        except Exception as e:
            logger.error(f"Error publishing to NATS: {e}")
            raise
    
    async def get_queue_depth(self) -> int:
        """Get approximate queue depth from NATS JetStream"""
        if not self._connected or not self.nc:
            return 0
        
        try:
            js = self.nc.jetstream()
            # Try to get stream info
            # Note: This requires JetStream to be enabled and stream to exist
            # For now, return 0 as a placeholder
            return 0
        except Exception as e:
            logger.debug(f"Could not get queue depth: {e}")
            return 0
    
    @property
    def is_connected(self) -> bool:
        """Check if NATS is connected"""
        return self._connected


# Global NATS client instance
_nats_client: Optional[NATSClient] = None


async def init_nats_client() -> NATSClient:
    """Initialize and connect NATS client"""
    global _nats_client
    if _nats_client is None:
        _nats_client = NATSClient()
        await _nats_client.connect()
    return _nats_client


async def close_nats_client() -> None:
    """Close NATS client connection"""
    global _nats_client
    if _nats_client:
        await _nats_client.disconnect()
        _nats_client = None


def get_nats_client() -> NATSClient:
    """Dependency to get NATS client"""
    global _nats_client
    if _nats_client is None:
        raise RuntimeError("NATS client not initialized")
    return _nats_client

