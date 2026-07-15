# python-grpc-service-archetype

An [Archetect](https://archetect.github.io/) (v3 / Lua) archetype that generates a Python gRPC
service using grpcio (with server reflection + health), a FastAPI management sidecar (health
probes + Prometheus metrics), CI workflows, and platform (Kubernetes) manifests.

## Acceptance tests

This archetype ships a [prova](https://github.com/prova-rs/prova) acceptance suite (`tests/`,
driven by `prova.toml`) that renders the archetype in-process and validates the generated
project across three tiers:

- **static** — project layout, template substitution, Kubernetes manifests parse, and no
  leftover template markers (no toolchain required)
- **build** — `uv sync` + the generated project's own pytest suite
- **live** — generates the proto stubs (`make proto`), boots the gRPC server, and proves
  server reflection, the health service (`SERVING`), UNIMPLEMENTED stub RPCs, and the
  management sidecar (health probes + Prometheus metrics) over the wire

### Install prova

```shell
brew tap prova-rs/tap
brew install prova
```

Or download a binary for your platform from the
[prova releases](https://github.com/prova-rs/prova/releases) and put it on your `PATH`.

### Prerequisites

- **Network access + git** — the suite renders the archetype in-process (prova embeds
  archetect), which fetches the composed libraries over HTTPS from GitHub.
- **[`uv`](https://docs.astral.sh/uv/)** — required by the build and live tiers (they run
  `uv sync` and boot the generated service via `uv run`). The static tier needs no toolchain.
- **`make`** — the live tier runs `make proto` to generate the gRPC stubs before booting.
  (proto codegen itself uses `grpcio-tools`, installed by `uv`; no separate protoc needed.)

Tiers whose required tools are unavailable are skipped, not failed.

### Run

From the repo root:

```shell
prova                                # run the whole suite (uses ./prova.toml)
prova --profile ci                   # the profile CI runs (JSON output)
prova tests/grpc_service_test.lua    # a single test file
```

CI runs the same suite via [`prova-rs/run-action`](https://github.com/prova-rs/run-action)
(see `.github/workflows/acceptance.yaml`).
