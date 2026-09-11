# Conjunction OS Repository Map & Development Conventions

## 1. Repository Overview

Conjunction uses a hybrid repository layout:
* **Rust Workspace**: Systems programming, application daemons, CLI tools, and core parsing logic.
* **Shell & Archiso Scripts**: OS image generation, live ISO configuration, and setup tooling.
* **Docs & Architecture**: RFCs, ADRs, design specifications, and guidelines.

---

## 2. Component Ownership & Directory Map

| Path | Purpose | Primary Language / Tool | Ownership |
|---|---|---|---|
| `conjunction-core/` | Shared core library: environment paths, process execution helpers, config structures. | Rust | Core System Team |
| `cj/` | CLI developer and admin interface (`cj` / `conj-bundle`). | Rust (`clap`) | Tooling Team |
| `application/` | Application bundle inspection and metadata parsing models. | Rust | App Services Team |
| `app_sync/` | Synchronizer daemon between `.app` manifests, system packages, and XDG desktop entries. | Rust | App Services Team |
| `archiso/` | Archiso configuration profiles for generating bootable Conjunction media. | Bash / Arch Linux | OS Image Team |
| `conjunction_gui/` | Python/PyQt/QML prototyping assets for desktop shell surfaces. | QML / Python | Shell / UI Team |
| `docs/` | System architecture RFCs, ADRs, and contributor documentation. | Markdown | Architecture Board |
| `docs/adr/` | Architectural Decision Records tracking technical choices over time. | Markdown | Architecture Board |
| `docs/rfc/` | Long-form Request For Comments defining specifications and phases. | Markdown | Architecture Board |
| `.github/workflows/` | CI workflows verifying Rust builds, unit tests, and shell script syntax. | GitHub Actions YAML | DevOps Team |

---

## 3. Formatting, Linting & Quality Standards

### Rust Code
* **Formatting**: `cargo fmt --all -- --check`
* **Linter**: `cargo clippy --workspace --all-targets -- -D warnings`
* **Tests**: `cargo test --workspace`
* **Safety**: Prefer safe Rust. Avoid `unsafe` unless interfacing with raw OS syscalls, with explicit safety comments.

### Shell Scripts
* **Syntax Validation**: `git ls-files -z '*.sh' | xargs -0 -r -n1 bash -n`
* **Defensive Practice**: `set -euo pipefail` where applicable; avoid unquoted variables in shell pipelines.

### Documentation & Architecture
* Follow RFC and ADR templates in `docs/adr/template.md`.
* Avoid speculative design beyond the active phase gate.

---

## 4. Local Development Commands

```bash
# Build entire Rust workspace
cargo build --workspace

# Run all automated tests
cargo test --workspace

# Run check on specific tool
cargo check -p cj

# Format check
cargo fmt --all -- --check

# Shell script syntax check
bash -n build-iso.sh
```
