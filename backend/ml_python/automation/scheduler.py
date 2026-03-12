"""
Automation scheduler used by application lifespan.
"""
from __future__ import annotations

import asyncio
from datetime import datetime
from typing import Optional


class AutomationScheduler:
    """Minimal async scheduler with start/stop hooks."""

    def __init__(self) -> None:
        self._running = False
        self._task: Optional[asyncio.Task] = None

    async def start(self) -> None:
        if self._running:
            return
        self._running = True
        self._task = asyncio.create_task(self._loop())

    async def stop(self) -> None:
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass

    def is_running(self) -> bool:
        return self._running

    async def _loop(self) -> None:
        while self._running:
            await asyncio.sleep(60)

    async def heartbeat(self) -> dict:
        return {"running": self._running, "timestamp": datetime.utcnow().isoformat()}
