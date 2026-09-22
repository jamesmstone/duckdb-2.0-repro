# No supported way for an extension to hold a connection

A feature request, not a regression. Nothing maps the extension or context
handle the V2 entrypoint receives onto the running instance, so an extension
cannot obtain a connection to it — and V1, which allows this in practice,
documents its database handle as borrowed for the entrypoint only.

```bash
./run.sh
```

See the [repository README](../README.md) for the full argument, including why
this is worth having anyway.
