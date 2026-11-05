# Linux launcher and shared code

See the [root README](../README.md) for configuration, security, setup and tests.
This Flutter project targets Linux and depends on `packages/finance_core`.
Run from repository root: `python3 linux/tool/flutter_client.py linux run -d linux`.
`supabase/migrations` defines the single cloud schema used by BOTH applications.
`tool` contains local administration and optional native build tooling, never a runtime service.
