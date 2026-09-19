---
name: data-engineering
description: Design and reason about data systems: databases, storage engines, replication, partitioning, transactions, consistency, batch and stream processing, schema evolution and data pipelines. Use when choosing a database or data model, designing a pipeline or event-driven system, diagnosing consistency or replication issues, planning schema migrations, or evaluating trade-offs in distributed data systems. Distilled from Designing Data-Intensive Applications (Kleppmann) with construction practices from Code Complete and The Pragmatic Programmer.
---

# Data Engineering

A data-intensive application is limited by data volume, complexity, and rate
of change rather than CPU. The job is to compose storage, caches, indexes,
queues, and processors into a system that is **reliable** (works correctly
under faults), **scalable** (has a plan for growth), and **maintainable**
(operable, simple, evolvable). Every choice below is a trade-off; know which
one you are making.

## 1. Foundations (DDIA ch. 1)

- **Reliability:** tolerate hardware faults (redundancy), software faults
  (careful assumptions, isolation, monitoring), human error (good abstractions,
  sandboxes, fast rollback, telemetry). Faults are inevitable; failures are
  what you prevent. Deliberately inject faults (chaos) to verify.
- **Scalability:** first define load (requests/s, read/write ratio, fan-out,
  working set size, concurrent users) and performance (throughput, latency
  *percentiles*: p50, p95, p99). Tail latency matters because one slow call in
  a fan-out slows the whole request. Scaling up (bigger machine) is simpler
  than scaling out; do it first. A scalable architecture is built from
  general-purpose blocks arranged for *your* load, not copied from a bigger
  company.
- **Maintainability:** operability (visibility, automation, good defaults),
  simplicity (remove accidental complexity with abstraction), evolvability
  (easy to change; see schema evolution).

## 2. Data models (DDIA ch. 2)

| Model | Fits | Struggles with |
|---|---|---|
| Relational | many-to-many, joins, ad-hoc queries, strong schema | deeply nested documents, impedance mismatch with objects |
| Document (JSON) | self-contained trees, locality, schema flexibility | joins, many-to-many, updating deep fields |
| Graph | highly connected data, variable-depth traversal, evolving relationships | simple tabular workloads |

- **Schema-on-write vs schema-on-read** is the real difference, not
  "schemaless". Document stores still have a schema; it lives in application
  code and is enforced late.
- **Normalise for consistency, denormalise for read speed.** Denormalisation
  is a cache; it needs a plan to keep it consistent.
- **Query language matters:** declarative (SQL, Cypher) lets the engine
  optimise and parallelise; imperative (application loops) does not.
- Ask: how do relationships look now, and how might they look in two years?
  If "many-to-many" is likely, start relational.

## 3. Storage engines and indexes (DDIA ch. 3)

- **Log-structured (LSM trees):** append-only writes to a memtable, flushed to
  sorted string tables (SSTables), merged by compaction. Fast writes, good
  compression, background compaction can spike latency. (Cassandra, RocksDB,
  LevelDB, HBase.)
- **Page-oriented (B-trees):** fixed-size pages updated in place, write-ahead
  log for crash recovery. Predictable reads, each key in one place, so strong
  transactional semantics are easier. (PostgreSQL, MySQL InnoDB, most
  relational DBs.)
- Rule of thumb: write-heavy with big values leans LSM; read-heavy or
  transactional leans B-tree. Measure with your workload.
- **Indexes** speed reads and slow writes. Every index is a derived data
  structure. Secondary indexes, multi-column, covering, full-text, and
  in-memory are variations on the same trade.
- **OLTP vs OLAP:** transaction processing (small, indexed, latency-critical)
  vs analytics (scan millions of rows, few columns). Do not run both on one
  system; ETL/ELT into a **data warehouse**.
- **Column-oriented storage** for analytics: each column stored separately,
  heavily compressed (bitmap, run-length), sorted, vectorised. Star/snowflake
  schemas: fact table plus dimension tables. Materialised views and data
  cubes precompute aggregates.

## 4. Encoding and schema evolution (DDIA ch. 4)

- Data outlives code. Old and new code will run at the same time (rolling
  deploys) and old data will be read by new code for years.
- **Backward compatibility:** new code reads old data. **Forward
  compatibility:** old code reads new data. You need both.
- **Language-specific serialisation** (pickle, Java serialisation) is a
  security risk and locks you in. Never use it for storage or wire formats.
- **JSON/XML/CSV:** human-readable, ambiguous about numbers, no schema, verbose.
  Fine for APIs; poor for long-term storage and large volume.
- **Binary schema formats** (Protocol Buffers, Thrift, Avro): compact, schema
  as documentation, compatibility checked by tooling. Rules: never reuse a
  field tag/number; new fields must be optional or have defaults; removing a
  field is fine only if it was optional. Avro handles schema evolution with
  reader/writer schema resolution and is well suited to dynamically generated
  schemas and Hadoop-style files.
- **Dataflow modes:** through databases (writer and reader are different
  versions), through services (REST/RPC; the server is upgraded before
  clients, or vice versa, so compatibility both ways), through message
  brokers (asynchronous, decoupled, one-to-many).
- Practical: put a schema registry in front of every topic; version your
  event schemas; run a compatibility check in CI.

## 5. Replication (DDIA ch. 5)

Keep copies on several nodes for latency, availability, and read scaling.

- **Single-leader:** writes to one node, replicated to followers. Simple,
  conflict-free, but leader is a bottleneck and failover is hard (choose a
  timeout, elect a new leader, avoid split brain, decide what to do with
  writes the old leader had not replicated).
- **Multi-leader:** leaders in several datacenters or offline clients.
  Better latency and tolerance, but **write conflicts** must be resolved:
  last-write-wins (loses data), merge by application, or CRDTs.
- **Leaderless (Dynamo-style):** client writes to n nodes, reads from r,
  quorum when w + r > n. Tolerates node failures without failover; needs
  read repair and anti-entropy; quorums do not give linearizability.
- **Synchronous vs asynchronous replication:** sync guarantees durability
  on followers but stalls on any slow follower; async is faster but a
  failed leader loses unreplicated writes. Semi-synchronous is common.
- **Replication lag** produces anomalies. Decide which guarantees the
  application needs:
  - **Read-your-writes:** a user sees their own updates (route their reads to
    the leader for a while after a write, or track write timestamps).
  - **Monotonic reads:** no going back in time (pin a user to one replica).
  - **Consistent prefix reads:** causally related writes appear in order
    (write causally related data to the same partition).
- Log formats: statement-based (non-deterministic functions break it),
  WAL shipping (tied to storage engine version), logical/row-based (best for
  evolution and change data capture), trigger-based (flexible, slow).

## 6. Partitioning / sharding (DDIA ch. 6)

- **By key range:** sorted, efficient range scans, risk of hot spots
  (timestamps as keys put all today's writes on one partition; prefix the key
  with something else).
- **By hash of key:** even distribution, no range scans. Compound keys
  (hash the first part, sort by the rest) give both.
- **Secondary indexes:** document-partitioned (local index, scatter/gather
  reads) or term-partitioned (global index, slower asynchronous writes).
- **Rebalancing:** never `hash mod N` (everything moves when N changes).
  Use fixed number of partitions (many more than nodes), dynamic splitting,
  or partitions proportional to nodes. Rebalance automatically with care, or
  manually; a fully automatic rebalancer during a partial outage can cascade.
- **Request routing:** coordination service (ZooKeeper), routing tier, or
  partition-aware clients.
- Hot keys (a celebrity account) need application-level spreading
  (append a random suffix, then aggregate on read).

## 7. Transactions (DDIA ch. 7)

- **ACID** is marketing until you define each letter: Atomicity (abort
  restores state), Consistency (application invariants; the DB cannot
  guarantee it alone), Isolation (concurrent transactions do not see each
  other's half-done work), Durability (committed data survives crashes,
  which in practice means replicated to disk on multiple nodes).
- **Weak isolation levels** and what they allow:
  - *Read committed:* no dirty reads or dirty writes. Still allows
    non-repeatable reads and lost updates.
  - *Snapshot isolation / repeatable read (MVCC):* each transaction sees a
    consistent snapshot. Great for long read-only queries and backups. Still
    allows lost updates (fix with atomic ops, explicit locking `SELECT ... FOR
    UPDATE`, compare-and-set, or automatic detection) and **write skew**
    (two transactions read overlapping data, each writes a different row,
    together they break an invariant: doctors on call, meeting room booking,
    username uniqueness). Write skew's root is a **phantom**: a write changes
    the result of another transaction's earlier search.
  - *Serializable:* the only level that prevents all anomalies.
- **Serializable implementations:** actual serial execution (single thread,
  in-memory, stored procedures: VoltDB, Redis), two-phase locking (2PL, shared
  and exclusive locks, predicate/index-range locks, prone to deadlock and
  unstable latency), **serializable snapshot isolation** (SSI: optimistic,
  detects conflicting reads/writes at commit, aborts losers; PostgreSQL's
  SERIALIZABLE).
- Practical: default to snapshot isolation; for invariants that span rows,
  use SERIALIZABLE or materialise the conflict (a row per bookable slot to
  lock). Keep transactions short. Retry on abort with idempotent logic.

## 8. Trouble with distributed systems (DDIA ch. 8)

Assume everything can fail partially and silently.

- **Networks are unreliable:** packets drop, delay, reorder, duplicate; a
  timeout does not tell you whether the request was processed. Choose
  timeouts empirically and adaptively; too short causes false failovers, too
  long delays recovery.
- **Clocks are unreliable:** time-of-day clocks jump (NTP), monotonic clocks
  are only meaningful on one node. Never use timestamps to order events
  across nodes (last-write-wins with wall clocks silently drops writes).
  Google's TrueTime exposes confidence intervals; without that, use
  logical clocks.
- **Process pauses:** GC, VM migration, swapping, disk I/O can pause a
  process for seconds while it believes it is the leader. Any lease/lock must
  be checked with a **fencing token** (monotonically increasing number
  checked by the storage service) so an old holder cannot write.
- **Truth is defined by majority.** A node cannot know it has been declared
  dead. Quorum decisions are the mechanism.
- **Byzantine faults** (nodes lying) are usually out of scope, but validate
  inputs and checksums anyway.
- **System model:** decide explicitly which faults you handle: crash-stop,
  crash-recovery, partially synchronous network. Then design and test for
  that model.

## 9. Consistency and consensus (DDIA ch. 9)

- **Linearizability:** the system behaves as one copy with atomic
  operations; every read returns the latest write. Needed for leader
  election, uniqueness constraints, locks. Costly: CAP says that under a
  network partition you choose linearizable (unavailable) or available
  (not linearizable). Cross-datacenter linearizability adds the round trip
  to every request.
- **Ordering and causality:** causal consistency is weaker than
  linearizability and can be available. **Lamport timestamps** give a total
  order consistent with causality but cannot tell you when the order is
  final. **Version vectors** capture concurrency.
- **Total order broadcast** = consensus: every node delivers the same
  messages in the same order. It is a replicated log, and it gives
  linearizable storage, fencing tokens, and state machine replication.
- **Two-phase commit (2PC)** for atomic commit across systems: a coordinator
  asks all participants to prepare, then commit. Blocking if the coordinator
  crashes after prepare. XA/distributed transactions across heterogeneous
  systems are operationally painful; avoid unless there is no alternative.
- **Consensus algorithms** (Paxos, Raft, Zab): safety (uniform agreement,
  integrity, validity) and liveness (termination given a majority). Used
  inside ZooKeeper/etcd/Consul for leader election, membership, locks,
  configuration. Use those services; do not implement consensus yourself.
- Many systems avoid needing consensus by: making operations commutative,
  accepting eventual consistency, or funnelling the critical decision through
  a single leader elected once.

## 10. Batch processing (DDIA ch. 10)

- **Unix philosophy:** small tools, uniform interface (byte streams),
  immutable inputs, output to a new place, so any stage can be re-run.
  Batch systems are this at cluster scale.
- **MapReduce:** map (extract key/value), shuffle/sort by key, reduce
  (aggregate). Inputs immutable, outputs written once, failed tasks retried,
  so it is fault-tolerant and easy to reason about.
- **Joins in batch:** sort-merge join (both sides partitioned by key),
  broadcast hash join (small side fits in memory), partitioned hash join.
  Handle **hot keys** (skew) by spreading them across reducers.
- **Dataflow engines** (Spark, Flink, Tez): operators chained in memory,
  no intermediate materialisation to disk, scheduler-aware of the whole
  job graph. Same programming model as MapReduce, far faster. Recompute
  lost partitions from lineage.
- **Outputs:** build search indexes, key-value stores, ML models, and load
  them atomically (write to a new file/table, then switch). Never mutate
  the production store from inside a batch job.
- **Batch is the safe default** for derived data: deterministic,
  re-runnable, and a bug means "fix and rerun" rather than "fix and
  repair".

## 11. Stream processing (DDIA ch. 11)

- An **event** is an immutable fact with a timestamp. A **log** is an
  append-only, totally ordered sequence of events per partition (Kafka,
  Kinesis, Pulsar). Consumers track an offset; replay is cheap.
- **Message brokers:** AMQP/JMS style (broker deletes on ack, per-message
  routing, good for task queues, order not preserved under redelivery) vs
  **log-based** (retention by time/size, consumers independent, ordering
  per partition, replay). Default to log-based for data integration.
- **Change data capture (CDC):** treat the database's replication log as an
  event stream; derived systems (search, cache, warehouse) subscribe. The
  database of record becomes the leader; all others are followers. Log
  compaction keeps the latest value per key so a new consumer can bootstrap.
- **Event sourcing:** store the events (user intent) rather than current
  state; derive state by replaying. Auditability and easy new views; needs
  snapshots and careful schema evolution because events are forever.
- **Time:** event time vs processing time. Windows (tumbling, hopping,
  sliding, session) are defined on event time; **straggler** events arrive
  late, so decide: drop, correct a published result, or wait a bounded time.
- **Stream joins:** stream-stream (buffer both within a window),
  stream-table (keep a local, CDC-updated copy of the table), table-table
  (materialised view maintenance). Joins are time-dependent; order of
  arrival can change the result.
- **Fault tolerance:** micro-batching/checkpointing, idempotence, and
  atomic commit of output + offset give effective **exactly-once**
  (really "effectively once"). At-least-once delivery plus idempotent
  consumers is the practical default. Make every consumer safe to replay.
- **Immutability and derived data:** keep the raw event log; every other
  store is a cache that can be rebuilt. "Turning the database inside out."

## 12. Designing the whole system (DDIA ch. 12)

- **Derived data over distributed transactions:** instead of 2PC across
  a DB, a search index, and a cache, write once to a log and let each
  system consume it asynchronously. Ordering within a partition gives
  determinism; idempotence gives safety.
- **Dataflow architecture:** application = stream processors over event
  logs; databases are materialised views. Read paths and write paths are
  separated (CQRS) and you choose how much work to do at write time
  (precompute) versus read time.
- **End-to-end argument:** exactly-once inside the pipeline is not enough;
  a client retry can still duplicate. Give every operation a
  client-generated **idempotency key** carried end to end.
- **Integrity vs timeliness:** integrity (no corruption, no loss) is what
  matters; timeliness (readers see fresh data) is negotiable. Build for
  eventual consistency with strong integrity: immutable events, deterministic
  derivation, idempotence, and end-to-end IDs. Detect violations with
  audits and checksums; trust nothing silently.
- **Unbundling the database:** compose specialised tools (OLTP store, search,
  cache, warehouse, stream processor) via logs rather than reaching for
  one system that does all things badly.

## 13. Construction practices for pipelines (Pragmatic Programmer, Code Complete)

- **Make pipelines idempotent and re-runnable** from any stage with the same
  inputs. Partition outputs by run/date so reruns overwrite cleanly.
- **Validate at boundaries:** schema check on ingest, row counts and
  null-rate checks between stages, reconciliation against source at the end.
  Fail loudly and early ("crash early"); a silently truncated dataset is
  worse than no dataset.
- **Keep transformations pure** (input tables in, output tables out); put
  I/O in thin readers and writers. Test transformations with small in-memory
  frames.
- **Configuration and orthogonality:** environment (paths, credentials,
  cluster sizes) in config, not code. The same job runs locally, in CI, and in
  production.
- **Observability:** log structured records with a run ID; emit metrics for
  rows in/out, lag, and duration; alert on freshness, not just failure.
- **Tracer bullets:** build an end-to-end skeleton (one source, one
  transform, one sink) first, then widen. Never build a perfect ingest layer
  before anything reads it.
- **Data outlives code:** name and version every schema; keep raw data
  immutable; document lineage.

## Decision checklist

1. What are the load parameters and the latency percentile that matters?
2. Which data model fits the relationships, now and in two years?
3. Read-heavy or write-heavy? Transactional or analytical? (storage engine)
4. What happens to the schema in a year? Are formats backward and forward
   compatible?
5. Which replication topology, and which lag anomalies does the product
   tolerate?
6. How is data partitioned, and where are the hot keys?
7. Which isolation level, and which invariants need serializability?
8. What fails: node, network, clock, process pause? Which model do we
   handle?
9. Where is linearizability actually required (locks, uniqueness, leader)?
10. Can this be a log + derived views instead of a distributed transaction?
11. Is every consumer idempotent, and does an end-to-end ID exist?
12. Can the whole derived state be rebuilt from raw events?
