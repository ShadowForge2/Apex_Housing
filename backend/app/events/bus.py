"""
Simple in-process event bus. In production, replace with Redis pub/sub or Celery.
Modules emit events, other modules subscribe to them.
"""
import asyncio
import logging
from typing import Any, Callable, Coroutine
from collections import defaultdict

logger = logging.getLogger(__name__)

class EventBus:
    def __init__(self):
        self._handlers: dict[str, list[Callable[..., Coroutine]]] = defaultdict(list)

    def subscribe(self, event_name: str, handler: Callable[..., Coroutine]):
        self._handlers[event_name].append(handler)
        logger.info(f"Handler {handler.__name__} subscribed to {event_name}")

    def unsubscribe(self, event_name: str, handler: Callable[..., Coroutine]):
        if handler in self._handlers[event_name]:
            self._handlers[event_name].remove(handler)

    async def emit(self, event_name: str, data: Any = None):
        handlers = self._handlers.get(event_name, [])
        if not handlers:
            logger.debug(f"No handlers for event: {event_name}")
            return
        tasks = [self._safe_call(handler, event_name, data) for handler in handlers]
        await asyncio.gather(*tasks, return_exceptions=True)

    async def _safe_call(self, handler, event_name: str, data: Any):
        try:
            await handler(data)
        except Exception as e:
            logger.error(f"Error in handler {handler.__name__} for {event_name}: {e}")

event_bus = EventBus()
