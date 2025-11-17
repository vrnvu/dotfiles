PostgreSQL (psql)

Connections and capacity (questions → commands)

- How many sessions are connected across the server? Why care: capacity vs max_connections.

```sql
SELECT count(*) AS total_sessions FROM pg_stat_activity;
```

- How many sessions are connected to my homework database? Why care: database-specific load.

```sql
SELECT count(*) AS homework_sessions FROM pg_stat_activity WHERE datname = 'homework';
```

- What is the cap on connections (and reserved)? Why care: hitting caps causes "remaining connection slots are reserved".

```sql
SHOW max_connections;
SHOW superuser_reserved_connections;
```

States and why they matter

- How many sessions are active vs idle? Why care: active = running work; many idle-in-transaction indicates leaks.

```sql
SELECT state, count(*) FROM pg_stat_activity GROUP BY 1 ORDER BY 2 DESC;
```

- Why are there blank states? Why care: those are background workers, not client sessions.

```sql
SELECT backend_type, count(*) FROM pg_stat_activity GROUP BY 1 ORDER BY 2 DESC;
```

- Only count client sessions (exclude background). Why care: separates user load from system.

```sql
SELECT state, count(*) FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY 1 ORDER BY 2 DESC;
```

- Only client sessions in homework DB. Why care: db-specific client pressure.

```sql
SELECT count(*) FROM pg_stat_activity
WHERE backend_type = 'client backend' AND datname = 'homework';
```

- Who is "idle in transaction" and for how long? Why care: open transactions hold locks and bloat; fix the app.

```sql
SELECT pid, usename, now()-xact_start AS xact_age, query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY xact_start ASC;
```

What's running now and for how long

- Which queries are currently running and their age/waits? Why care: find hot/slow queries and wait reasons.

```sql
SELECT pid, usename, datname,
       now()-query_start AS query_age,
       wait_event_type, wait_event,
       query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY query_start ASC;
```

Locks and blockers

- Who is blocking whom right now? Why care: resolve production stalls quickly.

```sql
SELECT bl.pid AS blocked_pid,
       ka.pid AS blocking_pid,
       now()-ka.query_start AS blocking_age,
       ka.query AS blocking_query
FROM pg_locks bl
JOIN pg_locks kl
  ON bl.locktype = kl.locktype
 AND bl.database = kl.database
 AND bl.relation = kl.relation
 AND bl.pid <> kl.pid
 AND NOT bl.granted
 AND kl.granted
JOIN pg_stat_activity ka ON kl.pid = ka.pid;
```

- What locks exist right now? Why care: understand contention hotspots.

```sql
SELECT pid, locktype, relation::regclass AS relation, mode, granted
FROM pg_locks
ORDER BY relation, mode;
```

- How do I stop a problem session? Why care: emergency remediation (use sparingly).

```sql
SELECT pg_cancel_backend(<pid>);      -- try cancel first
SELECT pg_terminate_backend(<pid>);   -- force terminate if needed
```

Timeouts and safety

- Do we have a statement timeout? Why care: runaway queries hurt availability.

```sql
SHOW statement_timeout;
```

- Set a timeout for just my session/transaction.

```sql
SET LOCAL statement_timeout = '5s';
```

Slow queries and plans

- Why is this query slow? Get the actual execution plan. Why care: fix scans/joins/idx.

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) <your_query>;
```

- Show top 10 longest-running non-idle queries. Why care: quick triage.

```sql
SELECT pid, now()-query_start AS age, state, query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_start ASC
LIMIT 10;
```

Historic slow queries (why)

- See historic/aggregated slow queries via pg_stat_statements. Why care: find expensive patterns beyond "what's running now".

- Is pg_stat_statements enabled?

```sql
SELECT extname FROM pg_extension WHERE extname = 'pg_stat_statements';
```

- If missing, enable (requires restart due to shared_preload_libraries):
  - In postgresql.conf: shared_preload_libraries = 'pg_stat_statements'
  - Then:

```sql
CREATE EXTENSION pg_stat_statements;
```

- Top queries by total time (all DBs):

```sql
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

- Top queries for homework DB only:

```sql
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = 'homework')
ORDER BY total_exec_time DESC
LIMIT 10;
```

- Most expensive on average:

```sql
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

- Reset stats (optional):

```sql
SELECT pg_stat_statements_reset();
```

If pg_stat_statements isn't available, temporarily log slow queries:

```sql
SET log_min_duration_statement = '200ms';
```

Handy psql client helpers (why)

```
\conninfo      -- confirm you're on the expected host/db/user
\dt+           -- list tables with sizes (find large objects)
\x on          -- readable expanded output
\timing on     -- see durations for your ad-hoc queries
\watch 2       -- re-run last query every 2s to monitor live
```

Docker/TigerData quick checks (why)

```bash
docker logs tigerdata --tail 200                         # errors/startup issues
docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Ports}}'  # port mapping
psql "host=localhost port=5432 user=<u> dbname=<db> sslmode=require" -c 'SELECT 1;'  # connectivity
```

Rule-of-thumb

- Many idle sessions: normal with pooling
- Many idle in transaction with growing ages: app leak; add timeouts
- Active sessions waiting on locks: find blockers, add indexes/tune
- Total sessions near max_connections: add pooling, or raise carefully
- statement_timeout = 0: consider a sane default to prevent runaways

