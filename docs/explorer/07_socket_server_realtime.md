# Этап 7: Socket Server (qaspa-socket-server)

## Цель

Адаптировать форк `kaspa-socket-server` для Qaspa:
- Подключение к qaspad через gRPC
- Поддержка stealth outputs в событиях
- Корректная обработка nullable адресов

---

## Важные оговорки

- Ниже приведены **скелеты/псевдокод**. Реальные названия сервисов, методов и сообщений protobuf нужно брать из вашего форка `qaspa-socket-server` (или из `rpc/grpc/...` в этом монорепо).
- Главная цель документа: какие события нужны фронту и какие поля должны быть в payload, а не 100% совпадение импорта/имён классов.

## Совместимость с фронтом (критично)

В `qaspa-explorer-ng` socket.io клиент создаётся так:
- `SOCKET_URL` + `path: "/ws/socket.io"` (см. `app/api/socket.ts`)
- комнаты: `room="blocks"` и event: `"new-block"`

Значит сервер обязан:
- слушать socket.io на **path `/ws/socket.io`**
- поддерживать `socket.emit("join-room", <room>)` (см. `app/hooks/useSocketRoom.ts`)
- эмитить событие `"new-block"` в комнату `"blocks"`

Дополнительно (используется в UI для разовых запросов):
- `socket.emit(<command>, "")` и ожидание ответа через `socket.on(<command>, handler)` (см. `app/hooks/useSocketCommand.ts`)
  - серверу нужно либо отвечать тем же именем события, либо держать слой совместимости.

## Архитектура

```
┌─────────────────────────────────────────────────────────────────┐
│                    qaspa-socket-server                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   gRPC       │───>│   Event      │───>│  Socket.IO   │      │
│  │   Listener   │    │   Processor  │    │   Emitter    │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                                       │               │
│         ▼                                       ▼               │
│  ┌──────────────┐                       ┌──────────────┐       │
│  │   qaspad     │                       │   Clients    │       │
│  │   (gRPC)     │                       │  (Browser)   │       │
│  └──────────────┘                       └──────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Ключевые изменения

### 1. Конфигурация

#### config.py

```python
import os
from dataclasses import dataclass

@dataclass
class Config:
    # Kaspad/Qaspad connection
    kaspad_host: str = os.getenv('KASPAD_HOST', 'localhost:16110')
    
    # Server
    host: str = os.getenv('HOST', '0.0.0.0')
    port: int = int(os.getenv('PORT', '8081'))
    
    # CORS
    cors_origins: list = None
    
    # Feature flags
    emit_stealth_stats: bool = os.getenv('EMIT_STEALTH_STATS', 'true').lower() == 'true'
    
    def __post_init__(self):
        origins = os.getenv('CORS_ORIGINS', '*')
        self.cors_origins = origins.split(',') if origins != '*' else ['*']
```

### 2. Модели событий

#### models/events.py

```python
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any
from enum import Enum


class EventType(str, Enum):
    NEW_BLOCK = 'new-block'
    VIRTUAL_CHAIN_CHANGED = 'virtual-chain-changed'
    TRANSACTION_ACCEPTED = 'transaction-accepted'
    STEALTH_STATS = 'stealth-stats'  # Qaspa-specific


@dataclass
class BlockAddedEvent:
    """Событие нового блока"""
    hash: str
    daa_score: int
    blue_score: int
    timestamp: int
    tx_count: int
    is_chain_block: bool
    miner_address: Optional[str] = None
    
    # Qaspa additions
    stealth_output_count: int = 0
    total_amount: int = 0
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'hash': self.hash,
            'daaScore': self.daa_score,
            'blueScore': self.blue_score,
            'timestamp': self.timestamp,
            'txCount': self.tx_count,
            'isChainBlock': self.is_chain_block,
            'minerAddress': self.miner_address,
            'stealthOutputCount': self.stealth_output_count,
            'totalAmount': self.total_amount,
        }


@dataclass
class VirtualChainChangedEvent:
    """Событие изменения virtual chain"""
    removed_chain_block_hashes: List[str]
    added_chain_block_hashes: List[str]
    accepted_transaction_ids: List[str]
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'removedChainBlockHashes': self.removed_chain_block_hashes,
            'addedChainBlockHashes': self.added_chain_block_hashes,
            'acceptedTransactionIds': self.accepted_transaction_ids,
        }


@dataclass
class TransactionAcceptedEvent:
    """Событие принятой транзакции"""
    transaction_id: str
    accepting_block_hash: str
    accepting_block_blue_score: int
    
    # Output summary
    outputs: List[Dict[str, Any]] = field(default_factory=list)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'transactionId': self.transaction_id,
            'acceptingBlockHash': self.accepting_block_hash,
            'acceptingBlockBlueScore': self.accepting_block_blue_score,
            'outputs': self.outputs,
        }


@dataclass  
class StealthStatsEvent:
    """Qaspa-specific: статистика stealth за период"""
    period_start_daa: int
    period_end_daa: int
    total_stealth_outputs: int
    total_stealth_amount: int
    unique_view_tags: int
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'periodStartDaa': self.period_start_daa,
            'periodEndDaa': self.period_end_daa,
            'totalStealthOutputs': self.total_stealth_outputs,
            'totalStealthAmount': self.total_stealth_amount,
            'uniqueViewTags': self.unique_view_tags,
        }
```

### 3. gRPC Listener

#### grpc_listener.py

```python
import asyncio
import logging
from typing import AsyncIterator, Callable, Awaitable

import grpc
from kaspa_grpc import messages_pb2, messages_pb2_grpc

from config import Config
from models.events import BlockAddedEvent, VirtualChainChangedEvent

logger = logging.getLogger(__name__)

# Stealth script version
SCRIPT_VERSION_STEALTH = 16


class GrpcListener:
    def __init__(self, config: Config):
        self.config = config
        self.channel: grpc.aio.Channel = None
        self.stub: messages_pb2_grpc.RPCStub = None
        self._running = False
        
    async def connect(self):
        """Подключение к qaspad"""
        self.channel = grpc.aio.insecure_channel(self.config.kaspad_host)
        self.stub = messages_pb2_grpc.RPCStub(self.channel)
        logger.info(f"Connected to qaspad at {self.config.kaspad_host}")
        
    async def disconnect(self):
        """Отключение"""
        self._running = False
        if self.channel:
            await self.channel.close()
            
    async def subscribe_block_added(
        self,
        callback: Callable[[BlockAddedEvent], Awaitable[None]]
    ):
        """Подписка на новые блоки"""
        self._running = True
        
        request = messages_pb2.NotifyBlockAddedRequestMessage()
        
        try:
            async for response in self.stub.MessageStream(
                self._block_added_request_stream()
            ):
                if not self._running:
                    break
                    
                if response.HasField('blockAddedNotification'):
                    notification = response.blockAddedNotification
                    block = notification.block
                    
                    # Подсчитываем stealth outputs
                    stealth_count = 0
                    total_amount = 0
                    
                    for tx in block.transactions:
                        for output in tx.outputs:
                            total_amount += output.amount
                            if output.scriptPublicKey.version == SCRIPT_VERSION_STEALTH:
                                stealth_count += 1
                    
                    event = BlockAddedEvent(
                        hash=block.verboseData.hash,
                        daa_score=int(block.header.daaScore),
                        blue_score=int(block.header.blueScore),
                        timestamp=int(block.header.timestamp),
                        tx_count=len(block.transactions),
                        is_chain_block=block.verboseData.isChainBlock,
                        miner_address=self._extract_miner_address(block),
                        stealth_output_count=stealth_count,
                        total_amount=total_amount,
                    )
                    
                    await callback(event)
                    
        except grpc.aio.AioRpcError as e:
            logger.error(f"gRPC error in block subscription: {e}")
            raise
            
    async def subscribe_virtual_chain_changed(
        self,
        callback: Callable[[VirtualChainChangedEvent], Awaitable[None]]
    ):
        """Подписка на изменения virtual chain"""
        self._running = True
        
        try:
            async for response in self.stub.MessageStream(
                self._virtual_chain_request_stream()
            ):
                if not self._running:
                    break
                    
                if response.HasField('virtualChainChangedNotification'):
                    notification = response.virtualChainChangedNotification
                    
                    event = VirtualChainChangedEvent(
                        removed_chain_block_hashes=list(notification.removedChainBlockHashes),
                        added_chain_block_hashes=list(notification.addedChainBlockHashes),
                        accepted_transaction_ids=list(notification.acceptedTransactionIds),
                    )
                    
                    await callback(event)
                    
        except grpc.aio.AioRpcError as e:
            logger.error(f"gRPC error in virtual chain subscription: {e}")
            raise
            
    def _extract_miner_address(self, block) -> str | None:
        """Извлекает адрес майнера из coinbase транзакции"""
        if not block.transactions:
            return None
            
        coinbase_tx = block.transactions[0]
        if coinbase_tx.subnetworkId != '0000000000000000000000000000000000000001':
            return None
            
        if not coinbase_tx.outputs:
            return None
            
        first_output = coinbase_tx.outputs[0]
        verbose = first_output.verboseData
        
        if verbose and verbose.scriptPublicKeyAddress:
            return verbose.scriptPublicKeyAddress
            
        return None
        
    async def _block_added_request_stream(self) -> AsyncIterator:
        """Генератор запросов для подписки на блоки"""
        request = messages_pb2.KaspadMessage()
        request.notifyBlockAddedRequest.CopyFrom(
            messages_pb2.NotifyBlockAddedRequestMessage()
        )
        yield request
        
        # Keep stream alive
        while self._running:
            await asyncio.sleep(30)
            # Send keepalive or wait
            
    async def _virtual_chain_request_stream(self) -> AsyncIterator:
        """Генератор запросов для подписки на virtual chain"""
        request = messages_pb2.KaspadMessage()
        request.notifyVirtualChainChangedRequest.CopyFrom(
            messages_pb2.NotifyVirtualChainChangedRequestMessage(
                includeAcceptedTransactionIds=True
            )
        )
        yield request
        
        while self._running:
            await asyncio.sleep(30)
```

### 4. Socket.IO Server

#### server.py

```python
import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import socketio

from config import Config
from grpc_listener import GrpcListener
from models.events import (
    EventType, 
    BlockAddedEvent, 
    VirtualChainChangedEvent,
    StealthStatsEvent
)

logger = logging.getLogger(__name__)

# Config
config = Config()

# Socket.IO
sio = socketio.AsyncServer(
    async_mode='asgi',
    cors_allowed_origins=config.cors_origins,
    logger=True,
    engineio_logger=True,
)

# gRPC listener
grpc_listener = GrpcListener(config)

# Stats accumulator for stealth
stealth_stats = {
    'period_start_daa': 0,
    'total_outputs': 0,
    'total_amount': 0,
    'view_tags': set(),
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle management"""
    # Startup
    await grpc_listener.connect()
    
    # Start subscriptions
    asyncio.create_task(run_block_subscription())
    asyncio.create_task(run_virtual_chain_subscription())
    
    if config.emit_stealth_stats:
        asyncio.create_task(run_stealth_stats_emitter())
    
    yield
    
    # Shutdown
    await grpc_listener.disconnect()


# FastAPI app
app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount Socket.IO
socket_app = socketio.ASGIApp(sio, app)


# === Socket.IO Events ===

@sio.event
async def connect(sid, environ):
    logger.info(f"Client connected: {sid}")


@sio.event
async def disconnect(sid):
    logger.info(f"Client disconnected: {sid}")


@sio.event
async def join(sid, data):
    """Join a room (e.g., 'blocks', 'transactions', 'stealth')"""
    room = data.get('room', 'blocks')
    await sio.enter_room(sid, room)
    logger.info(f"Client {sid} joined room: {room}")
    

@sio.event
async def leave(sid, data):
    """Leave a room"""
    room = data.get('room', 'blocks')
    await sio.leave_room(sid, room)
    logger.info(f"Client {sid} left room: {room}")


# === Subscription Handlers ===

async def run_block_subscription():
    """Обработка новых блоков"""
    async def on_block(event: BlockAddedEvent):
        # Emit to 'blocks' room
        await sio.emit(
            EventType.NEW_BLOCK.value,
            event.to_dict(),
            room='blocks'
        )
        
        # Update stealth stats
        if config.emit_stealth_stats:
            stealth_stats['total_outputs'] += event.stealth_output_count
            stealth_stats['total_amount'] += event.total_amount
            
        logger.debug(f"Emitted new-block: {event.hash[:16]}...")
        
    while True:
        try:
            await grpc_listener.subscribe_block_added(on_block)
        except Exception as e:
            logger.error(f"Block subscription error: {e}")
            await asyncio.sleep(5)  # Reconnect delay


async def run_virtual_chain_subscription():
    """Обработка изменений virtual chain"""
    async def on_chain_changed(event: VirtualChainChangedEvent):
        await sio.emit(
            EventType.VIRTUAL_CHAIN_CHANGED.value,
            event.to_dict(),
            room='blocks'
        )
        
        logger.debug(
            f"Emitted virtual-chain-changed: "
            f"+{len(event.added_chain_block_hashes)} "
            f"-{len(event.removed_chain_block_hashes)}"
        )
        
    while True:
        try:
            await grpc_listener.subscribe_virtual_chain_changed(on_chain_changed)
        except Exception as e:
            logger.error(f"Virtual chain subscription error: {e}")
            await asyncio.sleep(5)


async def run_stealth_stats_emitter():
    """Периодическая эмиссия статистики stealth"""
    global stealth_stats
    
    while True:
        await asyncio.sleep(60)  # Every minute
        
        if stealth_stats['total_outputs'] > 0:
            event = StealthStatsEvent(
                period_start_daa=stealth_stats['period_start_daa'],
                period_end_daa=stealth_stats['period_start_daa'],  # Update with actual
                total_stealth_outputs=stealth_stats['total_outputs'],
                total_stealth_amount=stealth_stats['total_amount'],
                unique_view_tags=len(stealth_stats['view_tags']),
            )
            
            await sio.emit(
                EventType.STEALTH_STATS.value,
                event.to_dict(),
                room='stealth'
            )
            
            # Reset stats
            stealth_stats = {
                'period_start_daa': 0,
                'total_outputs': 0,
                'total_amount': 0,
                'view_tags': set(),
            }


# === REST Endpoints ===

@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.get("/stats")
async def stats():
    """Текущая статистика подключений"""
    return {
        "connected_clients": len(sio.manager.rooms.get('/', {}).get(None, set())),
        "rooms": {
            "blocks": len(sio.manager.rooms.get('/', {}).get('blocks', set())),
            "stealth": len(sio.manager.rooms.get('/', {}).get('stealth', set())),
        }
    }


# === Entry Point ===

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        socket_app,
        host=config.host,
        port=config.port,
        log_level="info"
    )
```

### 5. Frontend клиент

#### app/api/socket.ts (обновлённый)

```typescript
import { io, Socket } from 'socket.io-client';
import { config } from '../config';

let socket: Socket | null = null;

export interface BlockAddedEvent {
  hash: string;
  daaScore: number;
  blueScore: number;
  timestamp: number;
  txCount: number;
  isChainBlock: boolean;
  minerAddress: string | null;
  // Qaspa additions
  stealthOutputCount: number;
  totalAmount: number;
}

export interface VirtualChainChangedEvent {
  removedChainBlockHashes: string[];
  addedChainBlockHashes: string[];
  acceptedTransactionIds: string[];
}

export interface StealthStatsEvent {
  periodStartDaa: number;
  periodEndDaa: number;
  totalStealthOutputs: number;
  totalStealthAmount: number;
  uniqueViewTags: number;
}

export function getSocket(): Socket {
  if (!socket) {
    socket = io(config.api.socketUrl, {
      transports: ['websocket', 'polling'],
      autoConnect: true,
      reconnection: true,
      reconnectionAttempts: 10,
      reconnectionDelay: 1000,
    });
    
    socket.on('connect', () => {
      console.log('Socket connected');
    });
    
    socket.on('disconnect', (reason) => {
      console.log('Socket disconnected:', reason);
    });
    
    socket.on('connect_error', (error) => {
      console.error('Socket connection error:', error);
    });
  }
  
  return socket;
}

export function joinRoom(room: 'blocks' | 'stealth'): void {
  const s = getSocket();
  s.emit('join', { room });
}

export function leaveRoom(room: 'blocks' | 'stealth'): void {
  const s = getSocket();
  s.emit('leave', { room });
}

export function onNewBlock(callback: (event: BlockAddedEvent) => void): () => void {
  const s = getSocket();
  s.on('new-block', callback);
  return () => s.off('new-block', callback);
}

export function onVirtualChainChanged(
  callback: (event: VirtualChainChangedEvent) => void
): () => void {
  const s = getSocket();
  s.on('virtual-chain-changed', callback);
  return () => s.off('virtual-chain-changed', callback);
}

export function onStealthStats(
  callback: (event: StealthStatsEvent) => void
): () => void {
  const s = getSocket();
  s.on('stealth-stats', callback);
  return () => s.off('stealth-stats', callback);
}

export function disconnectSocket(): void {
  if (socket) {
    socket.disconnect();
    socket = null;
  }
}
```

### 6. React Hook для realtime

#### app/hooks/useRealtimeBlocks.ts

```typescript
import { useEffect, useState, useCallback } from 'react';
import { 
  getSocket, 
  joinRoom, 
  leaveRoom, 
  onNewBlock, 
  onVirtualChainChanged,
  BlockAddedEvent,
  VirtualChainChangedEvent 
} from '../api/socket';

interface UseRealtimeBlocksOptions {
  maxBlocks?: number;
  onNewBlock?: (block: BlockAddedEvent) => void;
}

export function useRealtimeBlocks(options: UseRealtimeBlocksOptions = {}) {
  const { maxBlocks = 50, onNewBlock: onNewBlockCallback } = options;
  
  const [blocks, setBlocks] = useState<BlockAddedEvent[]>([]);
  const [isConnected, setIsConnected] = useState(false);
  
  useEffect(() => {
    const socket = getSocket();
    
    socket.on('connect', () => setIsConnected(true));
    socket.on('disconnect', () => setIsConnected(false));
    
    // Join blocks room
    joinRoom('blocks');
    
    // Subscribe to new blocks
    const unsubBlock = onNewBlock((event) => {
      setBlocks((prev) => {
        const newBlocks = [event, ...prev].slice(0, maxBlocks);
        return newBlocks;
      });
      
      onNewBlockCallback?.(event);
    });
    
    return () => {
      unsubBlock();
      leaveRoom('blocks');
    };
  }, [maxBlocks, onNewBlockCallback]);
  
  return {
    blocks,
    isConnected,
  };
}
```

---

## Docker

### Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source
COPY . .

# Expose port
EXPOSE 8081

# Run
CMD ["python", "server.py"]
```

### requirements.txt

```
fastapi==0.109.0
uvicorn[standard]==0.27.0
python-socketio==5.11.0
grpcio==1.60.0
grpcio-tools==1.60.0
protobuf==4.25.2
```

---

## Тестирование

### Unit tests

```python
# tests/test_events.py
import pytest
from models.events import BlockAddedEvent, StealthStatsEvent


def test_block_added_event_to_dict():
    event = BlockAddedEvent(
        hash='abc123',
        daa_score=1000,
        blue_score=999,
        timestamp=1703001234567,
        tx_count=5,
        is_chain_block=True,
        miner_address='qaspa:qz...',
        stealth_output_count=2,
        total_amount=100000000,
    )
    
    d = event.to_dict()
    
    assert d['hash'] == 'abc123'
    assert d['stealthOutputCount'] == 2
    assert d['totalAmount'] == 100000000


def test_stealth_stats_event():
    event = StealthStatsEvent(
        period_start_daa=1000,
        period_end_daa=1100,
        total_stealth_outputs=50,
        total_stealth_amount=5000000000,
        unique_view_tags=42,
    )
    
    d = event.to_dict()
    
    assert d['totalStealthOutputs'] == 50
    assert d['uniqueViewTags'] == 42
```

### Integration tests

```python
# tests/test_socket_integration.py
import pytest
import socketio

@pytest.mark.asyncio
async def test_socket_connection():
    sio = socketio.AsyncClient()
    
    connected = False
    
    @sio.event
    async def connect():
        nonlocal connected
        connected = True
        
    await sio.connect('http://localhost:8081')
    
    assert connected
    
    await sio.disconnect()


@pytest.mark.asyncio
async def test_join_room():
    sio = socketio.AsyncClient()
    
    await sio.connect('http://localhost:8081')
    await sio.emit('join', {'room': 'blocks'})
    
    # Should not raise
    await sio.disconnect()
```

---

## Checklist готовности этапа

- [ ] gRPC listener подключается к qaspad
- [ ] Подписка на новые блоки работает
- [ ] Подписка на virtual chain changed работает
- [ ] Stealth output count включён в события блоков
- [ ] Socket.IO сервер запускается
- [ ] Rooms работают (blocks, stealth)
- [ ] Frontend клиент обновлён
- [ ] React hooks созданы
- [ ] Health endpoint работает
- [ ] Docker image собирается
- [ ] Тесты написаны и проходят

