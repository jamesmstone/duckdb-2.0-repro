# DuckDB 2.0 alpha: three findings

Three small, self-contained reproductions, found while porting a DuckDB
extension and its host application to the 2.0 alpha.

One is a performance regression; two are gaps in the new V2 C extension API
that leave an existing V1 extension with nowhere to go.

Recorded against **`v2.0.0-alpha42839`** (`duckdb/duckdb@31adc8b766`) and
compared against **`v1.5.5`**.

```bash
./run-all.sh          # all three
./01-first-byte-latency/run.sh
```

`run-all.sh` downloads both DuckDB CLIs from DuckDB's own distribution into
`bin/` and the headers into `tmp/`. Nothing else is needed. There is also a
`flake.nix` for anyone who wants the two binaries pinned by hash; it is
optional, and `run.sh` does not use it.

---

## 1. Time to first row regressed ~20x

`01-first-byte-latency/`

A streaming query can emit its first row long before the scan producing the
rest has finished. v1.5.5 does. v2.0.0-alpha does not: its first row now waits
on a large part of the scan, and the wait grows with the scan.

| shape | rows scanned | version | first row | total |
|---|---:|---|---:|---:|
| `UNION ALL` | 20,000,000 | v1.5.5 | **19 ms** | 183 ms |
| `UNION ALL` | 20,000,000 | v2.0.0-alpha42839 | **150 ms** | 163 ms |
| `UNION ALL` | 200,000,000 | v1.5.5 | **18 ms** | 1393 ms |
| `UNION ALL` | 200,000,000 | v2.0.0-alpha42839 | **304 ms** | 1247 ms |
| plain scan | 20,000,000 | v1.5.5 | **16 ms** | 155 ms |
| plain scan | 20,000,000 | v2.0.0-alpha42839 | **151 ms** | 164 ms |
| plain scan | 200,000,000 | v1.5.5 | **17 ms** | 1387 ms |
| plain scan | 200,000,000 | v2.0.0-alpha42839 | **301 ms** | 1215 ms |

Medians of five runs. Absolute numbers move with machine load; the ratio does
not. v1.5.5's first-row latency is flat in the scan size — 16-19 ms whether it
scans 20 million rows or 200 million. The alpha's scales with it: 150 ms, then
300 ms. Both query shapes behave identically, so this is not about `UNION ALL`.

The alpha is *faster* end to end at the larger size — 1247 ms against 1393 ms.
This reads like a deliberate trade of latency for throughput, but it is a large
one, and a ~17x first-row regression seems unlikely to be the intended size of
it.

```sql
COPY (
  SELECT 'head' AS c
  UNION ALL
  SELECT '<li>' || i || '</li>' FROM range(20000000) r(i) WHERE (r.i * 2654435761) % 97 = 3
) TO '/dev/stdout' (FORMAT csv);
```

**Why it matters.** Anything that streams a response out as it is produced —
an HTTP response, a pipe into another process — pays the whole latency before
its first byte moves.

## 2. A V2 extension cannot reach the instance it was loaded into

`02-no-connection-accessor/`

The V2 entrypoint receives `extension`, `context` and an error slot. A
connection comes only from `duckdb_v2_connection_create`, which needs an
instance; an instance comes only from `duckdb_v2_instance_create`, which makes
a **new** one from an environment. Nothing maps `extension` or `context` onto
the instance the extension is running inside, and the context is documented as

> Valid only until the extension entrypoint returns; do not retain or destroy it.

The seven `*_with_extension` entries register functions; that is everything an
extension handle can do.

Under V1, the entrypoint is handed the database directly via
`duckdb_extension_access.get_database`, and extensions open a connection from
it and keep it.

**Why it matters.** An extension that must hold a connection for the life of
the process cannot be written against V2 — one that serves requests on its own
threads, or that writes outside the transaction of the query that invoked it
(a write cannot reuse the connection running the outer `SELECT`).

**What would fix it.** An accessor from the extension or context handle to the
running instance, or directly to a connection.

## 3. A V2 extension cannot register a setting

`03-no-setting-registration/`

V2 registers functions, casts, copy functions, custom types and replacement
scans. It has no equivalent of V1's `duckdb_create_config_option` /
`duckdb_register_config_option`. Its option entries only read and write
options that already exist; an option handle can be inspected and destroyed,
never created.

So an extension that exposes a setting —

```sql
SET GLOBAL my_extension_option = '...';
SELECT current_setting('my_extension_option');
```

— has nowhere to put it under V2.

---

## Notes

The alpha moves. `DUCKDB_ALPHA=latest ./run-all.sh` chases the current build
instead of the pinned one; `DUCKDB_REF=<sha> ./run-all.sh` points the header
checks at a different commit. Findings 2 and 3 were first seen on
`v2.0.0-alpha42069` and still hold on `alpha42839`, across a round of renames
in the V2 API (`database` → `instance`, `duckdb_v2_connect` →
`duckdb_v2_connection_create`).
