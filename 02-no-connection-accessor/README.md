# A V2 extension cannot reach the instance it was loaded into

Nothing maps the extension or context handle the V2 entrypoint receives onto the running instance, so an extension cannot obtain a connection to it.

```bash
./run.sh
```

See the [repository README](../README.md) for the measured numbers, what it
means in practice, and what would fix it.
