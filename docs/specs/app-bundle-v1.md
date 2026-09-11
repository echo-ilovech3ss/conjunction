# Conjunction Application Bundle Specification v1

* **Specification Version**: 1.0.0
* **Bundle Format Identifier**: `conjunction.app/1`
* **Status**: Stable
* **Last Updated**: 2026-09-11

---

## 1. Purpose

The Conjunction `.app` bundle specification defines a standardized, self-contained, directory-based application package for the Conjunction desktop operating system. It presents an application as a single cohesive object to users while encapsulating its executable, metadata, assets, and system contracts.

---

## 2. Directory Structure

A Conjunction application is a directory ending in `.app`. The minimal and extended structures are defined as follows:

### 2.1 Minimal Viable Structure
```text
Example.app/
└── Contents/
    ├── Info.toml
    └── Executable/
        └── example
```

### 2.2 Standard Full Structure
```text
Example.app/
└── Contents/
    ├── Info.toml           # Mandatory application metadata manifest
    ├── Executable/         # Primary executable and auxiliary binaries
    │   └── example
    ├── Resources/          # Localization, UI templates, media assets
    ├── Libraries/          # Bundled shared libraries (if any)
    ├── PlugIns/            # Extensible application plugins
    ├── Icons/              # Vector (SVG) and raster (PNG) app icons
    ├── XDG/                # Desktop integration templates
    └── Sandbox.toml        # Isolation and permission constraints (future)
```

---

## 3. Manifest (`Info.toml`) Schema

The application manifest must be placed at `Contents/Info.toml` inside the bundle root. It is encoded in UTF-8 TOML.

### 3.1 Required Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `bundle_format` | String | Must equal `"conjunction.app/1"`. Unknown versions are rejected. | `"conjunction.app/1"` |
| `id` | String | Stable reverse-DNS application identifier. | `"org.example.hello"` |
| `name` | String | Human-readable application display name. Supports Unicode. | `"Hello World"` |
| `version` | String | Application version string. | `"1.0.0"` |
| `executable` | String | Relative path to the executable inside the bundle. | `"Contents/Executable/hello"` |
| `architectures` | Array of Strings | Non-empty list of supported target architectures. | `["x86_64"]` |

### 3.2 Optional Phase 1 Fields

| Field | Type | Description |
|---|---|---|
| `icon` | String | Path to main icon file relative to bundle root (e.g. `"Contents/Icons/app.svg"`). |
| `mime_types` | Array of Strings | MIME types handled by the application (e.g. `["image/png"]`). |
| `url_schemes` | Array of Strings | Custom URL schemes registered by the app (e.g. `["myproto"]`). |
| `category` | String | Main desktop menu category (e.g. `"Utility"`, `"Development"`). |
| `description` | String | Human-readable summary of the application. |
| `permissions` | Array of Strings | Declared system capabilities (e.g. `["network", "audio"]`). |
| `data` | Table / Map | Mapping of data domains to XDG namespaces. |

### 3.3 Minimal Valid Example
```toml
bundle_format = "conjunction.app/1"
id = "org.example.hello"
name = "Hello"
version = "1.0.0"
executable = "Contents/Executable/hello"
architectures = ["x86_64"]
```

### 3.4 Full Example
```toml
bundle_format = "conjunction.app/1"
id = "org.example.editor"
name = "Conjunction Notes"
version = "2.1.0"
executable = "Contents/Executable/notes"
architectures = ["x86_64", "aarch64"]
icon = "Contents/Icons/notes.svg"
category = "Office"
description = "A clean Markdown and note taking editor."
mime_types = ["text/plain", "text/markdown"]
url_schemes = ["notes"]
permissions = ["filesystem:home", "network"]

[data]
config = "org.example.editor"
cache = "org.example.editor"
state = "org.example.editor"
data = "org.example.editor"
```

---

## 4. Application Identifier Rules

Application IDs establish identity across desktop menus, settings, and file associations:
* **Syntax**: Reverse-DNS format (e.g. `org.example.hello`, `com.acme.tool`).
* **Components**: At least two segments separated by ASCII dots (`.`).
* **Characters**: Segments may contain `[a-zA-Z0-9_-]`.
* **Prohibitions**:
  * Cannot be empty.
  * Cannot have leading or trailing dots.
  * Cannot contain consecutive dots (`..`).
  * Segments cannot begin or end with `-` or `_`.
  * Cannot contain spaces, slashes, or shell metacharacters.

---

## 5. Executable Path Security & Resolution

To guarantee security against malicious bundles:
1. **Relative Path Only**: The declared `executable` path must be relative to the bundle root. Absolute paths (starting with `/`, `\`, or drive letters) are rejected immediately.
2. **No Path Traversal**: Components such as `..` are strictly prohibited in the manifest declaration.
3. **Strict Canonical Boundary**: When resolving the binary:
   $$\text{canonical}(\text{bundle\_root} + \text{executable}) \subset \text{canonical}(\text{bundle\_root})$$
   Any path whose canonicalization escapes the canonical bundle directory causes immediate validation failure (`ExecutableEscapesBundle`).
4. **Regular File Requirement**: The resolved executable target must be a regular file, not a directory, device, or socket.
5. **Execution Permissions**: On Unix platforms, the target file must possess execute permissions (`0o111` mask). Validation observes and enforces this; it never silently modifies (`chmod`) application contents.

---

## 6. Symlink Policy

* **Resources & Assets**: Symlinks are permitted within `Contents/Resources/` and other non-executable directories, provided they do not introduce circular references or security hazards.
* **Primary Executable**: The primary executable entry point may be a symbolic link **only** if its fully resolved canonical target resides inside the bundle root.
* **External Symlinks Prohibited**: Any executable symlink resolving outside the bundle root is rejected unconditionally during validation.

---

## 7. Supported Architecture Values

Phase 1 recognizes the following standard architecture strings:
* `x86_64`: 64-bit x86 architecture.
* `aarch64`: 64-bit ARM architecture.

Manifests declaring architectures outside this list are rejected with `UnsupportedArchitecture`.

---

## 8. Versioning & Forward Compatibility

The `bundle_format` string enforces strict major versioning:
* Format strings follow `<format_name>/<major_version>`.
* Applications for specification version 1 must specify `bundle_format = "conjunction.app/1"`.
* Future major revisions (`conjunction.app/2`) will introduce breaking schema changes and will be cleanly rejected by v1 tools rather than parsed erroneously.
