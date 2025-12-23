# Этап 0: Scope и Non-Goals

## Цель документа

Зафиксировать границы проекта Qaspa Explorer, чтобы команда понимала что делаем, а что — нет.

---

## Scope (что делаем)

### Обязательно (MVP)

1. **Block Explorer**
   - Просмотр блока по hash
   - Список последних блоков
   - DAG-визуализация (если есть в upstream)
   - Информация: daa_score, blue_score, timestamp, miner, transactions count

2. **Transaction Explorer**
   - Просмотр транзакции по txid
   - Inputs/Outputs с resolve previous outpoints
   - Статус: accepted/pending/rejected
   - Поддержка stealth outputs (view_tag, ephemeral_pubkey, destination_pubkey)

3. **Address Explorer (для non-stealth)**
   - Баланс адреса
   - UTXO списком
   - История транзакций (пагинация)
   - Поддержка всех типов адресов: `PubKey`, `PubKeyECDSA`, `PubKeyMLDSA`, `ScriptHash`

4. **Stealth Support**
   - Отображение stealth outputs в блоке/транзакции
   - View tags listing по блоку
   - Scan endpoint для кошельков (по view_tag + from_daa)
   - Корректная обработка `null` address для stealth outputs

5. **Network Info**
   - BlockDAG info (tip hashes, virtual info)
   - Coin supply
   - Network stats (hashrate estimate, difficulty)
   - Health/ping endpoint

6. **Realtime**
   - WebSocket/Socket.io для new blocks
   - Virtual chain changed events

### Желательно (Post-MVP)

1. **MLDSA Anchors/Delegations**
   - Страница со списком зарегистрированных anchors
   - Delegations по anchor
   - Требует: либо индексации, либо proxy к RPC

2. **Mempool**
   - Текущие pending транзакции
   - Статистика mempool

3. **Rich Analytics**
   - Графики TPS
   - Distribution of transaction sizes
   - Stealth vs non-stealth ratio

4. **Search**
   - Поиск по txid, block hash, address
   - Fuzzy search (если txid неполный)

---

## Non-Goals (что НЕ делаем)

1. **Wallet функционал**
   - Никаких приватных ключей
   - Никакого signing
   - Никакого "connect wallet"

2. **Stealth address tracking**
   - Публичный explorer НЕ может показать "историю stealth адреса"
   - Это приватная информация, требующая scan key
   - UI должен явно объяснять это пользователю

3. **Token/NFT explorer (Kasplex и т.п.)**
   - Пока не в scope
   - Можно добавить позже как отдельный модуль

4. **Mining pool dashboard**
   - Не наша задача

5. **Mobile app**
   - Только web (responsive)

---

## Технические ограничения

### Производительность

| Метрика | Цель |
|---------|------|
| GET /transactions/:id | < 100ms p95 |
| GET /blocks/:hash | < 50ms p95 |
| GET /addresses/:addr/balance | < 50ms p95 |
| GET /addresses/:addr/full-transactions | < 200ms p95 |
| Concurrent requests | 1000 RPS sustained |

### Данные

- Храним **всю историю** (не pruned)
- Индексируем только **accepted** транзакции (не orphaned)
- Stealth outputs индексируем отдельно для быстрого scan

### Совместимость

- REST API **mostly compatible** с `api.kaspa.org`
- Фронтенд работает с минимальными правками
- Допускаем расширение полей (добавление nullable полей не ломает клиентов)

---

## Принятые решения

| Вопрос | Решение | Обоснование |
|--------|---------|-------------|
| REST vs GraphQL | REST | Совместимость с существующим фронтом |
| БД | PostgreSQL | Проверено на kaspa-explorer, хорошо масштабируется |
| Язык API | Go | Производительность, простота деплоя |
| Схема БД | Новая | Нужна поддержка stealth/mldsa, старая схема не подходит |
| Индексатор | Fork kaspa-db-filler | Не переписывать с нуля, адаптировать |

---

## Stakeholders

- **Backend**: Go REST API, индексатор
- **Frontend**: React (kaspa-explorer-ng fork)
- **DevOps**: Docker Compose, возможно K8s позже
- **QA**: Integration tests, contract tests

---

## Checklist готовности этапа

- [ ] Документ согласован командой
- [ ] Non-goals явно озвучены стейкхолдерам
- [ ] Метрики производительности зафиксированы
- [ ] Технические решения задокументированы

