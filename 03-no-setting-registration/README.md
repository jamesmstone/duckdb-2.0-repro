# A V2 extension cannot register a setting

V2 has no equivalent of V1's duckdb_create_config_option / duckdb_register_config_option, so an extension cannot expose a setting.

```bash
./run.sh
```

See the [repository README](../README.md) for the measured numbers, what it
means in practice, and what would fix it.
