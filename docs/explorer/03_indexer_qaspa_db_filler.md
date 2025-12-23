# Этап 3: Индексатор (qaspa-db-filler)

## Цель

Адаптировать форк `kaspa-db-filler` под:
- Новую схему PostgreSQL (см. `02_data_model_and_queries.md`)
- Stealth outputs через RPC `get_block_view_tags`
- MLDSA типы адресов
- Сохранение поддержки публичных адресов

---

## Важные оговорки (чтобы не словить \"ложный компил\")\n+\n+- Примеры ниже — **скелеты**, их нужно подогнать под реальные protobuf-структуры и клиент, которые есть в вашем форке `qaspa-db-filler`.\n+- Критично: не используем зарезервированную колонку `index` в БД. Везде в схеме: `input_index` и `output_index`.\n+\n ---\n+\n ## Архитектура индексатора
## Архитектура индексатора

```
┌─────────────────────────────────────────────────────────────────┐
│                      qaspa-db-filler                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Listener   │───>│  Processor   │───>│   Writer     │      │
│  │   (gRPC)     │    │              │    │  (Postgres)  │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                   │                   │               │
│         │                   ▼                   │               │
│         │           ┌──────────────┐            │               │
│         │           │   Stealth    │            │               │
│         │           │   Enricher   │            │               │
│         │           │  (RPC call)  │            │               │
│         │           └──────────────┘            │               │
│         │                                       │               │
│         ▼                                       ▼               │
│  ┌──────────────┐                       ┌──────────────┐       │
│  │   qaspad     │                       │  PostgreSQL  │       │
│  │   (gRPC)     │                       │              │       │
│  └──────────────┘                       └──────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Ключевые изменения в форке

### 1. Новые SQLAlchemy модели

#### models/Block.py

```python
from sqlalchemy import Column, String, BigInteger, Boolean, Float, Text, TIMESTAMP
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.sql import func
from database import Base

class Block(Base):
    __tablename__ = 'blocks'

    hash = Column(String(64), primary_key=True)
    version = Column(BigInteger, nullable=False)
    
    # DAG info
    daa_score = Column(BigInteger, nullable=False, index=True)
    blue_score = Column(BigInteger, nullable=False, index=True)
    blue_work = Column(String(64), nullable=False)
    pruning_point = Column(String(64))
    
    # Timestamps
    timestamp = Column(BigInteger, nullable=False, index=True)
    
    # Merkle roots
    hash_merkle_root = Column(String(64), nullable=False)
    accepted_id_merkle_root = Column(String(64), nullable=False)
    utxo_commitment = Column(String(64), nullable=False)
    
    # Mining
    bits = Column(BigInteger, nullable=False)
    nonce = Column(String(20), nullable=False)
    
    # Verbose data
    difficulty = Column(Float)
    selected_parent_hash = Column(String(64))
    is_chain_block = Column(Boolean, default=False, index=True)
    
    # Extra
    miner_address = Column(String(128))
    miner_info = Column(Text)
    color = Column(String(16))
    
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())


class BlockParent(Base):
    __tablename__ = 'block_parents'

    block_hash = Column(String(64), primary_key=True)
    parent_hash = Column(String(64), primary_key=True, index=True)
    parent_level = Column(BigInteger, default=0)
```

#### models/Transaction.py

```python
from sqlalchemy import Column, String, BigInteger, Boolean, SmallInteger, LargeBinary, TIMESTAMP, Enum
from sqlalchemy.sql import func
from database import Base
import enum

class ScriptType(enum.Enum):
    pubkey = 'pubkey'
    pubkey_ecdsa = 'pubkey_ecdsa'
    pubkey_mldsa = 'pubkey_mldsa'
    script_hash = 'script_hash'
    stealth = 'stealth'
    non_standard = 'non_standard'


class Transaction(Base):
    __tablename__ = 'transactions'

    transaction_id = Column(String(64), primary_key=True)
    hash = Column(String(64), nullable=False, index=True)
    
    version = Column(SmallInteger, nullable=False)
    lock_time = Column(BigInteger, nullable=False)
    subnetwork_id = Column(String(40), nullable=False)
    gas = Column(BigInteger, default=0)
    payload = Column(LargeBinary)
    mass = Column(BigInteger, nullable=False)
    
    # Acceptance
    is_accepted = Column(Boolean, default=False)
    accepting_block_hash = Column(String(64), index=True)
    accepting_block_blue_score = Column(BigInteger)
    block_time = Column(BigInteger, index=True)
    
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())


class TransactionBlock(Base):
    __tablename__ = 'transaction_blocks'

    transaction_id = Column(String(64), primary_key=True)
    block_hash = Column(String(64), primary_key=True, index=True)


class TxInput(Base):
    __tablename__ = 'tx_inputs'

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    transaction_id = Column(String(64), nullable=False, index=True)
    input_index = Column(BigInteger, nullable=False)
    
    previous_outpoint_hash = Column(String(64), nullable=False)
    previous_outpoint_index = Column(BigInteger, nullable=False)
    
    signature_script = Column(LargeBinary, nullable=False)
    sig_op_count = Column(BigInteger, default=0)
    sequence = Column(BigInteger, default=0)


class TxOutput(Base):
    __tablename__ = 'tx_outputs'

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    transaction_id = Column(String(64), nullable=False, index=True)
    output_index = Column(BigInteger, nullable=False)
    
    amount = Column(BigInteger, nullable=False)
    
    script_public_key = Column(LargeBinary, nullable=False)
    script_version = Column(SmallInteger, default=0)
    script_type = Column(Enum(ScriptType), nullable=False)
    
    # NULL для stealth и non_standard
    script_public_key_address = Column(String(128), index=True)
    
    # Spending
    is_spent = Column(Boolean, default=False)
    spending_tx_id = Column(String(64))
    spending_input_index = Column(BigInteger)
```

#### models/Stealth.py (новый файл)

```python
from sqlalchemy import Column, String, BigInteger, Boolean, SmallInteger, TIMESTAMP
from sqlalchemy.sql import func
from database import Base


class StealthOutput(Base):
    __tablename__ = 'stealth_outputs'

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    
    transaction_id = Column(String(64), nullable=False)
    output_index = Column(BigInteger, nullable=False)
    
    # Stealth-specific
    view_tag = Column(SmallInteger, nullable=False)  # 0-255
    ephemeral_pubkey = Column(String(66), nullable=False)
    destination_pubkey = Column(String(66), nullable=False)
    
    amount = Column(BigInteger, nullable=False)
    
    # Block info (denormalized)
    block_hash = Column(String(64), nullable=False)
    block_daa_score = Column(BigInteger, nullable=False, index=True)
    block_time = Column(BigInteger, nullable=False)
    
    anchor_hint = Column(String(64))
    is_coinbase = Column(Boolean, default=False)
    is_spent = Column(Boolean, default=False)


class Utxo(Base):
    __tablename__ = 'utxos'

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    
    transaction_id = Column(String(64), nullable=False)
    output_index = Column(BigInteger, nullable=False)
    
    address = Column(String(128), nullable=False, index=True)
    amount = Column(BigInteger, nullable=False)
    
    script_public_key = Column(LargeBinary, nullable=False)
    script_type = Column(String(16), nullable=False)
    
    is_coinbase = Column(Boolean, default=False)
    block_daa_score = Column(BigInteger, nullable=False)


class AddressTx(Base):
    __tablename__ = 'address_tx'

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    
    address = Column(String(128), nullable=False, index=True)
    transaction_id = Column(String(64), nullable=False)
    
    is_input = Column(Boolean, nullable=False)
    amount = Column(BigInteger, nullable=False)
    
    block_daa_score = Column(BigInteger, nullable=False)
    block_time = Column(BigInteger, nullable=False)
```

---

### 2. Stealth Enricher

Новый модуль для получения stealth данных через RPC:

#### stealth_enricher.py

```python
import asyncio
from typing import List, Dict, Optional
from kaspad_client import KaspadClient
import logging

logger = logging.getLogger(__name__)


class StealthEnricher:
    """
    Обогащает данные блока информацией о stealth outputs
    через RPC get_block_view_tags.
    """
    
    def __init__(self, kaspad_client: KaspadClient):
        self.client = kaspad_client
    
    async def get_stealth_outputs(self, block_hash: str) -> List[Dict]:
        """
        Получает stealth outputs из блока через RPC.
        
        Returns:
            List of stealth output info:
            [
                {
                    "transaction_id": "...",
                    "output_index": 0,
                    "view_tag": 42,
                    "ephemeral_pubkey": "02...",
                    "destination_pubkey": "03...",
                    "amount": 100000000,
                    "is_coinbase": False,
                    "anchor_hint": "abc123..." | None
                },
                ...
            ]
        """
        try:
            response = await self.client.get_block_view_tags(block_hash)
            
            if not response or 'stealthOutputs' not in response:
                return []
            
            outputs = []
            for output in response['stealthOutputs']:
                outputs.append({
                    'transaction_id': output['transactionId'],
                    'output_index': output['outputIndex'],
                    'view_tag': output['viewTag'],
                    'ephemeral_pubkey': output['ephemeralPubkey'],
                    'destination_pubkey': output['destinationPubkey'],
                    'amount': output['amount'],
                    'is_coinbase': output.get('isCoinbase', False),
                    'anchor_hint': output.get('anchorHint'),
                })
            
            return outputs
            
        except Exception as e:
            logger.error(f"Failed to get stealth outputs for block {block_hash}: {e}")
            return []
    
    def build_stealth_lookup(self, stealth_outputs: List[Dict]) -> Dict[tuple, Dict]:
        """
        Создаёт lookup dict: (tx_id, output_index) -> stealth_info
        """
        lookup = {}
        for output in stealth_outputs:
            key = (output['transaction_id'], output['output_index'])
            lookup[key] = output
        return lookup
```

---

### 3. Обновлённый Block Processor

#### block_processor.py

```python
import asyncio
from typing import List, Dict, Optional
from sqlalchemy.orm import Session
from models import Block, BlockParent, Transaction, TransactionBlock
from models import TxInput, TxOutput, StealthOutput, Utxo, AddressTx, ScriptType
from stealth_enricher import StealthEnricher
from address_utils import parse_script_public_key, get_script_type
import logging

logger = logging.getLogger(__name__)

# Stealth script version
SCRIPT_VERSION_STEALTH = 16

# MLDSA script version  
SCRIPT_VERSION_MLDSA = 2


class BlockProcessor:
    def __init__(self, session: Session, stealth_enricher: StealthEnricher):
        self.session = session
        self.stealth_enricher = stealth_enricher
    
    async def process_block(self, block_data: Dict, is_chain_block: bool = False):
        """
        Обрабатывает блок и все его транзакции.
        """
        block_hash = block_data['verboseData']['hash']
        
        # 1. Получаем stealth данные для блока
        stealth_outputs = await self.stealth_enricher.get_stealth_outputs(block_hash)
        stealth_lookup = self.stealth_enricher.build_stealth_lookup(stealth_outputs)
        
        # 2. Сохраняем блок
        block = self._save_block(block_data, is_chain_block)
        
        # 3. Сохраняем parent hashes
        self._save_block_parents(block_hash, block_data)
        
        # 4. Обрабатываем транзакции
        for tx_data in block_data.get('transactions', []):
            await self._process_transaction(
                tx_data, 
                block_hash,
                block.daa_score,
                block.timestamp,
                stealth_lookup
            )
        
        self.session.commit()
        logger.info(f"Processed block {block_hash[:16]}... with {len(block_data.get('transactions', []))} txs")
    
    def _save_block(self, block_data: Dict, is_chain_block: bool) -> Block:
        header = block_data['header']
        verbose = block_data['verboseData']
        extra = block_data.get('extra', {})
        
        block = Block(
            hash=verbose['hash'],
            version=header['version'],
            daa_score=int(header['daaScore']),
            blue_score=int(header['blueScore']),
            blue_work=header['blueWork'],
            pruning_point=header.get('pruningPoint'),
            timestamp=int(header['timestamp']),
            hash_merkle_root=header['hashMerkleRoot'],
            accepted_id_merkle_root=header['acceptedIdMerkleRoot'],
            utxo_commitment=header['utxoCommitment'],
            bits=header['bits'],
            nonce=str(header['nonce']),
            difficulty=verbose.get('difficulty'),
            selected_parent_hash=verbose.get('selectedParentHash'),
            is_chain_block=is_chain_block,
            miner_address=extra.get('minerAddress'),
            miner_info=extra.get('minerInfo'),
            color=extra.get('color'),
        )
        
        self.session.merge(block)
        return block
    
    def _save_block_parents(self, block_hash: str, block_data: Dict):
        header = block_data['header']
        parents = header.get('parents', [])
        
        for level, parent_group in enumerate(parents):
            for parent_hash in parent_group.get('parentHashes', []):
                parent = BlockParent(
                    block_hash=block_hash,
                    parent_hash=parent_hash,
                    parent_level=level
                )
                self.session.merge(parent)
    
    async def _process_transaction(
        self, 
        tx_data: Dict, 
        block_hash: str,
        block_daa_score: int,
        block_time: int,
        stealth_lookup: Dict
    ):
        verbose = tx_data.get('verboseData', {})
        tx_id = verbose.get('transactionId')
        
        if not tx_id:
            return
        
        # 1. Сохраняем транзакцию
        tx = Transaction(
            transaction_id=tx_id,
            hash=verbose.get('hash', tx_id),
            version=tx_data['version'],
            lock_time=tx_data['lockTime'],
            subnetwork_id=tx_data['subnetworkId'],
            gas=tx_data.get('gas', 0),
            payload=bytes.fromhex(tx_data.get('payload', '')) if tx_data.get('payload') else None,
            mass=tx_data.get('mass', verbose.get('computeMass', 0)),
            is_accepted=True,  # Будет обновлено при virtual chain changed
            accepting_block_hash=block_hash,
            accepting_block_blue_score=block_daa_score,
            block_time=block_time,
        )
        self.session.merge(tx)
        
        # 2. Связь tx <-> block
        tx_block = TransactionBlock(
            transaction_id=tx_id,
            block_hash=block_hash
        )
        self.session.merge(tx_block)
        
        # 3. Inputs
        address_amounts: Dict[str, int] = {}  # для address_tx
        
        for i, input_data in enumerate(tx_data.get('inputs', [])):
            prevout = input_data['previousOutpoint']
            
            tx_input = TxInput(
                transaction_id=tx_id,
                input_index=i,
                previous_outpoint_hash=prevout['transactionId'],
                previous_outpoint_index=prevout['index'],
                signature_script=bytes.fromhex(input_data.get('signatureScript', '')),
                sig_op_count=input_data.get('sigOpCount', 0),
                sequence=input_data.get('sequence', 0),
            )
            self.session.add(tx_input)
            
            # Помечаем потраченный output
            await self._mark_output_spent(
                prevout['transactionId'],
                prevout['index'],
                tx_id,
                i,
                address_amounts
            )
        
        # 4. Outputs
        is_coinbase = tx_data['subnetworkId'] == '0000000000000000000000000000000000000001'
        
        # В большинстве источников output index не приходит как поле, это позиция в массиве.
        for output_index, output in enumerate(tx_data.get('outputs', [])):
            spk = output['scriptPublicKey']
            script_bytes = bytes.fromhex(spk['scriptPublicKey'])
            script_version = spk.get('version', 0)
            
            # Определяем тип скрипта и адрес
            script_type, address = self._parse_output_script(
                script_bytes, 
                script_version,
                output.get('verboseData', {})
            )
            
            tx_output = TxOutput(
                transaction_id=tx_id,
                output_index=output_index,
                amount=output['amount'],
                script_public_key=script_bytes,
                script_version=script_version,
                script_type=script_type,
                script_public_key_address=address,
            )
            self.session.add(tx_output)
            
            # Если это stealth output - сохраняем дополнительно
            stealth_key = (tx_id, output_index)
            if stealth_key in stealth_lookup:
                stealth_info = stealth_lookup[stealth_key]
                stealth_output = StealthOutput(
                    transaction_id=tx_id,
                    output_index=output_index,
                    view_tag=stealth_info['view_tag'],
                    ephemeral_pubkey=stealth_info['ephemeral_pubkey'],
                    destination_pubkey=stealth_info['destination_pubkey'],
                    amount=output['amount'],
                    block_hash=block_hash,
                    block_daa_score=block_daa_score,
                    block_time=block_time,
                    anchor_hint=stealth_info.get('anchor_hint'),
                    is_coinbase=is_coinbase,
                )
                self.session.add(stealth_output)
            
            # Если есть адрес - добавляем в UTXO и address_tx
            if address:
                utxo = Utxo(
                    transaction_id=tx_id,
                    output_index=output_index,
                    address=address,
                    amount=output['amount'],
                    script_public_key=script_bytes,
                    script_type=script_type.value,
                    is_coinbase=is_coinbase,
                    block_daa_score=block_daa_score,
                )
                self.session.add(utxo)
                
                # Накапливаем для address_tx
                if address not in address_amounts:
                    address_amounts[address] = 0
                address_amounts[address] += output['amount']
        
        # 5. Сохраняем address_tx записи
        for address, amount in address_amounts.items():
            addr_tx = AddressTx(
                address=address,
                transaction_id=tx_id,
                is_input=amount < 0,
                amount=abs(amount),
                block_daa_score=block_daa_score,
                block_time=block_time,
            )
            self.session.add(addr_tx)
    
    def _parse_output_script(
        self, 
        script_bytes: bytes, 
        script_version: int,
        verbose_data: Dict
    ) -> tuple[ScriptType, Optional[str]]:
        """
        Парсит script и возвращает (тип, адрес или None).
        """
        # Stealth
        if script_version == SCRIPT_VERSION_STEALTH:
            return ScriptType.stealth, None
        
        # Из verbose data если есть
        address = verbose_data.get('scriptPublicKeyAddress')
        script_type_str = verbose_data.get('scriptPublicKeyType', 'non_standard')
        
        # Map string to enum
        type_mapping = {
            'pubkey': ScriptType.pubkey,
            'pubkeyecdsa': ScriptType.pubkey_ecdsa,
            'pubkeymldsa': ScriptType.pubkey_mldsa,
            'scripthash': ScriptType.script_hash,
            'nonstandard': ScriptType.non_standard,
        }
        
        script_type = type_mapping.get(
            script_type_str.lower().replace('_', '').replace('-', ''),
            ScriptType.non_standard
        )
        
        return script_type, address
    
    async def _mark_output_spent(
        self,
        prev_tx_id: str,
        prev_index: int,
        spending_tx_id: str,
        spending_input_index: int,
        address_amounts: Dict[str, int]
    ):
        """
        Помечает output как потраченный и удаляет из UTXO.
        """
        # Update tx_outputs
        self.session.execute(
            """
            UPDATE tx_outputs 
            SET is_spent = TRUE,
                spending_tx_id = :spending_tx_id,
                spending_input_index = :spending_input_index
            WHERE transaction_id = :prev_tx_id 
              AND output_index = :prev_index
            RETURNING script_public_key_address, amount
            """,
            {
                'spending_tx_id': spending_tx_id,
                'spending_input_index': spending_input_index,
                'prev_tx_id': prev_tx_id,
                'prev_index': prev_index,
            }
        )
        
        # Delete from utxos
        result = self.session.execute(
            """
            DELETE FROM utxos 
            WHERE transaction_id = :prev_tx_id 
              AND output_index = :prev_index
            RETURNING address, amount
            """,
            {'prev_tx_id': prev_tx_id, 'prev_index': prev_index}
        )
        
        # Update stealth_outputs
        self.session.execute(
            """
            UPDATE stealth_outputs 
            SET is_spent = TRUE
            WHERE transaction_id = :prev_tx_id 
              AND output_index = :prev_index
            """,
            {'prev_tx_id': prev_tx_id, 'prev_index': prev_index}
        )
        
        # Track for address_tx (negative = spent)
        for row in result:
            address, amount = row
            if address:
                if address not in address_amounts:
                    address_amounts[address] = 0
                address_amounts[address] -= amount
```

---

### 4. Конфигурация

#### config.py

```python
import os
from dataclasses import dataclass

@dataclass
class Config:
    # Kaspad connection
    kaspad_host: str = os.getenv('KASPAD_HOST', 'localhost:16110')
    
    # Database
    database_url: str = os.getenv('DATABASE_URL', 'postgresql://qaspa:qaspa@localhost:5432/qaspa')
    
    # Processing
    batch_size: int = int(os.getenv('BATCH_SIZE', '100'))
    start_from_daa: int = int(os.getenv('START_FROM_DAA', '0'))
    
    # Feature flags
    enable_stealth_indexing: bool = os.getenv('ENABLE_STEALTH_INDEXING', 'true').lower() == 'true'
    enable_utxo_table: bool = os.getenv('ENABLE_UTXO_TABLE', 'true').lower() == 'true'
    enable_address_tx: bool = os.getenv('ENABLE_ADDRESS_TX', 'true').lower() == 'true'
```

---

## Команды запуска

### Локально

```bash
cd repos/qaspa-db-filler

# Установка зависимостей
pip install -r requirements.txt

# Настройка окружения
cp .env.example .env
# Edit .env

# Запуск миграций (из qaspa-rest-api)
cd ../qaspa-rest-api
goose -dir db/migrations postgres "$DATABASE_URL" up

# Запуск индексатора
cd ../qaspa-db-filler
python main.py
```

### Docker

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "main.py"]
```

```yaml
# docker-compose.yml (часть)
services:
  db-filler:
    build: ./repos/qaspa-db-filler
    environment:
      - KASPAD_HOST=qaspad:16110
      - DATABASE_URL=postgresql://qaspa:qaspa@postgres:5432/qaspa
      - ENABLE_STEALTH_INDEXING=true
    depends_on:
      - postgres
      - qaspad
    restart: unless-stopped
```

---

## Тестирование индексатора

### Unit tests

```python
# tests/test_stealth_enricher.py
import pytest
from stealth_enricher import StealthEnricher

class MockKaspadClient:
    async def get_block_view_tags(self, block_hash):
        return {
            'stealthOutputs': [
                {
                    'transactionId': 'tx123',
                    'outputIndex': 0,
                    'viewTag': 42,
                    'ephemeralPubkey': '02' + 'a' * 64,
                    'destinationPubkey': '03' + 'b' * 64,
                    'amount': 100000000,
                    'isCoinbase': False,
                }
            ]
        }

@pytest.mark.asyncio
async def test_get_stealth_outputs():
    client = MockKaspadClient()
    enricher = StealthEnricher(client)
    
    outputs = await enricher.get_stealth_outputs('block_hash')
    
    assert len(outputs) == 1
    assert outputs[0]['view_tag'] == 42
    assert outputs[0]['transaction_id'] == 'tx123'

def test_build_stealth_lookup():
    enricher = StealthEnricher(None)
    outputs = [
        {'transaction_id': 'tx1', 'output_index': 0, 'view_tag': 1},
        {'transaction_id': 'tx1', 'output_index': 1, 'view_tag': 2},
    ]
    
    lookup = enricher.build_stealth_lookup(outputs)
    
    assert ('tx1', 0) in lookup
    assert ('tx1', 1) in lookup
    assert lookup[('tx1', 0)]['view_tag'] == 1
```

### Integration tests

```python
# tests/test_block_processor.py
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import Base, Block, Transaction, StealthOutput

@pytest.fixture
def test_db():
    engine = create_engine('postgresql://test:test@localhost:5432/qaspa_test')
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()
    Base.metadata.drop_all(engine)

@pytest.mark.asyncio
async def test_process_block_with_stealth(test_db):
    # ... test implementation
    pass
```

---

## Checklist готовности этапа

- [ ] SQLAlchemy модели обновлены под новую схему
- [ ] StealthEnricher реализован и протестирован
- [ ] BlockProcessor обновлён для stealth outputs
- [ ] UTXO и address_tx таблицы заполняются корректно
- [ ] Unit tests написаны и проходят
- [ ] Integration tests с реальной БД проходят
- [ ] Индексатор успешно обрабатывает тестовые блоки
- [ ] Документация обновлена

