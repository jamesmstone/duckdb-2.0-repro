# Time to first row regressed ~20x

A streaming query emits its first row long before the scan producing the rest finishes. v1.5.5 does; v2.0.0-alpha waits on much of the scan, and the wait grows with it.

```bash
./run.sh
```

See the [repository README](../README.md) for the measured numbers, what it
means in practice, and what would fix it.
